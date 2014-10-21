module Network

  module Operator
    attr_accessor :operators, :methods_needed

    include HelperClasses::DPuts

    MISSING = -1
    CONNECTED = 1
    DISCONNECTED = 2
    ERROR = 3

    @operators = {}
    @operator = nil

    @methods_needed = [
        :sms_list, :sms_send, :sms_delete,
        :internet_left, :internet_add,
        :credit_left, :credit_add, :credit_send
    ]

    def method_missing( name, *args )
      super( name, args ) unless @methods_needed.index( name )
      @operator ? @operator.send( name, args) : raise NoOperator
    end

    def self.list
      @@operators
    end

    def self.chose(op)
      @modem = Network::Modem.present? or raise 'NoModemPresent'

      dputs(3) { "network-operators: #{@@operators.inspect}" }
      raise 'OperatorNotFound' unless @@operators.has_key? op.to_s
      @operator = @@operators[op.to_s].instance
      @operator.modem = @modem
      %w( credit_left internet_left ).each { |cmd|
        ddputs(3) { "Sending command #{cmd}" }
        @operator.send(cmd)
      }
      @operator
    end

    def self.operators
      @operators
    end

    class Stub
      def self.inherited(other)
        dputs(2) { "Inheriting operator #{other.inspect}" }
        Operator.operators[other.to_s.sub(/.*::/, '')] = other
        super(other)
      end

      def method_missing( name, *args )
        raise NotSupported if Operator.methods_needed.index name
        super( name, args )
      end
    end
  end

  Dir[File.dirname(__FILE__) + '/operators/*.rb'].each { |f|
    dputs(3) { "Adding operator-file #{f}" }
    require(f)
  }

end