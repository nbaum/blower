require 'monitor'
require 'base64'
require 'timeout'
require 'open3'

module Blower

  class Target
    include MonitorMixin
    extend Forwardable

    attr_reader :name, :data

    def_delegators :data, :[], :[]=

    def initialize (name, ssh: "ssh", scp: "scp")
      @name, @ssh, @scp = name, ssh, scp
      @data = {}
      super()
    end

    # Represent the host as a string.
    def to_s
      @name
    end

    # Copy files or directories to the host.
    # @api private
    def cp (froms, to, as: nil, quiet: false, delete: false)
      as ||= @user
      output = ""
      synchronize do
        [froms].flatten.each do |from|
          if from.is_a?(String)
            to += "/" if to[-1] != "/" && from.is_a?(Array)
            command = ["rsync", "-e", @ssh, "-r"]
            if File.exist?(".blowignore")
              command += ["--exclude-from", ".blowignore"]
            end
            command += ["--delete"] if delete
            command += [*from, ":#{to}"]
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
            cmd = "echo #{Base64.strict_encode64(from.read).shellescape} | base64 -d > #{to.shellescape}"
            sh cmd, quiet: quiet
          else
            fail "Don't know how to copy a #{from.class}: #{from}"
          end
        end
      end
      true
    end

    def sh (command, as: nil, quiet: false)
      marker, output = SecureRandom.hex(32), nil
      ssh do |i, o, _|
        i.puts "echo #{marker}"
        i.puts "sh -c #{command.shellescape} 2>&1"
        i.puts "STATUS_#{marker}=$?"
        i.puts "echo #{marker}"
        i.flush
        o.readline("#{marker}\n")
        output = o.readline("#{marker}\n")[0..-(marker.length + 2)]
        i.puts "echo $STATUS_#{marker}"
        status = o.readline.to_i
        if status != 0
          fail FailedCommand, output
        end
        output
      end
    end

    # Produce a Logger prefixed with the host name.
    # @api private
    def log
      @log ||= Logger.instance.with_prefix("on #{name}: ")
    end

    private

    def ssh
      unless @wait
        @stdin, @stdout, @stderr, @wait = Open3.popen3(@ssh)
      end
      yield @stdin, @stdout, @stderr
    end

  end

end
