DEBUG_LVL=3

require 'network'
require 'helperclasses'
include HelperClasses::DPuts

def setup
  dp Network::Operator.list
  return unless ($dev = Network::Device.search_dev({uevent: {driver: 'option'}})).length > 0
  dp $dev.inspect
  return unless $con = Network::Connection.new($dev.first)
  $dev = $dev.first
  $op = $con.operator
end

def main
  setup
  #test_tigo_callback
  test_send_credit
end

def test_tigo_callback
  #$op.credit_add('5047459016658')
  #$op.callback('93999699')
  sleep 10
end

def test_send_credit
  #dp $op.credit_left
  #sleep 10
  #dp $op.credit_left
  dp $op.credit_send( '93999699', 100)
  (1..10).each{
    dp $dev.sms_list
    sleep 3
  }
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
