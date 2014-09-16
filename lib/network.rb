#!/usr/bin/env ruby -wKU
# Replacement for LibNet

require 'drb'
require 'network/modem'
require 'network/operator'
require 'network/smscontrol'
require 'network/captive'
require 'helperclasses'

module Network
  extend self
  extend HelperClasses::DPuts

  def connection_up
    log_msg :Network, 'Connection goes up'
    system('systemctl start openvpn@vpn-profeda-mas')
    #system( "sudo -u fetchmail fetchmail -v -f /etc/fetchmailrc" )
    system( 'date | mail -s "$( hostname ): Connected" ineiti@profeda.org"' )
    system('postqueue -f')
    system('systemctl restart fetchmail')
    system('/opt/profeda/LibNet/Tools/9dnsmasq-internet.sh')
  end

  def connection_down
    log_msg :Network, 'Connection goes down'
    system('systemctl stop openvpn@vpn-profeda-mas')
    system('/opt/profeda/LibNet/Tools/9dnsmasq-catchall.sh')
    system('systemctl stop fetchmail')
  end

  class Connection
    def initialize( simul = false )
      @simul = simul
      if not @simul
      else
        dputs(1){ 'Simulation only' }
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
