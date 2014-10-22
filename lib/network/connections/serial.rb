#require 'huawei_modem'
require 'helperclasses'
require 'serialmodem'

module Network
  module Connection
    class Serial < Stub
      include HelperClasses::DPuts
      include SerialModem

      def initialize
        @connection = ERROR
        setup_modem
        status
      end

      def start
        ddputs(3) { 'Starting connection' }
        @connection = CONNECTING
        Kernel.system('netctl restart ppp0')
      end

      def stop
        ddputs(3) { 'Stopping connection' }
        @connection = DISCONNECTING
        Kernel.system('netctl stop ppp0')
      end

      def status
        @connection =
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

      def self.present?
        case System.run_str('lsusb')
          when /12d1:1506/, /12d1:14ac/, /12d1:1c05/
            true
          when /airtel-modem/
            true
          else
            false
        end
      end

      def present?
        self.present?
      end
    end
  end
end
