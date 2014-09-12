#require 'huawei_modem'
require 'helperclasses'

module Network
  module Modems
    class HuaweiModem < Modem
      include HelperClasses::DPuts

      def initialize
        @connection = MODEM_ERROR
        HuaweiModem::setup
        connection_status
      end

      def credit_left
        HuaweiModem::ussd_send('*100#')
        @huawei_ussd_results['*100#']
      end

      def credit_add(code)
        HuaweiModem::ussd_send("*128*#{code}#")
      end

      def credit_mn
      end

      def credit_mb
      end

      def connection_start
        ddputs(3) { 'Starting connection' }
        @connection = MODEM_CONNECTING
        Kernel.system('netctl start ppp0')
      end

      def connection_stop
        ddputs(3) { 'Stopping connection' }
        @connection = MODEM_DISCONNECTING
        Kernel.system('netctl stop ppp0')
      end

      def connection_status
        @connection =
            if Kernel.system('netctl status ppp0 | grep Active') =~ /: active/
              if Kernel.system('ifconfig ppp0') =~ /ppp0/
                MODEM_CONNECTED
              else
                MODEM_CONNECTING
              end
            else
              MODEM_DISCONNECTED
            end
      end

      def sms_list
        HuaweiModem::sms_scan
        @huawei_sms.collect { |sms_id, sms|
          {:Index => sms_id, :Phone => sms[1], :Content => sms[3],
           :Date => sms[4]}
        }.sort_by { |m| m._Index.to_i }
      end

      def sms_send(nbr, msg)
        HuaweiModem::sms_send(nbr, msg)
      end

      def sms_delete(index)
        HuaweiModem::sms_delete(index)
      end

      def traffic_stats
        if stats = HuaweiModem::Monitoring.traffic_statistics
          dputs(3) { stats.inspect }
          {:rx => stats._TotalDownload, :tx => stats._TotalUpload}
        else
          {:rx => -1, :tx => -1}
        end
      end

      def set_2g
        HuaweiModem::Network.set_connection_type("2g")
      end

      def traffic_reset
        HuaweiModem::Monitoring.traffic_reset
      end

      def self.modem_present?
        Kernel.system('lsusb -d 12d1:1506 > /dev/null')
      end
    end
  end
end
