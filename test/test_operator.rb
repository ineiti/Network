DEBUG_LVL=2

require 'network'
require 'helperclasses'
include HelperClasses::DPuts

def setup
  dp Network::Operator.list
  return unless ($dev = Network::Device.search_dev({uevent: {driver: 'option'}})).length > 0
  dp $dev.inspect
  return unless $con = Network::Connection.new($dev.first, :Airtel)
  $op = $con.operator
end

def main
  setup
  test_sms
end

def test_sms
  dp $op.device.sms_scan
  sleep 10
  dp $op.device.serial_sms.inspect
  sleep 1
end

def test_credit_airtel
  #ussd_send '*242*10#'
  ussd_send '*342#'
  ussd_send '4'
  sleep 10
end

def test_internet_left
  dp $op.internet_left(true)
  sleep 20
  dp $op.internet_left(true)
end

def test_internet_add
  $op.internet_add( 10_000_000 )
  sleep 20
  dp $op.credit_left
  dp $op.internet_left
end

main
