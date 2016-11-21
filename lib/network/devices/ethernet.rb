module Network
  module Device
    class Ethernet < Stub
      @ids = [{class: 'net', uevent: {interface: 'eth.*'}},
              {class: 'net', uevent: {interface: 'em.*'}},
              {class: 'net', uevent: {interface: 'enp.*'}},
              {class: 'net', uevent: {interface: 'br.*'}}]

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