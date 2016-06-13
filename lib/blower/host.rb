require 'net/ssh'
require 'net/scp'
require 'monitor'
require 'colorize'
require 'timeout'

module Blower

  class Host
    include MonitorMixin
    extend Forwardable

    # The default remote user.
    attr_accessor :user

    # The host adress.
    attr_accessor :address

    def_delegators :data, :[], :[]=

    def initialize (address, data: {}, user: "root")
      @address = address
      @user = user
      @data = data
      super()
    end

    def name
      to_s
    end

    # Represent the host as a string.
    def to_s
      "#{@user}@#{@address}"
    end

    # Attempt to connect to port 22 on the host.
    # @return +true+
    # @raise If it doesn't connect within 1 second.
    # @api private
    def ping ()
      log.debug "Pinging"
      Timeout.timeout(1) do
        TCPSocket.new(address, 22).close
      end
      true
    rescue Timeout::Error, Errno::ECONNREFUSED
      fail "Failed to ping #{self}"
    end

    # Copy files or directories to the host.
    # @api private
    def cp (froms, to, as: nil, quiet: false)
      as ||= @user
      output = ""
      synchronize do
        [froms].flatten.each do |from|
          if from.is_a?(String)
            to += "/" if to[-1] != "/" && from.is_a?(Array)
            command = ["rsync", "-e", "ssh -oStrictHostKeyChecking=no", "-r"]
            command += [*from, "#{as}@#{@address}:#{to}"]
            log.trace command.shelljoin, quiet: quiet
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
                log.fatal "exit status #{$?.exitstatus}: #{command}", quiet: quiet
                log.fatal output, quiet: quiet
                fail "failed to copy files"
              end
            end
          elsif from.respond_to?(:read)
            cmd = "echo #{from.read.shellescape} > #{to.shellescape}"
            sh cmd, quiet: quiet
          else
            fail "Don't know how to copy a #{from.class}: #{from}"
          end
        end
      end
      true
    end

    # Write a string to a host file.
    # @api private
    def write (string, to, as: nil, quiet: false)
      cp StringIO.new(string), to, as: as, quiet: quiet
    end

    # Read a host file.
    # @api private
    def read (filename, as: nil, quiet: false)
      sh "cat #{filename.shellescape}", as: as, quiet: quiet
    end

    # Execute a command on the host and return its output.
    # @api private
    def sh (command, as: nil, quiet: false)
      as ||= @user
      output = ""
      synchronize do
        log.debug "sh #{command}", quiet: quiet
        result = nil
        ch = ssh(as).open_channel do |ch|
          ch.request_pty do |ch, success|
            "failed to acquire pty" unless success unless success
            ch.exec(command) do |_, success|
              fail "failed to execute command" unless success
              ch.on_data do |_, data|
                log.trace "received #{data.bytesize} bytes stdout", quiet: quiet
                output << data
              end
              ch.on_extended_data do |_, _, data|
                log.trace "received #{data.bytesize} bytes stderr", quiet: quiet
                output << data.colorize(:red)
              end
              ch.on_request("exit-status") do |_, data|
                result = data.read_long
                log.trace "received exit-status #{result}", quiet: quiet
              end
            end
          end
        end
        ch.wait
        fail FailedCommand, output if result != 0
        output
      end
    end

    # Produce a Logger prefixed with the host name.
    # @api private
    def log
      @log ||= Logger.instance.with_prefix("on #{self}: ")
    end

    private

    attr_accessor :data

    def ssh (user)
      @sessions ||= {}
      if @sessions[user] && @sessions[user].closed?
        log.warn "Discovered the connection to ssh:#{self} was lost"
        @sessions[user] = nil
      end
      @sessions[user] ||= begin
        log.debug "Connecting to ssh:#{self}"
        Net::SSH.start(address, user)
      end
    end

  end

end
