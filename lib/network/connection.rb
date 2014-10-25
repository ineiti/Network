require 'singleton'
require 'helperclasses'
require 'thread'

module Network
  extend HelperClasses::DPuts

  module Connection
    attr_accessor :connections, :operator, :methods_needed
    extend HelperClasses::DPuts
    extend self

    ERROR=-1
    CONNECTED=1
    CONNECTING=2
    DISCONNECTING=3
    DISCONNECTED=4
    ERROR_CONNECTION=5

    @connections = {}
    @connection = nil
    @operator = nil
    @search_connections = nil

    @methods_needed = [
        :start, :stop, :status, :may_stop, :status_old,
        :present?, :reset, :down,
        :sms_list, :sms_send, :sms_delete,
        :ussd_send, :ussd_fetch
    ]

    def method_missing(name, *args)
      if @methods_needed.index(name)
        raise NoConnection unless @connection
        @connection.send(name, *args)
      else
        super(name, args)
      end
    end

    def available?
      @connection
    end

    def get_sms_time(sms)
      Time.strptime(sms._Date, '%Y-%m-%d %H:%M:%S')
    end

    def available
      @connections.select { |n, c|
        dputs(3){"Testing #{n}"}
        c.present?
      }
    end

    def remove
      return unless @connection
      @connection.down
      @connection = nil
    end

    def chose( name )
      return unless available.has_key? name.to_s
      if @connection
        remove
      end
      @connection = @connections[name.to_s].new
      log_msg :Connection, "Chosing new connection: #{@connection}"
      @connection
    end

    def start_search
      return if @search_connections
      @search_connections = Thread.new {
        begin
          dputs(4) { "Start search with connections #{@connections}" }
          if @connections.length > 0
            dputs(2) { "Available connections #{available}" }
            if @connection
              if !available.key(@connection.class)
                log_msg :Connection, "Lost connection #{@connection}"
                remove
              end
            else
              if available.length > 0
                @connection = available.first[1].new
                log_msg :Connection, "Instantiating new connection: #{@connection}"
              end
            end
          end
        rescue Exception => e
          dputs(0) { "#{e.inspect}" }
          dputs(0) { "#{e.to_s}" }
          puts e.backtrace
        end
        sleep 10
      }
    end

    class Stub
      extend HelperClasses::DPuts

      def self.inherited(other)
        dputs(2) { "Inheriting connection #{other.inspect}" }
        Connection.connections[other.to_s.sub(/.*::/, '')] = other
        super(other)
      end

      def method_missing(name, *args)
        raise NotSupported if Connection.methods_needed.index(name)
        super(name, args)
      end

      def respond_to?(name)
        return true if @@methods_needed.index(name)
        super(name)
      end
    end
  end

  Dir[File.dirname(__FILE__) + '/connections/*.rb'].each { |f|
    dputs(3) { "Adding connection-file #{f}" }
    require(f)
  }
  Connection.start_search
end
