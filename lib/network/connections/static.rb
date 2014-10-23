module Network
  module Connection
    class Static < Stub
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

      def self.present?
        true
      end

      def present?
        self.present?
      end

      def reset

      end

      def down

      end
    end
  end
end