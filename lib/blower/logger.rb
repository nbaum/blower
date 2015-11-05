require "singleton"

module Blower

  class Logger
    include MonitorMixin
    include Singleton

    COLORS = {
      trace: :light_black,
      debug: :light_black,
      info: :blue,
      warn: :yellow,
      error: :red,
      fatal: :magenta,
    }

    def initialize
      @indent = 0
      super()
    end

    def trace (a=nil, *b, &c); log(a, :trace, *b, &c); end
    def debug (a=nil, *b, &c); log(a, :debug, *b, &c); end
    def info (a=nil, *b, &c); log(a, :info, *b, &c); end
    def warn (a=nil, *b, &c); log(a, :warn, *b, &c); end
    def error (a=nil, *b, &c); log(a, :error, *b, &c); end
    def fatal (a=nil, *b, &c); log(a, :fatal, *b, &c); end
    def raw (a=nil, *b, &c); log(a, nil, *b, &c); end

    def log (message = nil, level = :info, &block)
      if message
        synchronize do
          message = message.colorize(COLORS[level]) if level
          puts "  " * @indent + message
        end
      end
      begin
        @indent += 1
        block.()
      ensure
        @indent -= 1
      end if block
    end

  end

  def self.log (*args, &block)
    Logger.instance.log(*args, &block)
  end

end
