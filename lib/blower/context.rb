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

    # The target hosts.
    attr_accessor :hosts

    def initialize (path)
      @path = path
      @hosts = []
      @have_seen = {}
    end

    def log
      Logger.instance
    end

    def add_host (spec)
      host = Host.new(*spec) unless spec.is_a?(Host)
      @hosts << host
    end

    # Execute the block on one host.
    # @param host Host to use. If nil, a random host is picked.
    def one_host (host = nil, &block)
      map [host || target.hosts.sample], &block
    end

    # Execute the block once for each host.
    # Each block executes in a copy of the context.
    def each (hosts = @hosts, &block)
      map(hosts, &block)
      nil
    end

    # Execute the block once for each host.
    # Each block executes in a copy of the context.
    def map (hosts = @hosts, &block)
      Kernel.fail "No hosts left" if hosts.empty?
      hosts.map do |host|
        Thread.new do
          block.(host)
        end
      end.map(&:join)
    end

    # Reboot each host and waits for them to come back up.
    # @param command The reboot command. A string.
    def reboot (command = "reboot")
      each do
        begin
          sh command
        rescue IOError
        end
        log.debug "Waiting for server to go away..."
        sleep 0.1 while ping(true)
        log.debug "Waiting for server to come back..."
        sleep 1.0 until ping(true)
      end
    end

    # Execute a shell command on each host.
    def sh (command, quiet = false)
      log.info "sh: #{command}" unless quiet
      map do |host|
        status = host.sh(command)
        fail host, "#{command}: exit status #{status}" if status != 0
      end
    end

    # Execute a command on the remote host.
    # @return false if the command exits with a non-zero status
    def sh? (command, quiet = false)
      log.info "sh?: #{command}" unless quiet
      win = true
      map do |host|
        status = host.sh(command)
        win = false if status != 0
      end
      win
    end

    # Execute a command on the remote host.
    # @return false if the command exits with a non-zero status
    def ping (quiet = false)
      log.info "ping" unless quiet
      win = true
      map do |host|
        win &&= host.ping
      end
      win
    end

    def fail (host, message)
      @hosts -= [host]
    end

    # Copy a file or readable to the host filesystem.
    # @param from An object that responds to read, or a string which names a file, or an array of either.
    # @param to A string.
    def cp (from, to)
      log.info "cp: #{from} -> #{to}"
      map do |host|
        host.cp(from, to)
      end
    end

    # Writes a string to a file on the host filesystem.
    # @param string The string to write.
    # @param to A string.
    def write (string, to)
      log "upload data to #{to}", :debug
      target.cp(StringIO.new(string), to)
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
    def run (task, optional: false)
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
        if optional
          return
        else
          fail "can't find #{task}"
        end
      else
        log.info "Running #{task}" do
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

end
