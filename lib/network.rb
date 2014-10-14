#!/usr/bin/env ruby -wKU
# Replacement for LibNet

require 'drb'
require 'network/modem'
require 'network/operator'
require 'network/smscontrol'
#require 'network/captive'
require 'helperclasses'

module Network
  extend self
  extend HelperClasses::DPuts

  def vpn_first
    File.basename Dir.glob('/etc/openvpn/vpn-profeda*conf').first, '.conf'
  end

  def connection_up
    log_msg :Network, 'Connection goes up'
    system("systemctl start openvpn@#{vpn_first}")
    #system( "sudo -u fetchmail fetchmail -v -f /etc/fetchmailrc" )
    log_msg :Network, 'Connection goes up - 1'
    system( 'date | mail -s "$( hostname ): Connected" ineiti@profeda.org' )
    log_msg :Network, 'Connection goes up - 2'
    system('postqueue -f')
    log_msg :Network, 'Connection goes up - 3'
    system('systemctl restart fetchmail')
    log_msg :Network, 'Connection goes up - 4'
    system('/opt/profeda/LibNet/Tools/9dnsmasq-internet.sh')
    log_msg :Network, 'Connection goes up - 5'
  end

  def connection_down
    log_msg :Network, 'Connection goes down'
    system("systemctl stop openvpn@#{vpn_first}")
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
