module Network
  module Operator
    attr_accessor :operators
    extend HelperClasses::DPuts
    extend self
    MISSING = -1
    CONNECTED = 1
    DISCONNECTED = 2
    ERROR = 3

    CONNECTION_ALWAYS = 1
    CONNECTION_ONDEMAND = 2

    @operators = {}

    def search_name(name, dev)
      op = @operators.select{|k,v|
        k == name.to_s
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

=begin
      Methods needed:

      :internet_left, :internet_add, :internet_cost,
      :credit_left, :credit_add, :credit_send,
      :has_promo, :user_cost_max
=end
    class Stub
      attr_accessor :connection_type,
                    :cost_base, :cost_shared, :allow_free
      extend HelperClasses::DPuts

      @connection_type = CONNECTION_ALWAYS
      @cost_base = 10
      @cost_shared = 10
      @allow_free = false

      def initialize(dev)
        @device = dev
      end

      def self.inherited(other)
        ddputs(2) { "Inheriting operator #{other.inspect}" }
        Operator.operators[other.to_s.sub(/.*::/, '')] = other
        super(other)
      end
    end
  end

  Operator.load
end
