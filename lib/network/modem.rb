require 'singleton'
require 'helperclasses'

module Network
  class NotSupported < StandardError; end
  extend HelperClasses::DPuts

  MODEM_ERROR=-1
  MODEM_CONNECTED=1
  MODEM_CONNECTING=2
  MODEM_DISCONNECTING=3
  MODEM_DISCONNECTED=4
  MODEM_CONNECTION_ERROR=5

  class Modem
    include Singleton
    extend HelperClasses::DPuts
    include HelperClasses::DPuts
  
    @@modems = []
    def initialize
    end
  
    def self.inherited( other )
      dputs(2){ "Inheriting modem #{other.inspect}" }
      @@modems << other
      super( other )
    end
  
    @@methods_needed = [
      :credit_left, :credit_add, :credit_mn, :credit_mb,
      :connection_start, :connection_stop, :connection_status,
      :sms_list, :sms_send, :sms_delete,
      :modem_present?, :modem_reset
    ]

    def method_missing( name, *args )
      raise NotSupported if @@methods_needed.index( name )
      super( name, args )
    end

    def respond_to?( name )
      return true if @@methods_needed.index( name )
      super( name )
    end

    def self.get_sms_time( sms )
      Time.strptime( sms._Date, '%Y-%m-%d %H:%M:%S')
    end
  
    def self.present
      dputs(3){ "network: #{@@modems.inspect}" }
      @modem = @@modems.find{|m| m.modem_present? }
      @modem and @modem.instance
    end
  end

  Dir[ File.dirname( __FILE__ ) + "/modems/*.rb"].each{|f|
    dputs(3){ "Adding modem-file #{f}" }
    require(f)
  }
end
