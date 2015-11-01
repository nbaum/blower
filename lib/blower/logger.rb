require "colorize"

module Blower

  class Logger

    def initialize ()
      @logdent = 0
    end

    def info (message, **keys, &block)
      log(message, :blue, **keys, &block)
    end

    def debug (message, **keys, &block)
      log(message, **keys, &block)
    end

    def warn (message, **keys, &block)
      log(message, :yellow, STDERR, **keys, &block)
    end

    def fail (message, **keys, &block)
      log(message, :red, STDERR, **keys, &block)
    end

    def win (message, **keys, &block)
      log(message, :green, **keys, &block)
    end

    def log (message, color=nil, to=STDOUT, prefix: "", &block)
      message.to_s.scan(/(?:[^\n\r]*[\n\r])|(?:[^\n\r]+$)/) do |line|
        case line[-1]
        when "\n", "\r"
        else
          line = line + "\n"
        end
        STDOUT.write "  " * @logdent + prefix + (color ? line.colorize(color) : line)
      end
      begin
        @logdent +=1
        block.()
      ensure
        @logdent -= 1
      end if block
    end

  end

end
