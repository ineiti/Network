module Network
  module Operator
    attr_accessor :operators, :methods_needed, :connection_type,
                  :cost_base, :cost_shared, :allow_free
    extend self

    extend HelperClasses::DPuts

    MISSING = -1
    CONNECTED = 1
    DISCONNECTED = 2
    ERROR = 3

    CONNECTION_ALWAYS = 1
    CONNECTION_ONDEMAND = 2

    @operators = {}
    @operator = nil
    @connection_type = CONNECTION_ALWAYS
    @cost_base = 10
    @cost_shared = 10
    @allow_free = false


    @methods_needed = [
        :internet_left, :internet_add, :internet_cost,
        :credit_left, :credit_add, :credit_send,
        :has_promo, :user_cost_max
    ]

    def method_missing(name, *args)
      super(name, args) unless @methods_needed.index(name)
      raise NoOperator unless @operator
      @operator.send(name, *args)
    end

    def chose(op)
      dputs_func
      dputs(3) { "network-operators: #{@operators.inspect}" }
      raise 'OperatorNotFound' unless @operators.has_key? op.to_s
      raise 'ConnectionNotFound' unless Connection.available?
      @operator = @operators[op.to_s].new( Connection.available? )
      %w( credit_left internet_left ).each { |cmd|
        ddputs(3) { "Sending command #{cmd}" }
        @operator.send(cmd)
      }
      @operator
    end

    def name
      @operator and @operator.class.name.sub(/.*::/, '')
    end

    def load
      Dir[File.dirname(__FILE__) + '/operators/*.rb'].each { |f|
        dputs(3) { "Adding operator-file #{f}" }
        require(f)
      }
    end

    def present?
      @operator
    end

    class Stub
      extend HelperClasses::DPuts

      attr_accessor :modem

      def initialize( modem )
        @modem = modem
      end

      def self.inherited(other)
        ddputs(2) { "Inheriting operator #{other.inspect}" }
        Operator.operators[other.to_s.sub(/.*::/, '')] = other
        super(other)
      end

      def method_missing(name, *args)
        raise NotSupported if Operator.methods_needed.index name
        super(name, *args)
      end
    end
  end
end

Network::Operator.load