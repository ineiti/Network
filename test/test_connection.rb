DEBUG_LVL=3
require 'network'

p dev = Network::Device.search_dev({uevent:{driver: 'option'}})
return unless dev
conn = Network::Connection.new(dev.first)
p conn
