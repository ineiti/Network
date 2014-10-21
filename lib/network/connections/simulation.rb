require 'helperclasses'

module Network
  module Modems
    class Simulation < Modem
      include HelperClasses::DPuts
      @@present = false
      @@credit = 100
      @@connection = false
      @@sms = []
      @@sms_index = 0

      def credit_left
        @@credit
      end

      def credit_add
      end

      def credit_mn
      end

      def credit_mb
      end

      def connection_start
        dputs(3) { 'Starting connection' }
        @@connection = MODEM_CONNECTED
      end

      def connection_stop
        dputs(3) { 'Stopping connection' }
        @@connection = MODEM_DISCONNECTED
      end

      def connection_status
        @@connection
      end

      def sms_list
        if @@sms.length == 0
          []
        else
          list._Messages._Message.map { |msg|
            msg.keep_if { |k, v| %w( Index Phone Content Date ).index k.to_s }.to_sym
          }.sort_by { |m| m._Index.to_i }
        end
      end

      def sms_send(nbr, msg)
      end

      def sms_delete(index)
      end

      def traffic_stats
        {:rx => -1, :tx => -1}
      end

      def set_2g
      end

      def traffic_reset
        @traffic = 0
      end

      def add_sms(phone, content, date = Date.today)
        @sms.push({:Index => @@sms_index += 1, :Phone => phone,
                   :Content => content, :Date => date})
      end

      def self.modem_present?
        @@present
      end
    end
  end
end
