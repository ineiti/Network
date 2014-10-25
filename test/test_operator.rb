DEBUG_LVL=2

require 'network'
require 'helperclasses'
include HelperClasses::DPuts

sleep 3

$con = Network::Connection.chose(:Serial) or raise 'ConnectionNotFound'
$op = Network::Operator.chose(:Airtel) or raise 'OperatorNotFound'
dp $op.name
#dp $op.internet_left( true )
#sleep 20
#dp $op.internet_left( true )

def ussd_send(str)
  $op.modem.ussd_send(str)
  sleep 5
  dp $op.modem.ussd_fetch(str)
  sleep 2
end

if true
  #$op.internet_add( 10_000_000 )
  #sleep 20
  sleep 10
  dp $op.credit_left
  sleep 300
  dp $op.internet_left

  exit

  dp $op.modem.sms_scan
  sleep 1
  dp $op.modem.sms_list.inspect
  sleep 1
#ussd_send '*242*10#'
  ussd_send '*342#'
  ussd_send '4'
  sleep 10
end

#dp $op.internet_left(true)
exit
dp $op.internet_left(true)
sleep 20
dp $op.internet_left(true)
