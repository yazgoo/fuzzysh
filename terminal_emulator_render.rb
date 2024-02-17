#!/usr/bin/env ruby
require 'optparse'
require 'socket'

class Terminal

  class Char
    attr_accessor :fg_color, :bg_color

    def initialize(char)
      @char = char
      @fg_color = 0
      @bg_color = 0
    end

    def to_s
      #"\e[#{@fg_color + 30}m#{@char}\e[0m"
      @char
    end
  end

  def interprete_escape_sequence(command, args, passthrough)
    STDOUT.printf "\e[#{args}#{command}" if passthrough
    if command == "H"
      @row = args.split(";")[0].to_i
      @col = args.split(";")[1].to_i
    elsif command == "J"
      @buffer.each do |row|
        row.map! { |col| Char.new(" ") }
      end
    elsif command == "m"
      args.split(";").each do |arg|
        case arg.to_i
        when 0
        when 1
          @buffer[@row - 1][@col - 1].fg_color = 1
        when 30..37
          @buffer[@row - 1][@col - 1].fg_color = arg.to_i - 30
        when 40..47
          # @bg_color = arg.to_i - 40
        end
      end
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
    @rows = rows
    @cols = cols
    @buffer = Array.new(@rows) { Array.new(@cols) }
    # initialize buffer with spaces
    @buffer.each do |row|
      row.map! { |col| Char.new(" ") }
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
        @buffer[@row - 1][@col - 1] = Char.new(char)
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
          client.puts "#{to_s}"
          client.close
        end
      end
    end
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
