#!/usr/bin/env ruby -wKU
# Replacement for LibNet

require 'helperclasses'

include HelperClasses::ArraySym
class Array
# Comptaibility for Ruby <= 2.0
  if ![].respond_to?(:to_h)
    def to_h
      Hash[*self.flatten]
    end
  end

  def to_sym
    collect { |v| v.to_sym }
  end

  def to_sym!
    self.replace(to_sym())
  end

  def to_s
    "[#{join(",")}]"
  end
end


require 'drb'
require 'network/operator'
require 'network/device'
require 'network/captive'
#require 'network/connection'
require 'network/mail'
require 'network/smscontrol'
require 'network/monitor/ping'
require 'network/monitor/traffic'
require 'network/monitor/traffic_user'

module Network
  extend self
  extend HelperClasses::DPuts
  class NotSupported < StandardError;
  end
  class NoOperator < StandardError;
  end
  class NoConnection < StandardError;
  end

end

if __FILE__ == $PROGRAM_NAME
  DRb.start_service 'druby://:9000', Network::Connection.new
  dputs(0) { "Server running at #{DRb.uri}" }

  trap("INT") { DRb.stop_service }
  DRb.thread.join
end
