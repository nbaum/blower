require 'forwardable'

module Blower

  # Blower tasks are executed within a context.
  #
  # The context can be used to share information between tasks, by storing it in instance variables.
  #
  class Context
    extend Forwardable

    # Search path for tasks.
    attr_accessor :path

    # The current target of operations. Usually a Host, HostGroup, or MockHost.
    attr_accessor :target

    def initialize (path)
      @path = path
      @have_seen = {}
    end

    # Send a message to the logger, prefixing it with the target name, if it has one.
    # Passes the block through to the logger.
    def log (message, level, &block)
      message = "(on #{target.name}) " + message if target.respond_to?(:name)
      Logger.instance.log(message, level, &block)
    end

    # Log an INFO message.
    def stage (message, &block)
      log message, :info, &block
    end

    # Execute the block on one host.
    # @param host Host to use. If nil, a random host is picked.
    def one_host (host = nil, &block)
      each_host [host || target.hosts.sample], &block
    end

    # Execute the block once for each host.
    # Each block executes in a copy of the context.
    def each_host (hosts = target, &block)
      hosts.each do |host|
        ctx = dup
        ctx.target = host
        ctx.instance_exec(&block)
      end
    end

    # Reboot each host and waits for them to come back up.
    # @param command The reboot command. A string.
    def reboot (command = "reboot")
      each_host do
        begin
          sh command
        rescue IOError
          sleep 0.1 while ping
          sleep 1.0 until ping
        end
      end
    end

    # Execute a shell command on each host.
    def sh (command)
      log "execute #{command}", :debug
      target.sh(command)
    end

    # Copy a file or readable to the host filesystem.
    # @param from An object that responds to read, or a string which names a file, or an array of either.
    # @param to A string.
    def cp (from, to)
      log "upload #{Array(from).join(", ")} -> #{to}", :debug
      target.cp(from, to)
    end

    # Writes a string to a file on the host filesystem.
    # @param string The string to write.
    # @param to A string.
    def write (string, to)
      log "upload data to #{to}", :debug
      target.cp(StringIO.new(string), to)
    end

    # Execute a command on the remote host.
    # @return false if the command exits with a non-zero status
    def sh? (command)
      log "execute #{command}", :debug
      target.sh(command)
    rescue Blower::Host::ExecuteError
      false
    end

    # Capture the output a command on the remote host.
    # @return (String) The combined stdout and stderr of the command.
    def capture (command)
      stdout = ""
      target.sh(command, stdout)
      stdout
    end

    # Run a task.
    # @param task (String) The name of the task
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
