module Blower

  class HostGroup

    attr_accessor :hosts
    attr_accessor :root
    attr_accessor :location

    def initialize (hosts)
      @hosts = hosts
    end

    def sh (command = nil, *args, &block)
      each do |host|
        command = block.() if block
        host.sh(command)
      end
    end

    def cp (from, to)
      each do |host|
        host.cp(from, to)
      end
    end

    def each (&block)
      hosts.map do |host|
        Thread.new do
          block.(host)
        end
      end.map(&:join)
    end

  end

end
