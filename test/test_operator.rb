DEBUG_LVL=5

require 'network'
require 'helperclasses'
include HelperClasses::DPuts

$op = Network::Operator.chose(:Airtel) or raise 'OperatorNotFound'
dp $op.name
#dp op.internet_left( true )
sleep 2

def ussd_send(str)
  $op.modem.ussd_send(str)
  sleep 5
  dp $op.modem.ussd_fetch(str)
  sleep 2
end
dp $op.modem.sms_scan
sleep 1
dp $op.modem.sms_list
exit

#ussd_send '*242*10#'
ussd_send '*342#'
ussd_send '4'
sleep 10

dp $op.internet_left( true )
#op.internet_add( 10_000_000 )
sleep 10
dp $op.internet_left( true )
sleep 10
dp $op.internet_left( true )
