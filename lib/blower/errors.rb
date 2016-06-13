
module Blower

  # Raised when a task isn't found.
  class TaskNotFound < RuntimeError; end

  # Raised when a command returns a non-zero exit status.
  class FailedCommand < RuntimeError; end

  class ExecuteError < RuntimeError
    attr_accessor :status
    def initialize (status)
      @status = status
    end
  end

end
