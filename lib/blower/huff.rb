module Blower
class Huff

  attr_accessor :hosts, :log, :puffs, :env

  def initialize ()
    @hosts = ["127.0.0.1"]
    @log = Logger.new
    @logdent = 0
    @puffs = Hash.new { |h, k| h[k] = Puff.new(self, k) }
    @env = {}
  end

  def hosts (hosts)
    log.info "new hosts: #{hosts.join(", ")}"
    @hosts = hosts
  end

  def ruby (task)
    instance_eval(File.read(task), task)
  end

  def shell (task)
    @hosts.each do |host|
      log.info "running #{task} on #{host}" do
        puffs[host].shell(task)
      end
    end
  end

  def inventory (task)
    hosts File.read(task).split
  end

  def run (name)
    name = name.to_s
    task = File.exist?(name) ? name : Dir[name + ".*"].first
    if !task
      fail "Can't find #{name}"
    elsif File.directory?(task)
      Dir.chdir(task) do
        run("main")
      end
    elsif task =~ /\.rb$/
      ruby(task)
    elsif task =~ /\.sh$/
      shell(task)
    elsif task =~ /\.ini$/
      inventory(task)
    else
      fail "Don't know what to do with #{task}"
    end
  end

end
end
