require 'net/ssh'
require 'net/scp'

module Blower

  class Host
    extend Forwardable

    attr_accessor :name
    attr_accessor :user
    attr_accessor :log
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
      @log = Logger.new("#{user}@#{name.ljust(15)} | ")
      @data = {}
    end

    def ping ()
      Timeout.timeout(1) do
        TCPSocket.new(name, 22).close
      end
      true
    rescue Timeout::ExitException
      false
    rescue Errno::ECONNREFUSED
      false
    end

    def cp (from, to, quiet: false)
      if from.is_a?(String)
        to += File.basename(from) if to[-1] == "/"
        system("rsync", "-r", "--progress", from, "#{@user}@#{@name}:#{to}")
      elsif from.is_a?(Array)
        to += "/" unless to[-1] == "/"
        system("rsync", "-r", "--progress", *from, "#{@user}@#{@name}:#{to}")
      elsif from.is_a?(StringIO) or from.is_a?(IO)
        log.info "string -> #{to}" unless quiet
        ssh.scp.upload!(from, to)
      else
        fail "Don't know how to copy a #{from.class}: #{from}"
      end
    end

    private

    def ssh ()
      @ssh = nil if @ssh && @ssh.closed?
      @ssh ||= Net::SSH.start(name, user)
    end

    def sh (command, quiet: false, stdout: STDOUT, stderr: STDERR)
      log.info command unless quiet
      result = nil
      ch = ssh.open_channel do |ch|
        ch.exec(command) do |_, success|
          fail "failed to execute command" unless success
          ch.on_data do |_, data|
            stdout << data
          end
          ch.on_extended_data do |_, _, data|
            stderr << data
          end
          ch.on_request("exit-status") { |_, data| result = data.read_long }
        end
      end
      ch.wait
      result == 0 ? true : raise(ExecuteError.new(result))
    end

    end

  end

end
