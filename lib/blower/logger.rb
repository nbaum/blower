require "singleton"

module Blower

  # Colorized logger.
  #
  # Prints messages to STDOUT, colorizing them according to the specified log level.
  #
  # The logging methods accept an optional block. Inside the block, log messages will
  # be indented by two spaces. This works recursively.
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

    # Log a trace level event
    def trace (a=nil, *b, &c); log(a, :trace, *b, &c); end

    # Log a debug level event
    def debug (a=nil, *b, &c); log(a, :debug, *b, &c); end

    # Log a info level event
    def info (a=nil, *b, &c); log(a, :info, *b, &c); end

    # Log a warn level event
    def warn (a=nil, *b, &c); log(a, :warn, *b, &c); end

    # Log a error level event
    def error (a=nil, *b, &c); log(a, :error, *b, &c); end

    # Log a fatal level event
    def fatal (a=nil, *b, &c); log(a, :fatal, *b, &c); end

    # Log a level-less event
    # @deprecated
    def raw (a=nil, *b, &c); log(a, nil, *b, &c); end

    private

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

end
