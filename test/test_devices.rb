DEBUG_LVL = 3
require 'network'
require 'drb/drb'

DRb.start_service

handler = DRbObject.new_with_uri('druby://localhost:9000')
#puts handler.add( {} )

exit

sys_net = [{:class => "net", :path => "/sys/class/net/br0",
            :uevent => {"devtype" => "bridge", "interface" => "eth0",
                        "ifindex" => "5"},
            :dirs => ["brif", "power", "bridge", "queues", "statistics"]}]
id_1 = [{class: 'net', uevent: {interface: 'eth.*'}, dirs: ['bridge']}]

puts Network::Device::Stub.check_same(sys_net.first, id_1.first.keys, id_1.first).inspect
