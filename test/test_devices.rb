DEBUG_LVL = 3
require 'network'
require 'drb/drb'

def setup
  DRb.start_service

  handler = DRbObject.new_with_uri('druby://localhost:9000')
#puts handler.add( {} )
  Network::Device.list
  p Network::Device.search_dev({uevent: {driver: 'option'}})
end

def main
  setup
  #test_check_same_2
end

def test_check_same
  sys_net = [{:class => "net", :path => "/sys/class/net/br0",
              :uevent => {"devtype" => "bridge", "interface" => "eth0",
                          "ifindex" => "5"},
              :dirs => ["brif", "power", "bridge", "queues", "statistics"]}]
  id_1 = [{class: 'net', uevent: {interface: 'eth.*'}, dirs: ['bridge']}]

  puts Network::Device::Stub.check_this(sys_net.first, id_1.first.keys, id_1.first).inspect
end

def test_check_same_2
  sys_net = [{:class => "net",
              :path => "/sys/class/net/eth1",
              :dirs => ["power", "brport", "queues", "statistics"],
              :uevent => {"interface" => "eth1", "ifindex" => "3"},
              :address => "f0:ad:4e:02:07:40"}]
  id_1 = [{:class => "net", :uevent => {:interface => "eth.*"}}]

  puts Network::Device::Stub.check_this(sys_net.first, id_1.first.keys, id_1.first).inspect
end

def ussd_send(str)
  $op.modem.ussd_send(str)
  sleep 5
  dp $op.modem.ussd_fetch(str)
  sleep 2
end

def test_ussd
  $op.modem.sms_send('62154352', 'test1')
end

main