require 'helperclasses/system.rb'

module Network
  module Operator
    attr_accessor :operators, :start_loaded,
                  :cost_base, :cost_shared, :allow_free, :phone_main

    extend HelperClasses::DPuts
    include HelperClasses
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
    @phone_main = nil
    @start_loaded = false

    def search_name(name, dev)
      #dputs_func
      dputs(3) { "Looking for #{name}" }
      op = @operators.select { |k, v|
        dputs(3) { "Searching #{name} in #{k} - #{v.name.inspect}" }
        v.operator_match(name)
        #name.to_s.downcase =~ /#{v.name.downcase}/
      }
      ret = op.size > 0 ? op.first.last.new(dev) : nil
      dputs(3) { "And found #{ret.inspect} for #{op.inspect}" }
      ret
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
      @start_loaded = @start_loaded == 'true'
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

      def self.operator_match(n)
        name = self.name.gsub(/^.*::/, '').downcase
        dp "#{n.to_s.downcase} <-> #{name.inspect}"
        n.to_s.downcase == name
      end
    end
  end

  Operator.load
end
