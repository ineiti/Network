DEBUG_LVL=2
require 'network'
require 'helperclasses'
include Network::Monitor
include HelperClasses::DPuts

def main
  #test_user
  #test_user_measure
  test_json
end

def assert(cond, str = nil)
  return if cond
  log_msg :assert, "Failed on #{str}"
end

def test_user
  Traffic.setup_config(hosts: %w(one two three), host_ips: {one: 1, two: 2, three: 3})
  user = Traffic::User.new
  assert user.total(:one) == 0
  assert user.diff(:one) == 0

  user.update(one: [100, 0], two: [0, 200], three: [0, 0])
  dp user.traffic.inspect
  assert user.total(:one) == 100
  assert user.diff(:one) == 100

  user.update(one: [100, 50], two: [100, 200], three: [0, 0])
  dp user.traffic.inspect
  assert user.total(:one) == 150
  assert user.diff(:one) == 50
  assert user.total(:two) == 300
  assert user.diff(:two) == 100
end

def test_user_measure
  Traffic.setup_config(hosts: %w(one two three), host_ips:
                                                   {one: '192.168.1.146',
                                                    two: '192.168.1.3',
                                                    three: '192.168.1.120'},
                       db: '')
  Traffic.create_iptables
  user = Traffic::User.new
  user.update
  dp user.get_sec(:one)
  dp user.get_min(:one)
  sleep 5
  user.update
  dp user.get_sec(:one)
  dp user.get_min(:one)
  sleep 5
  user.update
  dp user.get_sec(:one)
  dp user.get_min(:one)
end

def test_json
  Traffic.setup_config(hosts: %w(one two three), host_ips:
                                                   {one: '192.168.1.146',
                                                    two: '192.168.1.3',
                                                    three: '192.168.1.120'},
                       db: '')
  Traffic.create_iptables
  user = Traffic::User.new
  user.update
  sleep 3
  user.update
  dp user.get_sec(:one, -10)
  json = user.save_json

  sleep 3
  user_new = Traffic::User.from_json(json)
  user_new.update
  dp user_new.get_sec(:one, -10)
end

main