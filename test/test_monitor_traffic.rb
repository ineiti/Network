DEBUG_LVL=2
require 'helper_classes/dputs'
require 'network/monitor/traffic'
require 'network/monitor/traffic_user'
include Network::Monitor
include HelperClasses::DPuts

def main
  #test_setup
  #test_create_rrb
  #test_create_iptables
  #test_measure_dynamic
  test_update_traffic
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
  Traffic.create_rrb(false)
end

def test_create_iptables
  test_create_rrb
  Traffic.create_iptables
end

def test_measure
  test_create_iptables
  test_setup
  Traffic.run_measure
  sleep 1
end

def test_measure_dynamic
  Traffic.setup_config
  Traffic.create_iptables
  user = Traffic::User.new

  user.update
  Traffic.ip_add('192.168.1.146', 'linus')
  Traffic.ip_add('192.168.1.3', :dp)
  (1..10).each{
    user.update
    sleep 1
  }
end

def test_update_traffic
  user = Traffic::User.new
  dp time = Time.new(2000, 1, 1, 0, 0, 0)
  user.update_host(:new, [2,2], time)
  dp user.traffic._new._sec
  time += 1
  user.update_host(:new, [4,5], time)
  dp user.traffic._new._sec
  time += 1
  user.update_host(:new, [10,12], time)
  dp user.traffic._new._sec
  time += 1
  user.update_host(:new, [20,18], time)
  dp user.traffic._new._sec
  time += 60
  user.update_host(:new, [100,100], time)
  dp user.traffic._new._sec
  time += 120
  user.update_host(:new, [200,200], time)
  dp user.traffic._new._sec
end

main
