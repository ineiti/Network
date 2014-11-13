module Network
  module Operator
    attr_accessor :operators,
                  :cost_base, :cost_shared, :allow_free
    extend HelperClasses::DPuts
    extend self
    MISSING = -1
    CONNECTED = 1
    DISCONNECTED = 2
    ERROR = 3

    CONNECTION_ALWAYS = 1
    CONNECTION_ONDEMAND = 2

    @operators = {}
    @cost_base = 10
    @cost_shared = 10
    @allow_free = false

    def search_name(name, dev)
      dputs(3) { "Looking for #{name}" }
      op = @operators.select { |k, v|
        name.to_s.downcase =~ /#{k.downcase}/
      }
      op.size > 0 ? op.first.last.new(dev) : nil
    end

    def load
      Dir[File.dirname(__FILE__) + '/operators/*.rb'].each { |f|
        dputs(3) { "Adding operator-file #{f}" }
        require(f)
      }
    end

    def list
      @operators.inspect
    end

    def list_names
      @operators.keys
    end

    def clean_config
      @cost_base &&= @cost_base.to_i
      @cost_shared &&= @cost_shared.to_i
      @allow_free = @allow_free == 'true'
    end

=begin
      Methods needed:

      :internet_left, :internet_add, :internet_cost,
      :credit_left, :credit_add, :credit_send,
      :has_promo, :user_cost_max
=end
    class Stub
      attr_accessor :connection_type
      extend HelperClasses::DPuts

      def initialize(dev)
        @device = dev
        dev.add_observer(self)
        @connection_type = CONNECTION_ALWAYS
      end

      def user_cost_max
        Operator.cost_base + Operator.cost_shared
      end

      def user_cost_now
        connected = Captive.users_connected.length
        Operator.cost_base + Operator.cost_shared / [1, connected].max
      end

      def name
        self.class.name
      end

      def update(operation, dev = nil)
        if operation =~ /del/
          log_msg :Operator, "Killing #{self}"
        end
      end

      def self.inherited(other)
        dputs(2) { "Inheriting operator #{other.inspect}" }
        Operator.operators[other.to_s.sub(/.*::/, '')] = other
        super(other)
      end
    end
  end

  Operator.load
end
