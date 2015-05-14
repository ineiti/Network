require 'helper_classes'

module Network
  module Device
    class Simulation < Stub
      attr_accessor :connection_status
      include HelperClasses::DPuts
      @ids = [{bus: 'simulation', uevent: {interface: 'simul0'}}]
      @credit = 100
      @connection = false
      @sms = []
      @sms_index = 0

      def initialize(dev)
        dputs(2) { 'Got a new simulation device' }
        super(dev)
        @operator = Operator.search_name(:simulation, self)
        @connection_status = DISCONNECTED
      end

      def connection_may_stop

      end

      def reset

      end

      def down

      end

      def credit_left
        @credit
      end

      def credit_add
      end

      def credit_mn
      end

      def credit_mb
      end

      def connection_start
        dputs(3) { 'Starting connection' }
        @connection = CONNECTED
      end

      def connection_stop
        dputs(3) { 'Stopping connection' }
        @connection = DISCONNECTED
      end

      def connection_status
        @connection
      end

      def sms_list
        if @sms.length == 0
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

      def self.load
        Device.add(@ids.first)
      end
    end
  end
end
