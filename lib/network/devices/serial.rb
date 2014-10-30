#require 'huawei_modem'
require 'helperclasses'
require 'serialmodem'

module Network
  module Device
    class Serial < Stub
      include HelperClasses::DPuts
      include SerialModem

      @ids = [{bus: 'usb', uevent: {product: '12d1/1506/102'}, dirs: ['ep_02']},
              {bus: 'usb', uevent: {product: '12d1/14ac'}},
              {bus: 'usb', uevent: {product: '12d1/1c05'}}]

      def initialize(dev)
        super(dev)
        @connection_status = ERROR
        setup_modem(dev._dirs.find{|d| d =~ /ttyUSB/})
      end

      def connection_start
        ddputs(3) { 'Starting connection' }
        @connection_status = CONNECTING
        Kernel.system('netctl restart ppp0')
      end

      def connection_stop
        ddputs(3) { 'Stopping connection' }
        @connection_status = DISCONNECTING
        Kernel.system('netctl stop ppp0')
      end

      def connection_status
        @connection_status =
            if %x[ netctl status ppp0 | grep Active ] =~ /: active/
              if Kernel.system('grep -q ppp0 /proc/net/dev')
                if %x[ ifconfig ppp0 ]
                  CONNECTED
                else
                  CONNECTING
                end
              else
                ERROR_CONNECTION
              end
            else
              DISCONNECTED
            end
      end

      def sms_list
        sms_scan
        @serial_sms.collect { |sms_id, sms|
          {:Index => sms_id, :Phone => sms[1], :Date => sms[3],
           :Content => sms[4]}
        }.sort_by { |m| m._Index.to_i }
      end

      def ussd_list
        @serial_ussd_results
      end

      def set_2g
        set_connection_type('2g')
      end

      def set_3g
        set_connection_type('3g')
      end

      def down

      end
    end
  end
end
