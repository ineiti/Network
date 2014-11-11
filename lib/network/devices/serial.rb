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
              {bus: 'usb', uevent: {product: '12d1/1c05.*'}, dirs: ['ep_02']}]

      def initialize(dev)
        super(dev)
        @connection_status = ERROR
        setup_modem(dev._dirs.find { |d| d =~ /ttyUSB/ })
      end

      def connection_start
        ddputs(2) { 'Starting connection' }
        @connection_status = CONNECTING
        Kernel.system('netctl restart ppp')
      end

      def connection_stop
        ddputs(2) { 'Stopping connection' }
        @connection_status = DISCONNECTING
        Kernel.system('netctl stop ppp')
      end

      def connection_status
        @connection_status =
            if System.run_str('netctl status ppp | grep Active') =~ /: active/
              if System.run_bool 'grep -q ppp0 /proc/net/route'
                CONNECTED
              elsif System.run_bool 'pidof pppd'
                CONNECTING
              else
                ERROR_CONNECTION
              end
            elsif System.run_str('netctl status ppp | grep Active') =~ /: inactive/
              DISCONNECTED
            else
              ERROR_CONNECTION
            end
      end

      def sms_list
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
