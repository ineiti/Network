#require 'huawei_modem'
require 'helperclasses'
require 'serialmodem'

module Network
  module Device
    class Serial < Stub
      attr_accessor :connection_reset
      include HelperClasses::DPuts
      include HelperClasses::System
      include SerialModem
      include Observable

      #@ids = [{bus: 'usb', uevent: {product: '12d1.1506.102'}, dirs: ['ep_01']},
      #        {bus: 'usb', uevent: {product: '12d1.1506.102'}, dirs: ['ep_02']},
      #        {bus: 'usb', uevent: {product: '12d1/14ac'}},
      #        {bus: 'usb', uevent: {product: '19d2/fff1/0'}},
      #        {bus: 'usb', uevent: {product: '12d1/1c05.*'}, dirs: ['ep_01']}]
      @ids = [{bus: 'usb', uevent: {driver: 'option'}, dirs: ['ttyUSB0']}]

      def initialize(dev)
        #dputs_func
        super(dev)
        @connection_status = ERROR
        setup_modem(dev._dirs.find { |d| d =~ /ttyUSB/ })
        @operator = nil
        # Some operators need to reset the connection if there is only a small
        # amount of "promotion" left
        @connection_reset = {promotion: 0, transfer: 0}
        @promotion_left = 0
        if dev._uevent._product =~ /19d2.fff1.0/
          dputs(3) { 'ZTE-modem' }
          @netctl_dev = 'cdma'
          @network_dev = 'ppp0'
          @operator = Operator.search_name(:Tawali, self)
          changed
          notify_observers(:operator)
        else
          dputs(3) { 'Not ZTE-modem' }
          @netctl_dev = 'umts'
          @network_dev = 'ppp0'
          @thread_operator = Thread.new {
            dputs(2) { 'Starting search for operator' }
            rescue_all {
              (1..11).each { |i|
                dputs(3) { "Searching operator #{i}" }
                op_name = get_operator
                if @operator = Operator.search_name(op_name, self)
                  rescue_all do
                    log_msg :Serial, "Got new operator #{@operator}"
                    changed
                    log_msg :Serial, "Telling observers #{self.count_observers}"
                    notify_observers(:operator)
                  end
                  break
                else
                  dputs(1) { "Didn't find operator #{op_name}" }
                end
                sleep 2*i
              }
            }
          }
        end
      end

      def update(op, dev = nil)
        dputs(2) { op }
        dputs(2) { dev }
      end

      def connection_start
        dputs(2) { 'Starting connection' }
        @connection_status = CONNECTING
        Kernel.system("netctl restart #{@netctl_dev}")
      end

      def connection_restart
        dputs(2) { 'Restarting connection' }
        @connection_status = CONNECTING
        Kernel.system("netctl restart #{@netctl_dev}")
      end

      def connection_stop
        dputs(2) { 'Stopping connection' }
        @connection_status = DISCONNECTING
        Kernel.system("netctl stop #{@netctl_dev}")
      end

      def connection_status
        @connection_status =
            if System.run_str("netctl status #{@netctl_dev} | grep Active") =~ /: active/
              if System.run_bool "grep -q #{@network_dev} /proc/net/route"
                CONNECTED
              elsif System.run_bool 'pidof pppd'
                CONNECTING
              else
                ERROR_CONNECTION
              end
            elsif System.run_str("netctl status #{@netctl_dev} | grep Active") =~ /: inactive/
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
        @serial_ussd_results.reverse.collect { |u|
          "#{u._time} - #{u._code}: #{u._result}" }.join("\n")
      end

      def set_2g
        dp "*****  SETTING TO 2G ***** #{caller.inspect}"
        set_connection_type('2go')
      end

      def set_3g
        set_connection_type('3go')
      end

      def down
        dputs(2) { 'Downing Serial-module' }
        if @thread_operator
          @thread_operator.kill
          @thread_operator.join
          dputs(1) { 'Joined thread-operator' }
        end
        kill
      end
    end
  end
end
