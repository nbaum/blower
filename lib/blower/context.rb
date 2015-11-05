require 'forwardable'

module Blower

  class Context
    extend Forwardable

    attr_accessor :path
    attr_accessor :location
    attr_accessor :target

    def initialize (path)
      @path = path
      @have_seen = {}
    end

    def log (message, level, &block)
      message = "(on #{target.name}) " + message if target.respond_to?(:name)
      Logger.instance.log(message, level, &block)
    end

    def stage (message, &block)
      log message, :info, &block
    end

    def one_host (name = nil, &block)
      each_host [name || target.hosts.sample], &block
    end

    def each_host (hosts = target, parallel: true, &block)
      hosts.each do |host|
        ctx = dup
        ctx.target = host
        ctx.instance_exec(&block)
      end
    end

    def reboot
      begin
        sh "shutdown -r now"
      rescue IOError
        sleep 0.1 while ping
        sleep 1.0 until ping
      end
    end

    def sh (command)
      log "execute #{command}", :debug
      target.sh(command)
    end

    def cp (from, to)
      log "upload #{Array(from).join(", ")} -> #{to}", :debug
      target.cp(from, to)
    end

    def write (string, to)
      log "upload data to #{to}", :debug
      target.cp(StringIO.new(string), to)
    end

    def sh? (command)
      log "execute #{command}", :debug
      target.sh(command)
    rescue Blower::Host::ExecuteError
      false
    end

    def capture (command)
      stdout = ""
      target.sh(command, stdout)
      stdout
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
