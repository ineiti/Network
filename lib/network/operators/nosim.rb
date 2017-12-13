module Network
  module Operator
    class NoSIM < Stub
      def initialize(device)
        super(device)
        @services = %i()
      end

      def internet_left
        0
      end

      def internet_add

      end

      def internet_cost
        [[0,0]]
      end

      def credit_left
        0
      end

      def credit_add

      end

      def credit_send

      end

      def has_promo
        false
      end

      def user_cost_max
        Operator.cost_base + Operator.cost_shared
      end

      def name
        :NoOperator
      end

      def self.operator_match(n)
        n =~ /(Limited Service)/i
      end
    end
  end
end