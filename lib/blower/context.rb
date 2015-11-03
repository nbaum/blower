require 'forwardable'

module Blower

  class Context
    extend Forwardable

    attr_accessor :path
    attr_accessor :location
    attr_accessor :target
    attr_accessor :log

    def_delegators :target, :sh, :cp, :capture, :write, :reboot

    def initialize (path)
      @path = path
      @log = Logger.new
    end

    def one_host (name = nil, &block)
      each_host [name || target.hosts.sample], &block
    end

    def each_host (hosts = target.hosts, &block)
      hosts.each do |host|
        begin
          target, @target = @target, host
          block.()
        ensure
          @target = target
        end
      end
    end

    def run (task)
      @path.each do |dir|
        name = File.join(dir, task)
        name += ".rb" unless File.exist?(name)
        fail "can't find #{task}" unless File.exist?(name)
        return instance_eval(File.read(name), name)
      end
    end

  end

end
