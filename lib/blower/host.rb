require 'net/ssh'
require 'net/scp'
require 'monitor'
require 'colorize'

module Blower

  class Host
    include MonitorMixin
    extend Forwardable

    attr_accessor :name
    attr_accessor :user
    attr_accessor :data

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

    def log
      Logger.instance
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
          IO.popen(["rsync", "-z", "-r", "--progress", *from, "#{@user}@#{@name}:#{to}"],
                   in: :close, err: %i(child out)) do |io|
            until io.eof?
              begin
                output << io.read_nonblock(100)
              rescue IO::WaitReadable
                IO.select([io])
                retry
              end
            end
          end
        elsif from.is_a?(StringIO) or from.is_a?(IO)
          log.info "string -> #{to}" unless quiet
          ssh.scp.upload!(from, to)
        else
          fail "Don't know how to copy a #{from.class}: #{from}"
        end
      end
      true
    rescue => e
      false
    end

    def sh (command, output = "")
      synchronize do
        result = nil
        ch = ssh.open_channel do |ch|
          ch.exec(command) do |_, success|
            fail "failed to execute command" unless success
            ch.on_data do |_, data|
              output << data
            end
            ch.on_extended_data do |_, _, data|
              output << data.colorize(:red)
            end
            ch.on_request("exit-status") { |_, data| result = data.read_long }
          end
        end
        ch.wait
        if result != 0
          log.fatal "failed on #{name}"
          log.raw output
          exit 1
        end
        result
      end
    end

    def each (&block)
      block.(self)
    end

    private

    def ssh
      @ssh = nil if @ssh && @ssh.closed?
      @ssh ||= Net::SSH.start(name, user)
    end

  end

end
