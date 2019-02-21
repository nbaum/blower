require 'colorize'
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

    # Logging levels in ascending order of severity.
    LEVELS = %i(all trace debug info warn error fatal none)

    # Colorize specifications for log levels.
    COLORS = {
      trace: { color: :light_black },
      debug: { color: :default },
      info:  { color: :blue },
      warn:  { color: :yellow },
      error: { color: :red },
      fatal: { color: :light_white, background: :red },
    }

    class << self
      # The minimum severity level for which messages will be displayed.
      attr_accessor :level

      # The current indentation level.
      attr_accessor :indent
    end

    self.level = :info

    def initialize (prefix = "")
      @prefix = prefix
      thread[:indent] = 0
      super()
    end

    # Return a logger with the specified prefix
    def with_prefix (string)
      Logger.send(:new, string)
    end

    # Yield with a temporarily incremented indent counter
    def with_indent ()
      thread[:indent] += 1
      yield
    ensure
      thread[:indent] -= 1
    end

    # Display a log message. The block, if specified, is executed in an indented region after the log message is shown.
    # @api private
    # @param [Symbol] level the severity level
    # @param [#to_s] message the message to display
    # @param block a block to execute with an indent after the message is displayed
    # @return the value of block, or nil
    def log (level, message, quiet: false, &block)
      if !quiet && (LEVELS.index(level) >= LEVELS.index(Logger.level))
        synchronize do
          message = message.to_s.colorize(COLORS[level]) if level
          message = message.to_s.colorize(COLORS[level]) if level
          message.split("\n").each do |line|
            STDERR.puts "  " * thread[:indent] + @prefix + line
          end
        end
        with_indent(&block) if block
      elsif block
        block.()
      end
    end

    # Define a helper method for a given severity level.
    # @!macro [attach] log_helper
    #   @!method $1(message, &block)
    #   Display a $1 log message, as if by calling log directly.
    #   @param [#to_s] message the message to display
    #   @param block a block to execute with an indent after the message is displayed
    #   @return the value of block, or nil
    def self.define_helper (level)
      define_method(level) do |*args, **kwargs, &block|
        log(level, *args, **kwargs, &block)
      end
    end

    define_helper :trace
    define_helper :debug
    define_helper :info
    define_helper :warn
    define_helper :error
    define_helper :fatal

    def thread
      Thread.current
    end

  end

end

# Return the logger instance.
def log
  Blower::Logger.instance
end
