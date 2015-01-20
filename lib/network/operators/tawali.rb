module Network
  module Operator
    class Tawali < Stub
      attr_accessor :device, :credit_left, :internet_left

      def initialize(device)
        super( device )
        @credit_left = 100
        @internet_left = 100_000_000
      end

      def name
        :Tawali
      end
    end
  end
end