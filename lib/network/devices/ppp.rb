module Network
  module Device
    class PPP < Stub
      attr_accessor :serial

      @ids = [{class: 'net', uevent: {interface: 'ppp.*'}}]

      def initialize(dev)
        super(dev)
        @operator = nil
        @serial = nil
        if @serial = Device.present.find { |dev|
          dputs(3) { "Checking dev: #{dev.dev._dirs.inspect}" }
          dev.dev._dirs.find { |d| d =~ /ttyUSB/ }
        }
          @serial.add_observer(self)
          @operator = @serial.operator
          dputs(2) { "And found #{@operator.inspect} for #{@serial}" }
        end
      end

      def update(operation, dev = nil)
        if operation =~ /operator/
          if @serial
            @operator = @serial.operator
            log_msg :PPP, "Found new operator: #{@operator}"
            changed
            notify_observers(:operator)
          else
            log_msg :PPP, 'Got new operator without @serial'
          end
        end
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
        #@serial.delete_observer(self)
      end
    end
  end
end