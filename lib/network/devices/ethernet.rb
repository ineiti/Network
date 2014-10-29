module Network
  module Device
    class Ethernet < Stub
      @ids = [{class: 'net', uevent: {interface: 'eth.*'}}]

      def start

      end

      def stop

      end

      def may_stop

      end

      def status
        CONNECTED
      end

      def status_old
        4
      end

      def reset

      end

      def down

      end
    end
  end
end