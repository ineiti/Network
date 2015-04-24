module Network
  module Operator
    class Simulation < Stub

      def initialize(dev)
        super(dev)
        @internet_left = @credit_left = -1
        @cost_base = 0
        @cost_shared = 0
      end
    end
  end
end

