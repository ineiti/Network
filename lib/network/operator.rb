module Network
  class Operator
    include Singleton
    extend HelperClasses::DPuts
    include HelperClasses::DPuts

    @@operators = []
    @modem = Network::Modem.instance

    def initialize
    end

    def self.inherited(other)
      dputs(2) { "Inheriting operator #{other.inspect}" }
      @@operators << other
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

    def self.chose( op )
      dputs(3) { "network-operators: #{@@operators.inspect}" }
      @operator = @@operators.find op or raise 'OperatorNotFound'
      @operator.instance
    end
  end

  Dir[File.dirname(__FILE__) + "/operators/*.rb"].each { |f|
    dputs(3) { "Adding operator-file #{f}" }
    require(f)
  }

end