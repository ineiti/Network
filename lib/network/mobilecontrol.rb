require 'helperclasses'
require 'erb'

module Network
  class MobileControl
    attr_accessor :state_now, :state_goal, :state_error,
                  :min_traffic, :device, :operator, :autocharge, :phone_main,
                  :recharge_hold
    extend HelperClasses::DPuts

    UNKNOWN = -1

    @operator = nil
    @autocharge = false

    def initialize
      @state_now = Device::DISCONNECTED
      @state_goal = UNKNOWN
      @send_status = false
      @send_connected = false
      @state_error = 0
      @min_traffic = 100_000
      @traffic_goal = 0
      @recharge_hold = false
      @asked_add_internet = nil

      @device = nil
      Network::Device.add_observer(self)
      update('add', Network::Device.search_dev({uevent: {driver: 'option'}}).first)
    end

    def operator_missing?
      if @operator
        false
      else
        @state_now = Device::DISCONNECTED
        true
      end
    end

    def update(operation, dev = nil)
      dputs(3) { "Updating #{operation} with device #{dev}" }
      case operation
        when /del/
          if @device == dev
            log_msg :MobileControl, "Lost device #{@device}"
            @device.delete_observer(self)
            @device = @operator = nil
            @state_goal = UNKNOWN
          end
        when /add/
          if !@device && dev
            if dev.dev._uevent and dev.dev._uevent._driver == 'option'
              @device = dev
              @device.add_observer(self)
              if @device.operator
                update(:operator)
              end
              log_msg :MobileControl, "Got new device #{@device}"
            else
              log_msg :MobileControl, "New device #{dev.dev._path} has no option-driver"
            end
          end
        when /operator/
          @operator = @device.operator
          @operator.add_observer(self, :update_operator)
          log_msg :MobileControl, "Found operator #{@operator}"
        when /down/
          log_msg :MobileControl, "Downing device #{@device}"
      end
    end

    def update_operator(msg, add = 0)
      case msg
        when /credit_added/
          if do_autocharge?
            log_msg :MobileControl, "Got credit #{add} and autocharging on"
            recharge_all
          end
        when /credit_total/
          if do_autocharge? && operator.internet_left <= @min_traffic &&
              operator.credit_left >= operator.internet_cost_smallest
            log_msg :MobileControl, "Credit #{@credit_left}, no internet and autocharging on"
            recharge_all
          end
        when /internet_added/
          log_msg :MobileControl, "Making sure we're connected"
          if @state_goal != Device::CONNECTED
            make_connection
          end
        when /internet_total/
          if @state_goal == UNKNOWN && @operator.internet_left > @min_traffic
            log_msg :MobileControl, 'Enough internet, connecting'
            make_connection
            return
          elsif @state_goal != Device::CONNECTED || @operator.internet_left > @min_traffic
            return
          end
          log_msg :MobileControl, 'Not enough internet, checking for charge-possibility'
          @state_goal = Device::DISCONNECTED
          update_operator(:credit_total)
      end
    end

    def is_connected
      @state_now == Device::CONNECTED
    end

    def state_to_s
      "#{@state_now}:#{@state_goal}:#{@state_error}:" +
          if operator_missing?
            'noop'
          else
            "#{(@operator.internet_left / 1_000_000).separator("'")}Mo:" +
                "#{@operator.credit_left}CFAs"
          end
    end

    def interpret_commands(msg)
      ret = []
      msg.sub(/^cmd:/i, '').split('::').each { |cmdstr|
        log_msg :SMS, "Got command-str #{cmdstr.inspect}"
        cmd, attr = /^ *([^ ]*) *(.*) *$/.match(cmdstr)[1..2]
        case cmd.downcase
          when /^status$/
            disk_usage = %x[ df -h / | tail -n 1 ].gsub(/ +/, ' ').chomp
            ret.push "#{System.run_str('hostname').chomp}:"+
                         " #{state_to_s} :: #{disk_usage} :: #{Time.now}"
          when /^connect/
            make_connection
          when /^disconnect/
            @state_goal = Device::DISCONNECTED
          when /^bash:/
            ret.push %x[ #{attr}]
          when /^ping/
            ret.push 'pong'
          when /^sms/
            number, text = attr.split(';', 2)
            @device.sms_send(number, text)
          when /^email/
            Kernel.const_defined? :SMSinfo and SMSinfo.send_email
            return false
          when /^charge/

        end
      }
      ret.length == 0 ? nil : ret
    end

    def make_connection
      @operator.update_internet_left(true)
      @operator.update_credit_left(true)
      @state_goal = Device::CONNECTED
      @send_status = @send_connected = true
      @state_error = 0
    end

    def check_connection
      return if operator_missing?
      @operator.update_credit_left
      @operator.update_internet_left

      old = @state_now

      @state_now = @device.connection_status
      if @state_goal != @state_now
        if @state_now == Device::ERROR_CONNECTION
          @state_error += 1
          log_msg :MobileControl, 'Connection Error - stopping'
          @device.connection_stop
          sleep 2
          if @state_error > 5
            @state_goal = Connection::DISCONNECTED
          end
        elsif @state_goal == Device::DISCONNECTED
          log_msg :MobileControl, 'Goal is ::Disconnected'
          @device.connection_stop
        elsif @state_goal == Device::CONNECTED
          @device.connection_start
        end
      else
        @state_error = 0
      end

      # If Network-Actions are defined, call connection-handlers
      if Network.const_defined? :Actions && old != @state_now
        if @state_now == Device::CONNECTED
          Network::Actions.connection_up
        elsif old == Device::CONNECTED
          Network::Actions.connection_down
        end
      end
    end

    def do_autocharge?
      @autocharge && !@recharge_hold
    end

    def recharge_all(cfas = 0)
      return unless @operator
      (cfas == 0 or !cfas) and cfas = @operator.credit_left
      log_msg :MobileControl, "Recharging for #{cfas}"
      if cfas >= @operator.internet_cost_smallest
        @operator.internet_add_cost(cfas)
        @send_status = true
        @state_now != Device::CONNECTED and @state_now = UNKNOWN
      else
        log_msg :MobileControl, "#{cfas} is smaller than smallest internet-cost"
      end
    end

    def check_sms
      return if operator_missing?
      @device.sms_scan

      if @send_status
        Operator.phone_main.to_s.length > 0 and
            @device.sms_send(Operator.phone_main, interpret_commands('cmd:status').join('::'))
        @send_status = false
        Kernel.const_defined? :SMSinfo and SMSinfo.send_email
      end
      dputs(3) { "SMS are: #{sms.inspect}" }
      @device.sms_list.each { |sms|
        Kernel.const_defined? :SMSs and SMSs.create(sms)
        rescue_all do
          log_msg :MobileControl, "Working on SMS #{sms.inspect}"
          if sms._Content =~ /^cmd:/i
            if (ret = interpret_commands(sms._Content))
              log_msg :MobileControl, "Sending to #{sms._Phone} - #{ret.inspect}"
              @device.sms_send(sms._Phone, ret.join('::'))
            end
          end
        end
        @device.sms_delete(sms._Index)
      }
    end
  end
end
