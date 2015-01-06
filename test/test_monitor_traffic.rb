DEBUG_LVL=2
require 'network/monitor/traffic'
include Network::Monitor

def main
  Traffic.setup_config
  Traffic.hosts = %w( dp mbp )
  Traffic.config._hosts_ips = %w( 192.168.1.3 192.168.1.146 )
end

def test_create_rrb
  Traffic.create_rrb
end

main