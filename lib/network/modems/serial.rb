#require 'huawei_modem'
require 'helperclasses'
require 'serialmodem'

module Network
  module Modems
    class Serial < Modem
      include HelperClasses::DPuts
      include SerialModem

      def initialize
        @connection = MODEM_ERROR
        setup
        connection_status
      end

      def credit_left
        ussd_send('*100#')
        @serial_ussd_results['*100#']
      end

      def credit_add(code)
        ussd_send("*128*#{code}#")
      end

      def credit_mn
      end

      def credit_mb
      end

      def connection_start
        ddputs(3) { 'Starting connection' }
        @connection = MODEM_CONNECTING
        Kernel.system('netctl restart ppp0')
      end

      def connection_stop
        ddputs(3) { 'Stopping connection' }
        @connection = MODEM_DISCONNECTING
        Kernel.system('netctl stop ppp0')
      end

      def connection_status
        @connection =
            if %x[ netctl status ppp0 | grep Active ] =~ /: active/
              if Kernel.system('grep -q ppp0 /proc/net/dev')
                if %x[ ifconfig ppp0 ]
                  MODEM_CONNECTED
                else
                  MODEM_CONNECTING
                end
              else
                MODEM_CONNECTION_ERROR
              end
            else
              MODEM_DISCONNECTED
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

      def traffic_stats
        {rx: 0, tx: 0}
      end

      def traffic_reset

      end

      def set_2g
        set_connection_type('2g')
      end

      def set_3g
        set_connection_type('3g')
      end

      def self.modem_present?
        File.exists? '/dev/ttyUSB2'
        #Kernel.system('lsusb -d 12d1:1506 > /dev/null') ||
        #    Kernel.system('lsusb -d 12d1:14ac > /dev/null')
      end
    end
  end
end
