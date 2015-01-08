DEBUG_LVL=2
require 'network/monitor/traffic'
include Network::Monitor

def main
  #test_setup
  #test_create_rrb
  #test_create_iptables
  test_measure
end

def test_setup
  Traffic.setup_config({hosts: %i(dp mbp),
                        host_ips: {dp: '192.168.1.3', mbp: '192.168.1.146'},
                        colors: {dp: 'f99', mbp: '9f9'},
                        name_hosts: {dp: 'DreamPlug', mbp: 'MacBook_Pro'},
                        bw_upper: 1_000_000} )
end

def test_create_rrb
  test_setup
  Traffic.create_rrb
end

def test_create_iptables
  test_create_rrb
  Traffic.create_iptables
end

def test_measure
  #test_create_iptables
  test_setup
  Traffic.measure
end

main
