module Network
  module Device
    class Ethernet < Stub
      @ids = [{class: 'net', uevent: {interface: 'eth.*'}}]

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