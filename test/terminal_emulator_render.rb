#!/usr/bin/env ruby
require 'pty'
require 'optparse'
require 'socket'
require 'io/console'

class Color
  def initialize(color)
    @color = color
  end
  def to_s
    "\e[#{@color}m"
  end
  def ansi_to_css(n)
    { 30 => "black", 31 => "red", 32 => "green", 33 => "yellow", 34 => "blue", 35 => "magenta", 36 => "cyan", 37 => "white" , 
      40 => "grey", 41 => "red", 42 => "green", 43 => "yellow", 44 => "blue", 45 => "magenta", 46 => "cyan", 47 => "white" }[n]
  end

  def to_css
    n = @color.sub("1;", "").to_i
    n / 10 == 3 ? "color: #{ansi_to_css(n)};" : 
      n / 10 == 4 ? "background-color: #{ansi_to_css(n)};" : ""
  end

  def to_svg
    n = @color.sub("1;", "").to_i
    n / 10 == 3 ? "stroke=\"#{ansi_to_css(n)}\"" : 
      n / 10 == 4 ? "fill=\"#{ansi_to_css(n)}\"" : ""
  end
end

def do_log(level, msg, log)
  color = Color.new({ info: 31, error: 32, warn: 33, debug: 34}[level])
  end_color = Color.new(0)
  if log
    File.open(log, "a") do |f|
      f.puts("#{color}#{level.upcase.to_s}#{end_color} #{msg}")
    end
  end
end

def info(msg, log)
  do_log(:info, msg, log)
end

def error(msg, log)
  do_log(:error, msg, log)
end

def warn(msg, log)
  do_log(:warn, msg, log)
end

def debug(msg, log)
  do_log(:debug, msg, log)
end

class Terminal

  class Char
    def initialize(char)
      @char = char
    end
    def to_s
      @char
    end
    def to_html
      case @char
      when " "
        "&nbsp;"
      when "<"
        "&lt;"
      when ">"
        "&gt;"
      else
        @char
      end
    end
  end



  class Termel

    def initialize(col, row)
      @col = col.to_i
      @row = row.to_i
      @char = Char.new(" ")
      @fg_color = Color.new("1")
      @bg_color = Color.new("1")
    end

    def set(char, color, bg_color)
      @char = Char.new(char)
      @fg_color = Color.new(color)
      @bg_color = Color.new(bg_color)
    end

    def set_fg_color(color)
      @fg_color = Color.new(color)
    end

    def set_bg_color(color)
      @bg_color = Color.new(color)
    end


    def to_svg
      bg_color_svg = @bg_color.to_svg
      bg = ""
      if bg_color_svg != ""
        bg = "<rect x=\"#{@col * 8}\" y=\"#{(@row - 1) * 12 + 1}\" width=\"8\" height=\"12\" #{bg_color_svg}></rect>\n"
      end
      text = "<text x=\"#{@col * 8}\" y=\"#{@row * 12}\" #{@fg_color.to_svg} style=\"font-family: monospace;\">#{@char}</text>\n"
      bg + text
    end

    def to_html
      "<span style=\"letter-spacing: 0; line-height: 1.25em; font-family: monospace; #{@fg_color.to_css}\">#{@char.to_html}</span>"
    end

    def to_ansi
      "#{@bg_color}#{@fg_color}#{@char}#{Color.new(0)}"
    end

    def to_s
      @char.to_s
    end
  end

  class Buffer
    def initialize(rows, cols)
      @rows = rows
      @cols = cols
      @buffer = Array.new(@rows) { Array.new(@cols) }
      # TODO buffer should handle overflow in term of lines
    end

    def row_col_to_0_based(row, col)
      # row, col start at 1, row0, col0 start at 0
      row0 = row - 1
      col0 = col - 1
      col0 = 0 if col0 < 0
      row0 = 0 if row0 < 0
      col0 = @cols - 1 if col0 > @cols - 1
      if row > @buffer.size
        (row - @buffer.size).times do
          @buffer.push((1..@cols).to_a.map { |c| Termel.new(c, row) })
        end
      end

      [row0, col0]
    end

    def access(row, col)
      row0, col0 = row_col_to_0_based(row, col)
      yield @buffer[row0][col0]
    end

    def set(row, col, char, fg_color, bg_color)
      access(row, col) { |termel| termel.set(char, fg_color, bg_color) }
    end

    def set_fg_color(row, col, fg_color)
      access(row, col) { |termel| termel.set_fg_color(fg_color) }
    end

    def set_bg_color(row, col, bg_color)
      access(row, col) { |termel| termel.set_bg_color(bg_color) }
    end

    def set_fg_bg_color(row, col, fg_color, bg_color)
      access(row, col) { |termel| 
        termel.set_fg_color(fg_color)
        termel.set_bg_color(bg_color)
      }
    end

    def reduce_s(line_separator="\n")
      @buffer.map do |row|
        row.map do |termel| yield termel 
        end.join 
      end.join(line_separator)
    end

    def clear
      @buffer.each_with_index do |row, r|
        c = 0
        row.map! { |col| c += 1; Termel.new(c, r + 1) }
      end
    end
  end

  def exit_with_error(msg, log)
    error(msg, log)
    error("exit 1", log)
    puts msg
    exit 1
  end

  def interprete_escape_sequence(command, args, passthrough, log)
    info("escape sequence: ESC[#{args}#{command} (args: #{args} command: #{command})", log)
    STDOUT.printf "\e[#{args}#{command}" if passthrough
    if command == "H"
      @row = args.split(";")[0].to_i
      @col = args.split(";")[1].to_i
      info("move cursor to row: #{@row}, col: #{@col}", log)
    elsif command == "J"
      if args == "2"
        info("clear screen", log)
        @buffer.clear
      else
        exit_with_error("Unknown escape sequence: #{args}#{command}", log)
      end
    elsif command == "m"
      args = args.gsub("\r\n", "")
      info("color: (size == #{args.size}) #{args}", log)
      if args.size == 0
        info("empty color", log)
      elsif args == "0"
        @fg_color = "1"
        @bg_color = "1"
        @buffer.set_fg_bg_color(@row, @col, @fg_color, @bg_color)
      elsif args.include?(";") and (args.split(";")[1][0] == "3" or args.start_with?("38;"))
        @fg_color = args
        @buffer.set_fg_color(@row, @col, @fg_color)
      elsif args.include?(";") and (args.split(";")[1][0] == "4" or args.start_with?("48;"))
        @bg_color = args
        @buffer.set_bg_color(@row, @col, @bg_color)
      elsif args == "1"
        # bold
        # TODO
        warn("bold not implemented", log)
      elsif args == "7"
        # inverse video mode
        warn("inverse video not implemented", log)
      elsif args == "27"
        # reverse video mode
        warn("reverse video not implemented", log)
      else
        error("exit color", log)
        error("exit color «#{args.size}»", log)
        exit_with_error("Unknown color: [#{is}] «#{args}»", log)
      end
    elsif command == "h"
      if args == "?1049"
        # enable alternate screen buffer
        warn("enable alternate screen buffer not implemented", log)
        # TODO
      elsif args == "?25"
        # rmcup
        warn("rmcup not implemented", log)
        # TODO
      elsif args == "?1"
        # 40 x 25 colors (text) screen mode
        warn("40 x 25 colors (text) screen mode not implemented", log)
        # TODO
      elsif args == "?7"
        warn("auto wrap not implemented", log)
        # TODO enable line wrapping
      else
        exit_with_error("Unknown escape sequence: '#{args}#{command}'", log)
      end
    elsif command == "l"
      if args == "?1049"
        # disable alternate screen buffer
        warn("disable alternate screen buffer not implemented", log)
        # TODO
      elsif args == "?25"
        # smcup
        warn("smcup not implemented", log)
        # TODO
      elsif args == "4"
        # TODO what is this ?
        warn("what is this? implemented", log)
      else
        exit_with_error("Unknown escape sequence: '#{args}#{command}'", log)
      end
    elsif command == "K"
      # TODO
    elsif command == "t"
      # window manipulation (XTWINOPS)
      warn("window manipulation is ignored", log)
    else
      exit_with_error("Unknown escape sequence: '#{args}#{command}'", log)
    end
  end

  def read_escape_sequence(file, passthrough, log)
    info("read_escape_sequence", log)
    c = file.read(1)
    debug("file char: #{c.unpack('c*')[0]}", log)
    info("read_escape_sequence: c: #{c.unpack('c*')}", log)
    #info("read_escape_sequence: char: #{char.unpack('c*')}", log)
    if c == "["
      chars = ""
      char = ""
      while file.eof? == false
        char = file.read(1)
        debug("file char: #{char.unpack('c*')[0]}", log)
        debug("read_escape_sequence: char: #{char.unpack('c*')} (#{char})", log)
        if ["h", "l", "m", "H", "J", "K", "t"].include?(char.to_s)
          debug("end of sequence", log)
          break 
        end
        chars += char
      end
      debug("before interprete sequence done", log)
      interprete_escape_sequence(char, chars, passthrough, log)
      debug("interprete escape sequence done", log)
    elsif c == "="
      warn("ignore application keypade mode", log)
    elsif c.to_i == 0
      warn("ignore escape sequence: #{c.to_i}", log)
    else
      warn("unknown escape sequence: #{c.to_i}", log)
      warn("exit 1", log)
      exit 1
    end
  end
  
  def initialize rows, cols
    @fg_color = "1"
    @bg_color = "1"
    @rows = rows
    @cols = cols
    @buffer = Buffer.new(@rows, @cols)
    # initialize buffer with spaces
    @buffer.clear
    @row = 1
    @col = 1
  end

  def run(file, passthrough=true, log=nil)
    begin
      while file.eof? == false
        debug("run loop", log)
        char = file.getc
        debug("file char: #{char.unpack('c*')[0]}", log)
        info("char: #{char.unpack('c*')}", log)
        if char.ord == 27
          read_escape_sequence(file, passthrough, log)
        elsif char.ord == 10
          @row += 1
          @col = 1
          STDOUT.puts if passthrough
        elsif char.ord == 27
          warn("escape", log)
        elsif char.ord == 13
          @col = 1
          STDOUT.print "\r" if passthrough
        elsif char.ord == 10
          @row += 1
        else
          STDOUT.write char if passthrough
          info("set buffer row: #{@row} col: #{@col} «#{char}»", log)
          @buffer.set(@row, @col, char, @fg_color, @bg_color)
          @col += 1
          if @col > @cols
            @col = 1
            @row += 1
          end
        end
      end
      info("end of file", log)
    rescue => e
      info("error: #{e}", log)
      e.backtrace.each do |l|
        info("error: #{l}", log)
      end
    end
  end

  def server(port)
    Thread.start do
      server = TCPServer.new port
      loop do
        Thread.start(server.accept) do |client|
          mode = client.gets
          if mode.chomp == "html"
            client.puts "#{to_html}"
          elsif mode.chomp == "svg"
            client.puts "#{to_svg}"
          elsif mode.chomp == "ansi"
            client.puts "#{to_ansi}"
          else
            client.puts "#{to_s}"
          end
          client.close
        end
      end
    end
  end

  def to_svg
    buffer = @buffer.reduce_s { |termel| termel.to_svg }
    "<svg width=\"#{(@cols + 1) * 8}\" height=\"#{(@rows + 1) * 12}\" xmlns=\"http://www.w3.org/2000/svg\">
      #{buffer}
    </svg>"
  end


  def to_html
    @buffer.reduce_s("<br/>") { |c| c.to_html }
  end

  def to_ansi
    @buffer.reduce_s { |c| c.to_ansi }
  end

  def to_s
    @buffer.reduce_s { |c| c.to_s }
  end

end

def parse_opts
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: [options]"

    opts.on("-p", "--passthrough", "Directly output stdin to stdout") do |v|
      options[:passthrough] = v
    end

    opts.on("-r", "--rows ROWS", "Number of rows") do |v|
      options[:rows] = v.to_i
    end

    opts.on("-c", "--cols COLS", "Number of columns") do |v|
      options[:cols] = v.to_i
    end

    opts.on("-f", "--final", "put final buffer state to stdout") do |v|
      options[:final] = v
    end

    opts.on("-P", "--port PORT", "Port to listen on") do |v|
      options[:port] = v.to_i
    end

    opts.on("-e", "--stderr", "read data from stderr") do |v|
      options[:stderr] = v
    end

    opts.on("-s", "--spawn ARGS", "spawn program") do |args|
      options[:spawn] = args.to_s
    end

    opts.on("-l", "--log LOGFILE", "log to file") do |v|
      options[:log] = v
    end
  end.parse!
  options
end

def spawn(args, stderr, cols, rows, log)
  STDIN.raw!
  args_redirected = stderr ? "#{args} 2>&1" : args
  PTY.spawn(args_redirected) do |stdout_stderr, stdin, pid|
    begin
      Thread.new do
        if not cols.nil? and not rows.nil?
          stdin.winsize = [rows, cols]
        end
        loop do
          char = STDIN.getc
          info("stdin char: #{char.to_i}", log)
          break if char.nil?  # Break the loop if no more input is available
          stdin.putc char
        end
      end
      info("stdout start yield", log)
      begin
        info("stdout read", log)
        yield stdout_stderr
      rescue Errno::EIO
        info("stdout Errno::EIO", log)
        # do nothing
      end
    ensure
      # Close the pseudo-terminal when done
      Process.wait(pid)
      stdin.close
      stdout_stderr.close
    end
  end
  STDIN.cooked!
end

options = parse_opts
t = Terminal.new(options[:rows], options[:cols])
t.server(options[:port]) if options.key?(:port)
if options.key?(:spawn)
  spawn(options[:spawn], options[:stderr], options[:cols], options[:rows], options[:log]) do |stdout_stderr|
    t.run(stdout_stderr, options[:passthrough], options[:log])
  end
else
  STDIN.set_encoding("UTF-8")
  t.run(STDIN, options[:passthrough], options[:log])
end 
puts t.to_s if options[:final]
