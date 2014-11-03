require 'helperclasses'
require 'erb'

module Network
  class SMScontrol
    attr_accessor :state_now, :state_goal, :state_error, :state_traffic,
                  :min_traffic, :connection, :device, :operator
    extend HelperClasses::DPuts

    UNKNOWN = -1

    def initialize
      @state_now = Device::DISCONNECTED
      @state_goal = UNKNOWN
      @send_status = false
      @state_error = 0
      @phone_main = 99836457
      @state_traffic = 0
      @min_traffic = 100000
      @sms_injected = []
      @device = Network::Device.search_dev({uevent:{driver: 'option'}}).first
      return unless @device
      @connection = Network::Connection.new(@device)
      @operator = @connection.operator
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
      return unless @connection

      @state_traffic = @operator.internet_left
      if @state_traffic >= 0 and @state_goal == UNKNOWN
        @state_goal = @state_traffic > @min_traffic ?
            Device::CONNECTED : Device::DISCONNECTED
      end

      old = @state_now
      if @state_now == Device::CONNECTED &&
          @state_traffic <= @min_traffic
        @state_goal = Device::DISCONNECTED
      end

      @state_now = @connection.status
      if @state_goal != @state_now
        if @state_now == Device::ERROR_CONNECTION
          @state_error += 1
          @connection.stop
          sleep 2
          #if @state_error > 5
          #  @state_goal = Connection::DISCONNECTED
          #end
        end
        if @state_goal == Device::DISCONNECTED
          @connection.stop
        elsif @state_goal == Device::CONNECTED
          if @state_traffic < @min_traffic
            @state_goal = Device::DISCONNECTED
          else
            @connection.start
          end
        end
      else
        @state_error = 0
      end
      if old != @state_now
        begin
          if @state_now == Device::CONNECTED
            Network::Actions.connection_up
          elsif old == Device::CONNECTED
            Network::Actions.connection_down
          end
        rescue NotSupported => e
        end
      end
    end

    def check_sms
      return unless @connection
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
            when :Tigo2
              case sms._Content
                when /200.*cfa/i
                  @state_goal = Device::DISCONNECTED
                  log_msg :SMS, 'Getting internet-credit'
                  @device.sms_send(100, 'internet')
                when /350.*cfa/i
                  @state_goal = Device::DISCONNECTED
                  log_msg :SMS, 'Getting internet-credit'
                  @device.sms_send(200, 'internet')
                when /850.*cfa/i
                  @state_goal = Device::DISCONNECTED
                  log_msg :SMS, 'Getting internet-credit'
                  @device.sms_send(1111, 'internet')
                when /souscription reussie/i
                  make_connection
                  log_msg :SMS, 'Making connection'
                  @send_status = true
              end
          end
        end
        @device.sms_delete(sms._Index)
      }
      @device.sms_scan
    end
  end
end
