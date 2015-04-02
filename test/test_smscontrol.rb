DEBUG_LVL=2
$LOAD_PATH.push '../../HelperClasses/lib', '../lib', '../../Hilink/lib', '../../HuaweiModem/lib'

require 'network'

include Network
include HelperClasses::DPuts

trap('SIGINT') {
  throw :ctrl_c
}

catch :ctrl_c do
  $smsc = MobileControl.new
#$smsc.device.sms_send(99836457, 'test from Smileplug')
#exit
  loop do
    $smsc.check_sms
    $smsc.check_connection
    dputs(0) { $smsc.state_to_s }
    sleep 10
  end

  exit

  MobileControl.check_connection
  puts MobileControl.state_to_s

  MobileControl.make_connection
  puts MobileControl.state_to_s

  while MobileControl.state_now != MODEM_CONNECTED
    sleep 10
    MobileControl.check_connection
    puts MobileControl.state_to_s
  end
end