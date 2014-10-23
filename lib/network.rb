#!/usr/bin/env ruby -wKU
# Replacement for LibNet

require 'drb'
require 'network/captive'
require 'network/connection'
require 'network/mail'
require 'network/operator'
require 'network/smscontrol'
require 'helperclasses'

module Network
  extend self
  extend HelperClasses::DPuts
  class NotSupported < StandardError; end
  class NoOperator < StandardError; end
  class NoConnection < StandardError; end

end

if __FILE__ == $PROGRAM_NAME
  DRb.start_service 'druby://:9000', Network::Connection.new
  dputs(0){ "Server running at #{DRb.uri}" }

  trap("INT") { DRb.stop_service }
  DRb.thread.join
end
