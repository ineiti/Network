require 'hilinkmodem'
require 'helperclasses'

module Network
  module Modems
    class Hilink < Modem
      include HelperClasses::DPuts

      def credit_left
      end

      def credit_add
      end

      def credit_mn
      end

      def credit_mb
      end

      def connection_start
        dputs(3) { 'Starting connection' }
        HilinkModem::Dialup.connect
      end

      def connection_stop
        dputs(3) { 'Stopping connection' }
        HilinkModem::Dialup.disconnect
      end

      def connection_status
        if status = HilinkModem::Monitoring.status
          dputs(3) { "#{status.inspect}" }
          case HilinkModem::Monitoring.status._ConnectionStatus.to_i
            when 20, 112..115
              MODEM_DISCONNECTED
            when 900
              MODEM_CONNECTING
            when 901
              MODEM_CONNECTED
            when 902
              MODEM_DISCONNECTED
            when 903
              MODEM_DISCONNECTING
            when 26, 32
              MODEM_CONNECTION_ERROR
            else
              MODEM_CONNECTION_ERROR
          end
        else
          dputs(1) { "No status received" }
          MODEM_ERROR
        end
      end

      def sms_list
        list = HilinkModem::SMS.list
        if !list or list._Count.to_i == 0
          []
        else
          list._Messages._Message.map { |msg|
            msg.keep_if { |k, v| %w( Index Phone Content Date ).index k.to_s }.to_sym
          }.sort_by { |m| m._Index.to_i }
        end
      end

      def sms_send(nbr, msg)
        HilinkModem::SMS.send(nbr, msg)
      end

      def sms_delete(index)
        HilinkModem::SMS.delete(index)
      end

      def traffic_stats
        if stats = HilinkModem::Monitoring.traffic_statistics
          dputs(3) { stats.inspect }
          {:rx => stats._TotalDownload, :tx => stats._TotalUpload}
        else
          {:rx => -1, :tx => -1}
        end
      end

      def set_2g
        HilinkModem::Network.set_connection_type("2g")
      end

      def traffic_reset
        HilinkModem::Monitoring.traffic_reset
      end

      def self.modem_present?
        Kernel.system('lsusb -d 12d1:14db > /dev/null')
      end
    end
  end
end
