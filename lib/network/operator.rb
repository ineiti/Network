module Network
  class Operator
    attr_accessor :modem

    include Singleton
    extend HelperClasses::DPuts
    include HelperClasses::DPuts

    @@operators = {}

    def self.inherited(other)
      ddputs(2) { "Inheriting operator #{other.inspect}" }
      @@operators[other.to_s.sub(/.*::/, '')] = other
      dp @@operators.inspect
      super(other)
    end

    @@methods_needed = [
        :credit_left, :credit_add, :credit_send,
        :internet_left, :internet_add, :internet_cost
    ]

    def method_missing(name, *args)
      raise NotSupported if @@methods_needed.index(name)
      super(name, args)
    end

    def respond_to?(name)
      return true if @@methods_needed.index(name)
      super(name)
    end

    def self.list
      @@operators
    end

    def self.chose(op)
      @modem = Network::Modem.present? or raise 'NoModemPresent'

      ddputs(3) { "network-operators: #{@@operators.inspect}" }
      raise 'OperatorNotFound' unless @@operators.has_key? op.to_s
      @operator = @@operators[op.to_s].instance
      @operator.modem = @modem
#      @operator.instance
#      @operator = Network::Operators::Tigo.instance
      @last_traffic = Time.now - 60
      if @modem.present?
        @get_vars = Thread.new {
          %w( credit_left, internet_left ).each { |cmd|
            ddputs(2) { "Sending command #{cmd}" }
            while !@operator.send(cmd) do
              sleep 1
            end
          }
        }
      end
      @operator
    end

    def self.operators
      @@operators
    end
  end

  Dir[File.dirname(__FILE__) + '/operators/*.rb'].each { |f|
    dputs(3) { "Adding operator-file #{f}" }
    require(f)
  }

end