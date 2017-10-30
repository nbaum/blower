module Blower

  class Plugin
    extend Forwardable

    def_delegators :@context, *%i(get unset set with on as run sh cp read write render ping once)

    def initialize (context)
      @context = context
    end

  end

  def self.plugin (name, &body)
    Class.new(Plugin, &body).tap do |klass|
      Context.send :define_method, name do
        klass.new(self)
      end
    end
  end

end
