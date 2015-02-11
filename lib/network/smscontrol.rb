require 'helperclasses'
require 'erb'

module Network
  class SMScontrol
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
      @sms_injected = []
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
            log_msg :SMScontrol, "Lost device #{@device}"
            @device.delete_observer(self)
            @device = @operator = nil
            @state_goal = UNKNOWN
          end
        when /add/
          if !@device && dev
            @device = dev
            @operator = @device.operator
            @device.add_observer(self)
            log_msg :SMScontrol, "Got new device #{@device} with operator #{@operator}"
          end
        when /operator/
          @operator = @device.operator
          log_msg :SMScontrol, "Found operator #{@operator}"
        when /down/
          log_msg :SMScontrol, "Downing device #{@device}"
      end
    end

    def is_connected
      @state_now == Device::CONNECTED
    end

    def state_to_s
      il = operator_missing? ? -1 : @operator.internet_left
      "#{@state_now}-#{@state_goal}-#{@state_error}-#{il}"
    end

    def inject_sms(content, phone = '1234',
                   date = Time.now.strftime('%Y-%m-%d %H:%M:%S'), index = -1)
      new_sms = {:Content => content, :Phone => phone,
                 :Date => date, :Index => index}
      @sms_injected.push(new_sms)
      dputs(2) { "Injected #{new_sms.inspect}: #{@sms_injected.inspect}" }
    end

    def interpret_commands(msg)
      ret = []
      msg.sub(/^cmd:/i, '').split("::").each { |cmdstr|
        log_msg :SMS, "Got command-str #{cmdstr.inspect}"
        cmd, attr = /^ *([^ ]*) *(.*) *$/.match(cmdstr)[1..2]
        case cmd.downcase
          when /^status$/
            disk_usage = %x[ df -h / | tail -n 1 ].gsub(/ +/, ' ').chomp
            ret.push "#{state_to_s} :: #{disk_usage} :: #{Time.now}"
          when /^connect/
            make_connection
          when /^disconnect/
            @state_goal = Device::DISCONNECTED
          when /^bash:/
            ret.push %x[ #{attr}]
          when /^ping/
            ret.push 'pong'
          when /^sms/
            number, text = attr.split(";", 2)
            @device.sms_send(number, text)
          when /^email/
            Kernel.const_defined? :SMSinfo and SMSinfo.send_email
            return false
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

      if @operator.internet_left >= 0 and @state_goal == UNKNOWN
        if @operator.internet_left > @min_traffic
          @state_goal = Device::CONNECTED
        else
          if @operator.credit_left == 0
            @state_goal = Device::DISCONNECTED
          else
            if @operator.credit_left > 0 &&
                @operator.credit_left >= @operator.internet_cost_smallest
              if !@asked_add_internet || (Time.now - @asked_add_internet > 300)
                inject_sms("valeur transferee #{@operator.credit_left} CFA")
                @asked_add_internet = Time.now
              end
            end
            @state_goal = UNKNOWN
          end
        end
      end

      old = @state_now
      if @state_now == Device::CONNECTED &&
          (@operator.internet_left >= 0 && @operator.internet_left <= @min_traffic)
        @state_goal = Device::DISCONNECTED
      end

      @state_now = @device.connection_status
      if @state_goal != @state_now
        if @state_now == Device::ERROR_CONNECTION
          @state_error += 1
          log_msg :SMScontrol, 'Connection Error - stopping'
          @device.connection_stop
          sleep 2
          #if @state_error > 5
          #  @state_goal = Connection::DISCONNECTED
          #end
        end
        if @state_goal == Device::DISCONNECTED
          log_msg :SMScontrol, 'Goal is ::Disconnected'
          @device.connection_stop
        elsif @state_goal == Device::CONNECTED
          if @operator.internet_left < @min_traffic
            @state_goal = Device::DISCONNECTED
          else
            @device.connection_start
          end
        end
      else
        @state_error = 0
      end
      if old != @state_now
        begin
          if @state_now == Device::CONNECTED
            if @send_connected
              @send_connected = false
              @send_status = true
            end
            Network::Actions.connection_up
          elsif old == Device::CONNECTED
            Network::Actions.connection_down
          end
        rescue NameError => e
        end
      end
    end

    def do_autocharge?
      @autocharge && !@recharge_hold
    end

    def recharge_all(cfas = 0)
      return unless @operator
      (cfas == 0 or !cfas) and cfas = @operator.credit_left
      log_msg :SMScontrol, "Recharging for #{cfas}"
      if cfas >= @operator.internet_cost_smallest
        @operator.internet_add_cost(cfas)
        @send_status = true
        @state_now != Device::CONNECTED and @state_now = UNKNOWN
      else
        log_msg :SMScontrol, "#{cfas} is smaller than smallest internet-cost"
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
      sms = @device.sms_list.concat(@sms_injected)
      @sms_injected = []
      dputs(3) { "SMS are: #{sms.inspect}" }
      sms.each { |sms|
        Kernel.const_defined? :SMSs and SMSs.create(sms)
        rescue_all do
          log_msg :SMS, "Working on SMS #{sms.inspect}"
          if sms._Content =~ /^cmd:/i
            if (ret = interpret_commands(sms._Content))
              log_msg :SMS, "Sending to #{sms._Phone} - #{ret.inspect}"
              @device.sms_send(sms._Phone, ret.join('::'))
            end
          else
            case @operator.name.to_sym
              when :Airtel
                case sms._Content
                  when /valeur transferee ([0-9]*) CFA/i
                    cfas = $1
                    log_msg :SMScontrol, "Got #{cfas} CFAs"
                    if do_autocharge?
                      recharge_all(cfas.to_i)
                    else
                      log_msg :SMScontrol, 'Not recharging, waiting for more...'
                    end
                  when /votre abonnement internet/,
                      /Vous avez achete le forfait/
                    log_msg :SMScontrol, "Making sure we're connected"
                    if @state_goal != Device::CONNECTED
                      make_connection
                      log_msg :SMScontrol, 'Airtel - make connection'
                    end
                end
              when :Tigo
                case sms._Content
                  when /valeur transferee ([0-9]*) CFA/i
                    cfas = $1
                    if do_autocharge? &&
                        !(sms._Content =~ /Tigo Cash/ && !sms._Content =~ /Vous avez recu/)
                      log_msg :SMScontrol, "Got #{cfas} CFAs"
                      if do_autocharge?
                        recharge_all(cfas.to_i)
                      else
                        log_msg :SMScontrol, 'Not recharging, waiting for more...'
                      end
                    end
                  when /souscription reussie/i
                    log_msg :SMS, 'Making connection'
                    make_connection
                end
            end
          end
        end
        @device.sms_delete(sms._Index)
      }
    end
  end
end
