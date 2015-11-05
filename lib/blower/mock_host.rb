module Blower

  class MockHost
    extend Forwardable

    attr_accessor :log
    attr_accessor :data

    def_delegators :data, :[], :[]=

    def initialize (name)
      @log = Logger.new("mock #{name.ljust(15)} | ")
      @data = {}
    end

    def sh (command, stdout: nil, stdin: nil)
      log.info command
      sleep rand * 0.1
    end

    def cp (from, to, quiet: false)
      if from.is_a?(String)
        to += File.basename(from) if to[-1] == "/"
        log.info "#{from} -> #{to}" unless quiet
      elsif from.is_a?(Array)
        to += "/" unless to[-1] == "/"
        log.info "#{from.join(", ")} -> #{to}" unless quiet
      elsif from.is_a?(StringIO) or from.is_a?(IO)
        log.info "string -> #{to}" unless quiet
      else
        fail "Don't know how to copy a #{from.class}: #{from}"
      end
      sleep rand * 0.1
    end

    def each (&block)
      block.(self)
    end

  end

end
