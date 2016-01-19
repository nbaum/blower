require 'net/ssh'
require 'net/scp'
require 'monitor'
require 'colorize'
require 'timeout'

module Blower

  class Host
    include MonitorMixin
    extend Forwardable

    attr_accessor :name
    attr_accessor :user

    def_delegators :data, :[], :[]=

    class ExecuteError < Exception
      attr_accessor :status
      def initialize (status)
        @status = status
      end
    end

    def initialize (name, user = "root")
      @name = name
      @user = user
      @data = {}
      super()
    end

    def ping
      Timeout.timeout(1) do
        TCPSocket.new(name, 22).close
      end
      true
    rescue Timeout::ExitException
      false
    rescue Errno::ECONNREFUSED
      false
    end

    def cp (from, to, output = "")
      synchronize do
        if from.is_a?(String) || from.is_a?(Array)
          to += "/" if to[-1] != "/" && from.is_a?(Array)
          command = ["rsync", "-e", "ssh -oStrictHostKeyChecking=no", "-r", "--progress", *from,
                     "#{@user}@#{@name}:#{to}"]
          log.trace command.shelljoin
          IO.popen(command, in: :close, err: %i(child out)) do |io|
            until io.eof?
              begin
                output << io.read_nonblock(100)
              rescue IO::WaitReadable
                IO.select([io])
                retry
              end
            end
            io.close
            if !$?.success?
              log.fatal "exit status #{$?.exitstatus}: #{command}"
              log.raw output
            end
          end
        elsif from.respond_to?(:read)
          ssh.scp.upload!(from, to)
        else
          fail "Don't know how to copy a #{from.class}: #{from}"
        end
      end
      true
    end

    def sh (command, output = "")
      synchronize do
        log.debug command
        result = nil
        ch = ssh.open_channel do |ch|
          ch.exec(command) do |_, success|
            fail "failed to execute command" unless success
            ch.on_data do |_, data|
              log.trace "received #{data.bytesize} bytes stdout"
              output << data
            end
            ch.on_extended_data do |_, _, data|
              log.trace "received #{data.bytesize} bytes stderr"
              output << data.colorize(:red)
            end
            ch.on_request("exit-status") do |_, data|
              result = data.read_long
              log.trace "received exit-status #{result}"
            end
          end
        end
        ch.wait
        if result != 0
          log.fatal "exit status #{result}: #{command}"
          log.raw output
        end
        result
      end
    end

    # Execute the block with self as a parameter.
    # Exists to confirm with the HostGroup interface.
    def each (&block)
      block.(self)
    end

    private

    attr_accessor :data

    def log
      Logger.instance.with_prefix("(on #{name})")
    end

    def ssh
      if @ssh && @ssh.closed?
        log.trace "Discovered the connection to ssh:#{name}@#{user} was lost"
        @ssh = nil
      end
      @ssh ||= begin
        log.trace "Connecting to ssh:#{name}@#{user}"
        Net::SSH.start(name, user)
      end
    end

  end

end
