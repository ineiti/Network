module Network
  module Device
    class PPP < Stub
      @ids = [{class: 'net', uevent: {interface: 'ppp.*'}}]

      def initialize(dev)
        super(dev)
        @operator = nil
        dev = Device.present.find { |dev|
          dputs(3) { "Checking dev: #{dev}" }
          dev.operator
        } and @operator = dev.operator
        dputs(2) { "And found #{@operator.inspect}" }
      end

      def connection_start

      end

      def connection_stop

      end

      def connection_may_stop

      end

      def connection_status
        CONNECTED
      end

      def reset

      end

      def down

      end
    end
  end
end