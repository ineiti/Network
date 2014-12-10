module Network
  module Operator
    class Simulation < Stub

      def initialize(dev)
        super(dev)
        @internet_left = @credit_left = -1
      end
    end
  end
end

