require 'singleton'

module Network
  class NotSupported < StandardError; end

  class Modem
    include Singleton
  
    @@modems = []
    def initialize
    
    end
  
    def self.inherited( other )
      puts "Inherited from #{other.inspect}"
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
  
    def self.present
      puts "Modems: #{@@modems.inspect}"
      @modem = @@modems.find{|m| m.modem_present? }
      @modem and @modem.instance
    end
  end

  Dir[ File.dirname( __FILE__ ) + "/Modems/*.rb"].each{|f|
    puts "Requiring file #{f}"
    require(f)
  }
end