DEBUG_LVL=2
require 'network'
Network::Device.start
sleep 3

def main
  test_connect
end

def test_connect
  p dev = Network::Device.search_dev({uevent: {driver: 'option'}})
  return unless dev
  dev.first.connection_start
end

main