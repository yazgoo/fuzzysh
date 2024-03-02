#!/usr/bin/env ruby
require 'pty'
require 'optparse'
require 'socket'
require 'io/console'

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

  def interprete_escape_sequence(command, args, passthrough)
    STDOUT.printf "\e[#{args}#{command}" if passthrough
    if command == "H"
      @row = args.split(";")[0].to_i
      @col = args.split(";")[1].to_i
    elsif command == "J"
      @buffer.each_with_index do |row, r| 
        c = 0
        row.map! { |col| 
          c += 1
          Termel.new(c, r + 1) } 
      end
    elsif command == "m"
      if args == "0"
        @fg_color = "1"
        @buffer[@row - 1][@col - 1].set_fg_color(@fg_color)
        @bg_color = "1"
        @buffer[@row - 1][@col - 1].set_bg_color(@bg_color)
      elsif args.include?(";") and args.split(";")[1][0] == "3"
        @fg_color = args
        @buffer[@row - 1][@col - 1].set_fg_color(@fg_color)
      elsif args.include?(";") and args.split(";")[1][0] == "4"
        @bg_color = args
        @buffer[@row - 1][@col - 1].set_bg_color(@bg_color)
      else
        puts "Unknown color: #{args}"
        exit 1
      end
    elsif command == "h"
      # ignore
    elsif command == "l"
      # ignore
    else
      puts "Unknown escape sequence: #{command}"
      exit 1
    end
  end

  def read_escape_sequence(file, passthrough)
    if file.read(1) == "["
      chars = ""
      char = ""
      while file.eof? == false
        char = file.read(1)
        break if ["h", "l", "m", "H", "J"].include?(char)
        chars += char
      end
      interprete_escape_sequence(char, chars, passthrough)
    else
      exit 1
    end
  end
  
  def initialize rows, cols
    @fg_color = "1"
    @bg_color = "1"
    @rows = rows
    @cols = cols
    @buffer = Array.new(@rows) { Array.new(@cols) }
    # initialize buffer with spaces
    @buffer.each_with_index do |row, r|
      c = 0
      row.map! { |col| c += 1; Termel.new(c, r + 1) }
    end
    @row = 1
    @col = 1
  end

  def run(file, passthrough=true)
    while file.eof? == false
      char = file.getc
      if char.ord == 27
        read_escape_sequence(file, passthrough)
      elsif char.ord == 10
        @row += 1
        @col = 1
        STDOUT.puts if passthrough
      elsif char.ord == 15
        @col = 1
      else
        STDOUT.write char if passthrough
        @buffer[@row - 1][@col - 1].set(char, @fg_color, @bg_color)
        @col += 1
        if @col > @cols
          @col = 1
          @row += 1
        end
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
    buffer = @buffer.map { |row| row.map { |c| c.to_svg }.join }.join
    "<svg width=\"#{(@cols + 1) * 8}\" height=\"#{(@rows + 1) * 12}\" xmlns=\"http://www.w3.org/2000/svg\">
      #{buffer}
    </svg>"
  end


  def to_html
    @buffer.map { |row| row.map { |c| c.to_html }.join }.join("<br/>")
  end

  def to_ansi
    @buffer.map { |row| row.map { |c| c.to_ansi }.join }.join("\n")
  end

  def to_s
    @buffer.map { |row| row.map { |c| c.to_s }.join }.join("\n")
  end

end

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
end.parse!

t = Terminal.new(options[:rows], options[:cols])
t.server(options[:port]) if options.key?(:port)
if options.key?(:spawn)
  args = options[:spawn]
  STDIN.raw!
  args_redirected = options[:stderr] ? "#{args} >&2" : args
  PTY.spawn(args_redirected) do |stdout_stderr, stdin, pid|
    begin
      Thread.new do
        loop do
          char = STDIN.getc
          break if char.nil?  # Break the loop if no more input is available
          stdin.putc char
        end
      end
      begin
        t.run(stdout_stderr, options[:passthrough])
      rescue Errno::EIO
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
else
  t.run(STDIN, options[:passthrough])
end
puts t.to_s if options[:final]
