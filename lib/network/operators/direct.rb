module Network
  module Operator
    class Direct < Stub
      def internet_left
        1_000_000_000
      end

      def internet_add

      end

      def internet_cost
        0
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
    end
  end
end