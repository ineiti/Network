require 'helperclasses'
require 'erb'

module Network
  class SMScontrol
    attr_accessor :modem, :state_now, :state_goal, :state_error, :state_traffic,
                  :min_traffic
    extend HelperClasses::DPuts

    UNKNOWN = -1

    def initialize( operator )
      @state_now = MODEM_DISCONNECTED
      @state_goal = MODEM_DISCONNECTED
      @send_status = false
      @state_error = 0
      @phone_main = 99836457
      @state_traffic = 0
      @min_traffic = 100000
      @sms_injected = []

      chose_operator( operator )
    end

    def chose_operator(name)
      @modem = nil
      @operator = Network::Operator::chose( name ) or return
      dp @modem = @operator.modem
    end

    def is_connected
      @state_now == MODEM_CONNECTED
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
            @state_goal = MODEM_DISCONNECTED
          when /^bash:/
            ret.push %x[ #{attr}]
          when /^ping/
            ret.push 'pong'
          when /^sms/
            number, text = attr.split(";", 2)
            @modem.sms_send(number, text)
          when /^email/
            Kernel.const_defined? :SMSinfo and SMSinfo.send_email
            return false
        end
      }
      ret.length == 0 ? nil : ret
    end

    def make_connection
      @state_goal = MODEM_CONNECTED
      @state_error = 0
    end

    def check_connection
      return unless @modem

      dp @state_traffic = @operator.internet_left
      if @state_goal == UNKNOWN
        @state_goal = @state_traffic > @min_traffic ?
            MODEM_CONNECTED : MODEM_DISCONNECTED
      end

      old = @state_now
      @state_now = @modem.connection_status
      if @state_goal != @state_now
        if @state_now == MODEM_CONNECTION_ERROR
          @state_error += 1
          @modem.connection_stop
          sleep 2
          #if @state_error > 5
          #  @state_goal = MODEM_DISCONNECTED
          #end
        end
        if @state_goal == MODEM_DISCONNECTED
          @modem.connection_stop
        elsif @state_goal == MODEM_CONNECTED
          if @state_traffic < @min_traffic
            @state_goal = MODEM_DISCONNECTED
          else
            @modem.connection_start
          end
        end
      else
        @state_error = 0
      end
      if old != @state_now
        if @state_now == MODEM_CONNECTED
          Network::connection_up
        elsif old == MODEM_CONNECTED
          Network::connection_down
        end
      end
    end

    def check_sms
      return unless @modem
      if @send_status
        @modem.sms_send(@phone_main, interpret_commands('cmd:status').join('::'))
        @send_status = false
        SMSinfo.send_email
      end
      sms = @modem.sms_list.concat(@sms_injected)
      @sms_injected = []
      ddputs(3) { "SMS are: #{sms.inspect}" }
      sms.each { |sms|
        Kernel.const_defined? :SMSs and SMSs.create(sms)
        log_msg :SMS, "Working on SMS #{sms.inspect}"
        if sms._Content =~ /^cmd:/i
          if (ret = interpret_commands(sms._Content))
            log_msg :SMS, "Sending to #{sms._Phone} - #{ret.inspect}"
            @modem.sms_send(sms._Phone, ret.join('::'))
          end
        else
          dp @state_traffic = @operator.internet_left( true )
          dp @operator
          case @operator
            when :Airtel
              case sms._Content
                when /votre.*solde/i
                  make_connection
                  log_msg :SMScontrol, 'Airtel - make connection'
                  @send_status = true
              end
            when :Tigo
              log_msg :SMS, "Got message from Tigo: #{sms.inspect}"

              case sms._Content
                when /200.*cfa/i
                  @state_goal = MODEM_DISCONNECTED
                  log_msg :SMS, 'Getting internet-credit'
                  @modem.sms_send(100, 'internet')
                when /350.*cfa/i
                  @state_goal = MODEM_DISCONNECTED
                  log_msg :SMS, 'Getting internet-credit'
                  @modem.sms_send(200, 'internet')
                when /850.*cfa/i
                  @state_goal = MODEM_DISCONNECTED
                  log_msg :SMS, 'Getting internet-credit'
                  @modem.sms_send(1111, 'internet')
                when /souscription reussie/i
                  make_connection
                  log_msg :SMS, 'Making connection'
                  @send_status = true
              end
          end
        end
        @modem.sms_delete(sms._Index)
      }
    end
  end
end
