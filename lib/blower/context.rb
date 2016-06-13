require 'erb'
require 'json'
require 'forwardable'

module Blower

  # Blower tasks are executed within a context.
  #
  # The context can be used to share information between tasks by storing it in instance variables.
  #
  class Context
    extend Forwardable

    # YARD documentation macros

    # @macro [new] onable
    #   @param [Array] on The hosts to operate on. Defaults to the context's current host list.

    # @macro [new] asable
    #   @param [#to_s] as The remote user to operate as. Defaults to the context's current user if that is not nil, and the host's configured user otherwise.

    # @macro [new] quietable
    #   @param [Boolean] quiet Whether to suppress log messages.

    # @macro [new] onceable
    #   @param [String] once If non-nil, only perform the operation if it hasn't been done before as per #once.

    # Search path for tasks.
    attr_accessor :path

    # The target hosts.
    attr_accessor :hosts

    # Username override. If not-nil, this user is used for all remote accesses.
    attr_accessor :user

    # The file name of the currently running task.
    # Context#cp interprets relative file names relative to this file name's directory component.
    attr_accessor :file

    # Create a new Context.
    # @param [Array] path The search path for tasks.
    def initialize (path)
      @path = path
      @data = {}
      @hosts = []
    end

    # Return a context variable.
    # @param name The name of the variable.
    # @param default The value to return if the variable is not set.
    def get (name, default = nil)
      @data.fetch(name, default)
    end

    # Remove context variables
    # @param names The names to remove from the variables.
    def unset (*names)
      names.each do |name|
        @data.delete name
      end
    end

    # Merge the hash into the context variables.
    # @param [Hash] hash The values to merge into the context variables.
    def set (hash)
      @data.merge! hash
    end

    # Yield with the hash temporary merged into the context variables.
    # Only variables specifically named in +hash+ will be reset when the yield returns.
    # @param [Hash] hash The values to merge into the context variables.
    # @return Whatever the yielded-to block returns.
    # @macro quietable
    def with (hash, quiet: false)
      old_values = data.values_at(hash.keys)
      log.debug "with #{hash}", quiet: quiet do
        set hash
        yield
      end
    ensure
      hash.keys.each.with_index do |key, i|
        @data[key] = old_values[i]
      end
    end

    # Yield with a temporary host list
    # @macro quietable
    def on (*hosts, quiet: false)
      let :@hosts => hosts.flatten do
        log.info "on #{@hosts.map(&:name).join(", ")}", quiet: quiet do
          yield
        end
      end
    end

    # Yield with a temporary username override
    # @macro quietable
    def as (user, quiet: false)
      let :@user => user do
        log.info "as #{user}", quiet: quiet do
          yield
        end
      end
    end

    # Find and execute a task. For each entry in the search path, it checks for +path/task.rb+, +path/task/blow.rb+,
    # and finally for bare +path/task+. The search stops at the first match.
    # If found, the task is executed within the context, with +@file+ bound to the task's file name.
    # @param [String] task The name of the task.
    # @macro quietable
    # @macro onceable
    # @raise [TaskNotFound] If no task is found.
    # @raise Whatever the task itself raises.
    # @return The result of evaluating the task file.
    def run (task, optional: false, quiet: false, once: nil)
      once once, quiet: quiet do
        log.info "run #{task}", quiet: quiet do
          file = find_task(task)
          code = File.read(file)
          let :@file => file do
            instance_eval(code, file)
          end
        end
      end
    rescue TaskNotFound => e
      return if optional
      raise e
    end

    # Execute a shell command on each host
    # @macro onable
    # @macro asable
    # @macro quietable
    # @macro onceable
    def sh (command, as: user, on: hosts, quiet: false, once: nil)
      self.once once, quiet: quiet do
        log.info "sh #{command}", quiet: quiet do
          hash_map(hosts) do |host|
            host.sh command, as: as, quiet: quiet
          end
        end
      end
    end

    # Copy a file or readable to the host filesystems.
    # @overload cp(readable, to, as: user, on: hosts, quiet: false)
    #   @param [#read] from An object from which to read the contents of the new file.
    #   @param [String] to The file name to write the string to.
    #   @macro onable
    #   @macro asable
    #   @macro quietable
    #   @macro onceable
    # @overload cp(filename, to, as: user, on: hosts, quiet: false)
    #   @param [String] from The name of the local file to copy.
    #   @param [String] to The file name to write the string to.
    #   @macro onable
    #   @macro asable
    #   @macro quietable
    #   @macro onceable
    def cp (from, to, as: user, on: hosts, quiet: false, once: nil)
      self.once once, quiet: quiet do
        log.info "cp: #{from} -> #{to}", quiet: quiet do
          Dir.chdir File.dirname(file) do
            hash_map(hosts) do |host|
              host.cp from, to, as: as, quiet: quiet
            end
          end
        end
      end
    end

    # Reads a remote file from each host.
    # @param [String] filename The file to read.
    # @return [Hash] A hash of +Host+ objects to +Strings+ of the file contents.
    # @macro onable
    # @macro asable
    # @macro quietable
    def read (filename, as: user, on: hosts, quiet: false)
      log.info "read: #{filename}", quiet: quiet do
        hash_map(hosts) do |host|
          host.read filename, as: as
        end
      end
    end

    # Writes a string to a file on the host filesystems.
    # @param [String] string The string to write.
    # @param [String] to The file name to write the string to.
    # @macro onable
    # @macro asable
    # @macro quietable
    # @macro onceable
    def write (string, to, as: user, on: hosts, quiet: false, once: nil)
      self.once once, quiet: quiet do
        log.info "write: #{string.bytesize} bytes -> #{to}", quiet: quiet do
          hash_map(hosts) do |host|
            host.write string, to, as: as, quiet: quiet
          end
        end
      end
    end

    # Renders and installs files from ERB templates. Files are under +from+ in ERB format. +from/foo/bar.conf.erb+ is
    # rendered and written to +to/foo/bar.conf+. Non-ERB files are ignored.
    # @param [String] from The directory to search for .erb files.
    # @param [String] to The remote directory to put files in.
    # @macro onable
    # @macro asable
    # @macro quietable
    # @macro onceable
    def render (from, to, as: user, on: hosts, quiet: false, once: nil)
      self.once once, quiet: quiet do
        Dir.chdir File.dirname(file) do
          (Dir["#{from}**/*.erb"] + Dir["#{from}**/.*.erb"]).each do |path|
            template = ERB.new(File.read(path))
            to_path = to + path[from.length..-5]
            log.info "render: #{path} -> #{to_path}", quiet: quiet do
              hash_map(hosts) do |host|
                host.cp StringIO.new(template.result(binding)), to_path, as: as, quiet: quiet
              end
            end
          end
        end
      end
    end

    # Ping each host by trying to connect to port 22
    # @macro onable
    # @macro quietable
    def ping (on: hosts, quiet: false)
      log.info "ping", quiet: quiet do
        hash_map(hosts) do |host|
          host.ping
        end
      end
    end

    # Execute a block only once per host.
    # It is usually preferable to make tasks idempotent, but when that isn't
    # possible, +once+ will only execute the block on hosts where a block
    # with the same key hasn't previously been successfully executed.
    # @param [String] key Uniquely identifies the block.
    # @param [String] store File to store +once+'s state in.
    # @macro quietable
    def once (key, store: "/var/cache/blower.json", quiet: false)
      return yield unless key
      log.info "once: #{key}", quiet: quiet do
        hash_map(hosts) do |host|
          done = begin
            JSON.parse(host.read(store, quiet: true))
          rescue => e
            {}
          end
          unless done[key]
            on [host] do
              yield
            end
            done[key] = true
            host.write(done.to_json, store, quiet: true)
          end
        end
      end
    end

    private

    def hash_map (hosts = self.hosts)
      {}.tap do |result|
        each(hosts) do |host|
          result[host] = yield(host)
        end
      end
    end

    def each (hosts = self.hosts)
      fail "No hosts" if hosts.empty?
      [hosts].flatten.each do |host|
        begin
          yield host
        rescue => e
          host.log.error e.message
          hosts.delete host
        end
      end
      fail "No hosts remaining" if hosts.empty?
    end

    def find_task (name)
      log.debug "Searching for task #{name}" do
        path.each do |path|
          log.trace "checking #{File.join(path, name + ".rb")}"
          file = File.join(path, name + ".rb")
          return file if File.exists?(file)
          log.trace "checking #{File.join(path, name, "/blow.rb")}"
          file = File.join(path, name, "/blow.rb")
          return file if File.exists?(file)
          log.trace "checking #{File.join(path, name)}"
          file = File.join(path, name)
          return file if File.exists?(file)
        end
      end
      fail TaskNotFound, "Task not found: #{name}"
    end

  end

end
