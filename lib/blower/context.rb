require 'forwardable'

module Blower

  class Context
    extend Forwardable

    attr_accessor :path
    attr_accessor :location
    attr_accessor :target
    attr_accessor :log

    def_delegators :target, :sh, :cp, :capture, :write, :reboot, :ping

    def initialize (path)
      @path = path
      @log = Logger.new
      @have_seen = {}
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
      files = []
      @path.each do |dir|
        name = File.join(dir, task)
        name += ".rb" unless File.exist?(name)
        if File.directory?(name)
          dirtask = File.join(name, File.basename(@task))
          dirtask += ".rb" unless File.exist?(dirtask)
          name = dirtask
          blowfile = File.join(name, "Blowfile")
          files << blowfile if File.exist?(blowfile) && !@have_seen[blowfile]
        end
        files << name if File.exist?(name)
        break unless files.empty?
      end
      if files.empty?
        fail "can't find #{task}"
      else
        begin
          old_task, @task = @task, task
          files.each do |file|
            @have_seen[file] = true
            instance_eval(File.read(file), file)
          end
        ensure
          @task = old_task
        end
      end
    end

  end

end
