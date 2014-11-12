require 'helperclasses'
require 'erb'

module Network
  class SMScontrol
    attr_accessor :state_now, :state_goal, :state_error, :state_traffic,
                  :min_traffic, :device, :operator
    extend HelperClasses::DPuts

    UNKNOWN = -1

    @operator = nil

    def initialize
      @state_now = Device::DISCONNECTED
      @state_goal = UNKNOWN
      @send_status = false
      @send_connected = false
      @state_error = 0
      @phone_main = 99836457
      @state_traffic = 0
      @min_traffic = 100000
      @traffic_goal = 0
      @sms_injected = []

      @device = nil
      Network::Device.add_observer(self)
      update('add', Network::Device.search_dev({uevent: {driver: 'option'}}).first )
    end

    def update(operation, dev = nil )
      ddputs(3){"Updating #{operation} with device #{dev}"}
      case operation
        when /del/
          if @device == dev
            log_msg :SMScontrol, "Lost device #{@device}"
            @device = @operator = nil
          end
        when /add/
          if !@device && dev
            @device = dev
            @operator = @device.operator
            @device.add_observer(self)
            log_msg :SMScontrol, "Got new device #{@device}"
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
      "#{@state_now}-#{@state_goal}-#{@state_error}-#{@state_traffic}"
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
      @state_goal = Device::CONNECTED
      @state_error = 0
    end

    def check_connection
      return unless @operator

      @state_traffic = @operator.internet_left
      if @state_traffic >= 0 and @state_goal == UNKNOWN
        @state_goal = @state_traffic > @min_traffic ?
            Device::CONNECTED : Device::DISCONNECTED
      end

      old = @state_now
      if @state_now == Device::CONNECTED &&
          ( @state_traffic >= 0 && @state_traffic <= @min_traffic )
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
          if @state_traffic < @min_traffic
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

    def check_sms
      return unless @operator
      if @send_status
        @device.sms_send(@phone_main, interpret_commands('cmd:status').join('::'))
        @send_status = false
        Kernel.const_defined? :SMSinfo and SMSinfo.send_email
      end
      sms = @device.sms_list.concat(@sms_injected)
      @sms_injected = []
      dputs(3) { "SMS are: #{sms.inspect}" }
      sms.each { |sms|
        Kernel.const_defined? :SMSs and SMSs.create(sms)
        log_msg :SMS, "Working on SMS #{sms.inspect}"
        if sms._Content =~ /^cmd:/i
          if (ret = interpret_commands(sms._Content))
            log_msg :SMS, "Sending to #{sms._Phone} - #{ret.inspect}"
            @device.sms_send(sms._Phone, ret.join('::'))
          end
        else
          @state_traffic = @operator.internet_left
          case @operator.name.to_sym
            when :Airtel
              case sms._Content
                when /votre.*solde/i
                  make_connection
                  log_msg :SMScontrol, 'Airtel - make connection'
                  @send_status = true
              end
            when :Tigo
              case sms._Content
                when /200.*cfa/i
                  @state_goal = Device::DISCONNECTED
                  log_msg :SMS, 'Getting internet-credit'
                  @device.sms_send(100, 'internet')
                  sleep 5
                when /350.*cfa/i
                  @state_goal = Device::DISCONNECTED
                  log_msg :SMS, 'Getting internet-credit'
                  @device.sms_send(200, 'internet')
                  sleep 5
                when /850.*cfa/i
                  @state_goal = Device::DISCONNECTED
                  log_msg :SMS, 'Getting internet-credit'
                  @device.sms_send(1111, 'internet')
                  sleep 5
                when /souscription reussie/i
                  log_msg :SMS, 'Asking credit'
                  @state_traffic = @operator.internet_left(true)
                  @state_goal = UNKNOWN
                  make_connection
                  @send_status = @send_connected = true
              end
          end
        end
        @device.sms_delete(sms._Index)
      }
      @device.sms_scan
    end
  end
end
