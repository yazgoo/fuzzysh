#!/usr/bin/env ruby
require 'optparse'
require 'socket'

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
      case n
      when 0
        "black"
      when 1
        "red"
      when 2
        "green"
      when 3
        "yellow"
      when 4
        "blue"
      when 5
        "magenta"
      when 6
        "cyan"
      when 7
        "white"
      else
        "black"
      end
    end

    def to_css
      n = @color.sub("1;", "").to_i
      n / 10 == 3 ? "color: #{ansi_to_css(n - 30)};" : 
        n / 10 == 4 ? "background-color: #{ansi_to_css(n - 40)};" : ""
    end
  end


  class Termel

    def initialize
      @char = Char.new(" ")
      @color = Color.new("0")
    end

    def set(char, color)
      @char = Char.new(char)
      @color = Color.new(color)
    end

    def set_color(color)
      @color = Color.new(color)
    end

    def to_html
      "<span style=\"letter-spacing: 0; line-height: 1.25em; font-family: monospace; #{@color.to_css}\">#{@char.to_html}</span>"
    end

    def to_ansi
      "#{@color}#{@char}#{Color.new(0)}"
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
      @buffer.each { |row| row.map! { |col| Termel.new } }
    elsif command == "m"
      @color = args
      @buffer[@row - 1][@col - 1].set_color(@color)
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
    @color = 1
    @rows = rows
    @cols = cols
    @buffer = Array.new(@rows) { Array.new(@cols) }
    # initialize buffer with spaces
    @buffer.each do |row|
      row.map! { |col| Termel.new }
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
        @buffer[@row - 1][@col - 1].set(char, @color)
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
end.parse!

t = Terminal.new(options[:rows], options[:cols])
t.server(options[:port]) if options.key?(:port)
t.run(STDIN, options[:passthrough])
puts t.to_s if options[:final]
