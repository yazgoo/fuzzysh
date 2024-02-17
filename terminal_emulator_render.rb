#!/usr/bin/env ruby

class Terminal

  def interprete_escape_sequence(command, args)
    if command == "H"
      @row = args.split(";")[0].to_i
      @col = args.split(";")[1].to_i
    end
  end

  def read_escape_sequence(chars, i)
    i += 1
    if chars[i] == "["
      command=""
      i += 1
      while not ["h", "l", "m", "H"].include?(chars[i])
        command += chars[i]
        i += 1
      end
      interprete_escape_sequence(chars[i], command)
    end
    return i
  end
  
  def initialize
    @rows = ARGV[0].to_i
    @cols = ARGV[1].to_i
    @buffer = Array.new(@rows) { Array.new(@cols) }
    # initialize buffer with spaces
    @buffer.each do |row|
      row.map! { |col| " " }
    end
    @row = 1
    @col = 1
  end

  def run(chars)
    i = 0
    while i < chars.size
      if chars[i].ord == 27
        i = read_escape_sequence(chars, i)
      elsif chars[i].ord == 10
        @row += 1
        @col = 1
      elsif chars[i].ord == 15
        @col = 1
      else
        @buffer[@row - 1][@col - 1] = chars[i]
        @col += 1
        if @col > @cols
          @col = 1
          @row += 1
        end
      end
      i += 1
    end
  end

  def to_s
    @buffer.map { |row| row.join }.join("\n")
  end

end

t = Terminal.new
t.run(STDIN.each_char.to_a)
puts t.to_s
