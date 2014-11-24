DEBUG_LVL=2

require 'network'

exit unless device = Network::Device.search_dev({uevent: {driver: 'option'}}).first
operator = device.operator

p list = device.sms_list
p device.connection_status
exit

modem.connection_start
loop do
  p modem.connection_status
  sleep 5
end

#modem.sms_send( 100, 'update credit' )
#modem.sms_send( 93999699, 'Hello from Smileplug')
#p Network::Modem.get_sms_time list[1]
#modem.sms_delete( list[1]._Index )
