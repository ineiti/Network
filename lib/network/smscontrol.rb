require 'helperclasses'
require 'erb'

module Network
  class SMScontrol
    attr_accessor :state_now, :state_goal, :state_error, :state_traffic,
                  :min_traffic
    extend HelperClasses::DPuts

    UNKNOWN = -1

    def initialize(operator)
      @state_now = Connection::DISCONNECTED
      @state_goal = UNKNOWN
      @send_status = false
      @state_error = 0
      @phone_main = 99836457
      @state_traffic = 0
      @min_traffic = 100000
      @sms_injected = []

      chose_operator(operator)
    end

    def chose_operator(name)
      Connection.chose_operator( name )
    end

    def is_connected
      @state_now == Connection::CONNECTED
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
            @state_goal = Connection::DISCONNECTED
          when /^bash:/
            ret.push %x[ #{attr}]
          when /^ping/
            ret.push 'pong'
          when /^sms/
            number, text = attr.split(";", 2)
            Connection.sms_send(number, text)
          when /^email/
            Kernel.const_defined? :SMSinfo and SMSinfo.send_email
            return false
        end
      }
      ret.length == 0 ? nil : ret
    end

    def make_connection
      @state_goal = Connection::CONNECTED
      @state_error = 0
    end

    def check_connection
      return unless Connection.available?

      @state_traffic = Operator.internet_left(true)
      if @state_traffic >= 0 and @state_goal == UNKNOWN
        @state_goal = @state_traffic > @min_traffic ?
            Connection::CONNECTED : Connection::DISCONNECTED
      end

      old = @state_now
      if @state_now == Connection::CONNECTED &&
          @state_traffic <= @min_traffic
        @state_goal = Connection::DISCONNECTED
      end

      @state_now = Connection.status
      if @state_goal != @state_now
        if @state_now == Connection::CONNECTION_ERROR
          @state_error += 1
          Connection.stop
          sleep 2
          #if @state_error > 5
          #  @state_goal = Connection::DISCONNECTED
          #end
        end
        if @state_goal == Connection::DISCONNECTED
          Connection.stop
        elsif @state_goal == Connection::CONNECTED
          if @state_traffic < @min_traffic
            @state_goal = Connection::DISCONNECTED
          else
            Connection.start
          end
        end
      else
        @state_error = 0
      end
      if old != @state_now
        begin
          if @state_now == Connection::CONNECTED
            Network::Actions.connection_up
          elsif old == Connection::CONNECTED
            Network::Actions.connection_down
          end
        rescue NotSupported => e
        end
      end
    end

    def check_sms
      return unless Connection.available?
      if @send_status
        Connection.sms_send(@phone_main, interpret_commands('cmd:status').join('::'))
        @send_status = false
        SMSinfo.send_email
      end
      sms = Connection.sms_list.concat(@sms_injected)
      @sms_injected = []
      dputs(3) { "SMS are: #{sms.inspect}" }
      sms.each { |sms|
        Kernel.const_defined? :SMSs and SMSs.create(sms)
        log_msg :SMS, "Working on SMS #{sms.inspect}"
        if sms._Content =~ /^cmd:/i
          if (ret = interpret_commands(sms._Content))
            log_msg :SMS, "Sending to #{sms._Phone} - #{ret.inspect}"
            Connection.sms_send(sms._Phone, ret.join('::'))
          end
        else
          @state_traffic = Operator.internet_left(true)
          case Operator.name
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
                  @state_goal = Connection::DISCONNECTED
                  log_msg :SMS, 'Getting internet-credit'
                  Connection.sms_send(100, 'internet')
                when /350.*cfa/i
                  @state_goal = Connection::DISCONNECTED
                  log_msg :SMS, 'Getting internet-credit'
                  Connection.sms_send(200, 'internet')
                when /850.*cfa/i
                  @state_goal = Connection::DISCONNECTED
                  log_msg :SMS, 'Getting internet-credit'
                  Connection.sms_send(1111, 'internet')
                when /souscription reussie/i
                  make_connection
                  log_msg :SMS, 'Making connection'
                  @send_status = true
              end
          end
        end
        Connection.sms_delete(sms._Index)
      }
    end
  end
end
