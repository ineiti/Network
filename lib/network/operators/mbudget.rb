module Network
  module Operator
    class MBudget < Stub
      def initialize(device)
        super(device)
        @services = %i(connection sms ussd )
      end

      def internet_left
        1_000_000_000
      end

      def internet_add

      end

      def internet_cost
        [[0,0]]
      end

      def credit_left
        100
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

      def self.operator_match(n)
        n =~ /(m-budget|mbudget)/i
      end

      def name
        'M-Budget'
      end
    end
  end
end