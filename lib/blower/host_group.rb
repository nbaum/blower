module Blower

  class HostGroup

    attr_accessor :hosts
    attr_accessor :log

    def self.from_inventory (path)
      new(File.read(path).split("\n").map do |line|
        Host.from_inventory_line(line)
      end)
    end

    def initialize (hosts)
      @hosts = hosts
      @log = Logger.new
    end

    def run (task)
      Dir.chdir File.dirname task do
        instance_eval(File.read File.basename task + ".rb", task)
      end
    end

    def once (&block)
      hosts.sample.instance_exec(&block)
    end

    def method_missing (name, *args, &block)
      hosts.each do |host|
        host.__send__(name, *args, &block)
      end
    end

  end

end
