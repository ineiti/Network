require 'helper_classes'
require 'erb'

module Network
  class MobileControl
    attr_accessor :state_now, :state_goal, :state_error,
                  :min_traffic, :device, :operator, :autocharge, :phone_main,
                  :recharge_hold,
                  :connection_cmds_up, :connection_cmds_down,
                  :connection_services_up, :connection_services_down,
                  :connection_vpns
    extend HelperClasses::DPuts

    DEBUG_LVL = 2

    UNKNOWN = -1

    @operator = nil
    @autocharge = false

    def initialize
      @state_now = Device::DISCONNECTED
      @state_goal = UNKNOWN
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
      if @operator && @device
        false
      else
        @state_now = Device::DISCONNECTED
        true
      end
    end

    def operator_name
      operator_missing? ? 'Unknown' : @operator.name
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
              @device.serial_sms_new.push(Proc.new { |sms| new_sms(sms) })

              log_msg :MobileControl, "Got new device #{@device}"
            else
              dputs(2) { "New device #{dev.dev._path} has no option-driver" }
            end
          end
        when /operator/
          @operator = @device.operator
          @operator.add_observer(self, :update_operator)
          @operator.services.index(:credit) and
              update_operator(:credit_total, @operator.credit_left)
          @operator.services.index(:promotion) and
              update_operator(:internet_total, @operator.internet_left)
          @operator.services.index(:auto_connect) and
              update_operator(:internet_total, @operator.internet_left)
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
          rescue_all do
            log_msg :MobileControl, "Making sure we're connected #{@state_goal}"
            if @state_goal != Device::CONNECTED
              send_status("internet++: #{add}")
              connect
            end
          end
        when /internet_total/
          if @state_goal == UNKNOWN && @operator.internet_left > @min_traffic
            log_msg :MobileControl, 'Enough internet, connecting'
            connect
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
      msg.sub(/^cmd\s*:\s*/i, '').split('::').each { |cmdstr|
        log_msg :MobileControl, "Got command-str #{cmdstr.inspect}"
        cmd, attr = cmdstr.strip.split(/\s+/)
        case cmd.downcase
          when /^status$/
            disk_usage = %x[ df -h / | tail -n 1 ].gsub(/ +/, ' ').chomp
            ret.push "stat: #{System.run_str('hostname').chomp}:"+
                         " #{state_to_s} :: #{disk_usage} :: #{Time.now.strftime('%y%m%d-%H%M')}"
          when /^connect/
            connect
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
            send_email
            return false
          when /^charge/
            recharge_all(attr)
          when /^update_left/
            update_left
            return false
        end
      }
      ret.length == 0 ? nil : ret
    end

    def update_left
      return if operator_missing?
      @operator.update_internet_left(true)
      @operator.update_credit_left(true)
    end

    def connect(force = false)
      return if operator_missing?
      if force
        if @operator.internet_left.to_i <= 1_000_000
          @operator.internet_total( 100_000_000 )
        end
      else
        #@operator.update_internet_left(true)
        #@operator.update_credit_left(true)
      end
      @state_goal = Device::CONNECTED
      @state_error = 0
    end

    def disconnect
      @state_goal = Device::DISCONNECTED
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
            @state_goal = Device::DISCONNECTED
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

      # Do some actions when the connection changes
      if old != @state_now
        if @state_now == Device::CONNECTED
          log_msg :MobileControl, "Connection goes up, doing cmds: #{@connection_cmds_up.inspect} " +
                                    "services: #{@connection_services_up}, vpn: #{@connection_vpns}"
          Platform.connection_run_cmds(@connection_cmds_up)
          Platform.connection_services(@connection_services_up, :start)
          Platform.connection_vpn(@connection_vpns, :start)
          send_email
        elsif old == Device::CONNECTED
          log_msg :MobileControl, "Connection goes down, doing cmds: #{@connection_cmds_down.inspect} " +
                                    "services: #{@connection_services_down}, vpn: #{@connection_vpns}"
          Platform.connection_run_cmds(@connection_cmds_down)
          Platform.connection_services(@connection_services_down, :stop)
          Platform.connection_vpn(@connection_vpns, :stop)
        end
      end
    end

    def do_autocharge?
      @autocharge && !@recharge_hold
    end

    def recharge_all(credit = 0)
      return unless @operator
      (credit == 0 or credit.to_s.length == 0) and credit = @operator.credit_left
      credit = credit.to_i
      log_msg :MobileControl, "Recharging for #{credit}"
      if credit >= @operator.internet_cost_smallest
        @operator.internet_add_cost(credit)
        send_status("charge: #{credit}")
        @state_now != Device::CONNECTED and @state_now = UNKNOWN
      else
        log_msg :MobileControl, "#{credit} is smaller than smallest internet-cost"
      end
    end

    # Sends en email as soon as the NTP is synchronized, but doesn't wait longer than
    # 60 seconds
    def send_email
      Kernel.const_defined?(:MobileInfo) and
          System.ntpd_wait(60) do
            MobileInfo.send_email
          end
    end

    def send_status(msg = nil)
      Operator.phone_main.to_s.length > 0 and
          @device.sms_send(Operator.phone_main,
                           interpret_commands('cmd:status').push(msg).compact.join('::'))
      send_email
    end

    def new_sms(sms)
      dputs(3) { "SMS is: #{sms.inspect}" }
      Kernel.const_defined?(:SMSs) && SMSs.create(sms)
      rescue_all do
        if sms._msg =~ /^cmd/i
          dputs(2) { "Working on SMS #{sms.inspect}" }
          if (ret = interpret_commands(sms._msg))
            log_msg :MobileControl, "Sending to #{sms._number} - #{ret.inspect}"
            @device.sms_send(sms._number, ret.join('::'))
          end
          @device.sms_delete sms._id
        end
      end
    end
  end
end
