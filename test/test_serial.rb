DEBUG_LVL=2

require 'network'
require 'helper_classes'

$dev = Network::Device.search_dev({uevent:{driver: 'option'}}).first or exit

$dev.connection_start

loop do
  puts $dev.connection_status
  sleep 0.5
end

