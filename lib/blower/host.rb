require 'net/ssh'
require 'net/scp'

module Blower

  class Host

    attr_accessor :name
    attr_accessor :user
    attr_accessor :log

    def self.from_inventory_line (line)
      new(line, "root")
    end

    def initialize (name, user)
      @name = name
      @user = user
      @log = Logger.new
    end

    def cp (from, to)
      to += File.basename(from) if to[-1] == "/"
      here = `md5sum #{from.shellescape}`.split(" ")[0]
      there = capture("md5sum #{to.shellescape}").split(" ")[0]
      if here == there
        log.info "#{from} -> #{to} (already there)"
      else
        log.info "#{from} -> #{to} (#{File.stat(from).size} bytes)"
        execute("rm #{to.shellescape}")
        ssh.scp.upload! from, to
      end
    end

    def sh (command)
      log.info command
      if (status = execute(*command)) != 0
        log.fail "exit status #{status}"
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
      @ssh ||= Net::SSH.start(name, user)
    end

    def execute (command)
      result = nil
      ch = ssh.open_channel do |ch|
        stdout, stderr = "", ""
        ch.exec(command) do |_, success|
          fail "failed to execute command" unless success
          ch.on_data do |_, data|
            stdout << data
            if i = stdout.rindex(/[\n\r]/)
              data, stdout = stdout[0..i], (stdout[(i + 1)..-1] || "")
              if block_given?
                yield :stdout, data
              else
                log.log data
              end
            end
          end
          ch.on_extended_data do |_, _, data|
            stderr << data
            if i = stderr.rindex(/[\n\r]/)
              data, stderr = stderr[0..i], (stderr[(i + 1)..-1] || "")
              if block_given?
                yield :stderr, data
              else
                log.fail data
              end
            end
          end
          ch.on_request("exit-status") { |_, data| result = data.read_long }
        end
      end
      ch.wait
      result
    end

  end

end
