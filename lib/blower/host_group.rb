module Blower

  class HostGroup

    attr_accessor :hosts
    attr_accessor :log
    attr_accessor :root
    attr_accessor :location

    def self.from_inventory (path)
      new(File.read(path).split("\n").map do |line|
        Host.from_inventory_line(line)
      end)
    end

    def self.delegate (*names)
      names.each do |name|
        define_method name do |*args, &block|
          each do |host|
            host.__send__(name, *args, &block)
          end
        end
      end
    end

    delegate :sh, :cp, :capture, :reboot

    def initialize (hosts)
      @hosts = hosts
      @log = Logger.new
    end

    def each (&block)
      hosts.map(&block)
    end

  end

end
