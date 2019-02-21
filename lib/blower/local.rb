require 'net/ssh'
require 'net/ssh/gateway'
require 'net/scp'
require 'monitor'
require 'base64'
require 'timeout'

module Blower

  class Local
    include MonitorMixin
    extend Forwardable

    attr_reader :name, :data

    def_delegators :data, :[], :[]=

    def initialize (name, proxy: nil)
      @name, @proxy = name, proxy
      @data = {}
    end

    # Represent the host as a string.
    def to_s
      @name
    end

    def sh (command, as: nil, quiet: false)
      command = "#{@proxy} #{command.shellescape}" if @proxy
      IO.popen(command).read
    end

    # Produce a Logger prefixed with the host name.
    # @api private
    def log
      @log ||= Logger.instance.with_prefix("on #{name}: ")
    end

  end

end
