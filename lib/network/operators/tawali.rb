module Network
  module Operator
    class Tawali < Stub
      def initialize(device)
        super(device)
        @services = %i(connection auto_connect)
        internet_total 100_000_000
      end

      def update_credit_left

      end

      def update_internet_left

      end

      def name
        :Tawali
      end
    end
  end
end