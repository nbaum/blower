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

    def initialize (name, user = "root")
      @name = name
      @user = user
      @log = Logger.new("#{user}@#{name.ljust(15)} | ")
      @data = {}
    end

    def write (data, dest)
      log.info "writing #{dest}"
      execute("rm -f #{dest.shellescape}")
      ssh.scp.upload! StringIO.new(data), dest
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

    def reboot ()
      log.info "rebooting"
      begin
        sh "shutdown -r now"
      rescue IOError
        # Hopefully this is fine. Ugh.
      end
      tick = 0
      while ping
        tick += 1
        log.info "waiting for host to go away... #{"-\\|/"[tick % 4]}\r"
        sleep 0.1
      end
      until ping
        tick += 1
        log.info "waiting for host to come back... #{"-\\|/"[tick % 4]}\r"
        sleep 0.1
      end
      log.info "\nreboot finished"
    end

    def cp (src, dest)
      Array(src).each do |from|
        to = dest
        to += File.basename(from) if to[-1] == "/"
        here = `md5sum #{from.shellescape}`.split(" ")[0]
        there = capture("md5sum #{to.shellescape} 2> /dev/null").split(" ")[0]
        if here != there
          log.info "#{from} -> #{to} (#{File.stat(from).size} bytes)"
          execute("rm -f #{to.shellescape}")
          if File.stat(from).size > 1000000
            system("scp #{from} #{@user}@#{@name}:#{to}")
          else
            ssh.scp.upload! from, to
          end
        end
      end
    end

    def sh (command)
      log.info command
      if (status = execute(*command)) != 0
        fail "exit status #{status}"
      end
    end

    def capture (command)
      result = ""
      status = execute(*command) do |kind, data|
        if kind == :stderr
          log.fail data
        else
          result << data
        end
      end
      status = 0 ? result : fail(result)
    end

    private

    def ssh ()
      @ssh = nil if @ssh && @ssh.closed?
      @ssh ||= Net::SSH.start(name, user)
    end

    def execute (command, quiet: false, stdout: STDOUT, stderr: STDERR)
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
      result
    end

  end

end
