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
    @search_connections = Thread.new {
      if @connection && !@connection.present?
        available = @connections.select { |n, c| c.present? }
        if !available.key(@connection.class)
          log_msg :Connection, "Lost connection #{@connection}"
          @connection.down
          @connection = nil
        end
      end
      if !@connection && available.length > 0
        @connection = available.first[1].new
        log_msg :Connection, "Instantiating new connection: #{@connection}"
      end
      sleep 10
    }

    @methods_needed = [
        :start, :stop, :status,
        :present?, :reset, :down,
        :sms_list, :sms_send, :sms_delete,
        :ussd_send, :ussd_fetch
    ]

    def method_missing(name, *args)
      if @methods_needed.index(name)
        raise NoConnection unless @connection
        @connection.send(name, args)
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

    class Stub
      def self.inherited(other)
        dputs(2) { "Inheriting modem #{other.inspect}" }
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

  Dir[File.dirname(__FILE__) + '/modems/*.rb'].each { |f|
    dputs(3) { "Adding modem-file #{f}" }
    require(f)
  }
end
