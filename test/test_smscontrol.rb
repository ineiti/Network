DEBUG_LVL=3
$LOAD_PATH.push '../../HelperClasses/lib', '../lib', '../../Hilink/lib', '../../HuaweiModem/lib'

require 'network'

include Network
include HelperClasses::DPuts

$smsc = SMScontrol.new
#$smsc.device.sms_send(99836457, 'test from Smileplug')
#exit
loop do
  $smsc.check_sms
  $smsc.check_connection
  dputs(0){ $smsc.state_to_s }
  sleep 10
end

exit

SMScontrol.check_connection
puts SMScontrol.state_to_s

SMScontrol.make_connection
puts SMScontrol.state_to_s

while SMScontrol.state_now != MODEM_CONNECTED
  sleep 10
  SMScontrol.check_connection
  puts SMScontrol.state_to_s
end
