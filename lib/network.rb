#!/usr/bin/env ruby -wKU
# Replacement for LibNet

require 'drb'
require 'network/modem'
require 'helperclasses'

module Network
  extend HelperClasses::DPuts

  class Connection
    def initialize( simul = false )
      @simul = simul
      if not @simul
      else
        dputs(1){"Simulation only"}
      end
    end
	
    def isp_params
      @simul and return {}
      Hash[ %w( ISP CONNECTION_TYPE HAS_PROMO HAS_CREDIT ALLOW_FREE ).collect{|v|
          [ v.downcase, print( v ) ]
        } ]
    end
  end
end

if __FILE__ == $PROGRAM_NAME 
  DRb.start_service 'druby://:9000', Network::Connection.new
  dputs(0){ "Server running at #{DRb.uri}" }
 
  trap("INT") { DRb.stop_service }
  DRb.thread.join
end
