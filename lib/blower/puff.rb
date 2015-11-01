require "net/ssh"
require "shellwords"

module Blower
class Puff

  attr_accessor :huff, :host, :log, :env

  def initialize (huff, host)
    @huff = huff
    @log = huff.log
    @host = host
    @env = {}
  end

  def env2shell ()
    huff.env.merge(@env).map do |name, value|
      next unless name =~ /\A[A-Za-z\d_]+\z/
      "#{name}=#{value.shellescape}"
    end.join("\n") + "\n"
  end

  def shell (task)
    Net::SSH.start(host, "root") do |ssh|
      command = File.read(task)
      status, signal = nil, nil
      ssh.open_channel do |ch|
        stdout, stderr = "", ""
        ch.exec(env2shell + command) do |_, success|
          fail "failed to execute command" unless success
          ch.on_data do |_, data|
            stdout << data
            if i = stdout.rindex(/[\n\r]/)
              data, stdout = stdout[0..i], (stdout[(i + 1)..-1] || "")
              log.log data
            end
          end
          ch.on_extended_data do |_, _, data|
            stderr << data
            if i = stderr.rindex(/[\n\r]/)
              data, stderr = stderr[0..i], (stderr[(i + 1)..-1] || "")
              log.fail data
            end
          end
          ch.on_request("exit-status") { |_, data| status = data.read_long }
          ch.on_request("exit-signal") { |_, data| signal = data.read_long }
        end
      end
      ssh.loop
      if status != 0
        fail "exit status #{status}"
      end
    end
  end

end
end
