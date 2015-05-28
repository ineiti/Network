require 'test/unit'
include Network

class NET_Op_Tigo < Test::Unit::TestCase

  def setup
  end

  def teardown

  end

  def test_check_this
    dev1 = {:bus=> 'usb', :path=> '/sys//devices/soc0/soc.1/2100000.aips-bus/2184200.usb/ci_hdrc.1/usb2/2-1/2-1:1.3/ttyUSB2',
            :uevent=>{'devtype' => 'usb_interface', 'driver' => 'option', 'product' => '12d1/1506/102', 'type' => '0/0/0', 'interface' => '255/2/2',
                      'modalias' => 'usb:v12d1p1506d0102dc00dsc00dp00icffisc02ip02in03'}, :dirs=>['ep_04', 'ep_86', 'power', 'ttyUSB2']}
    dev2 = {:bus=> 'usb', :uevent=>{:driver=> 'option'}, :dirs=>['ttyUSB2']}

    assert Network::Device::Stub.check_this(dev1, dev2.keys, dev2)
  end
end