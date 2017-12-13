DEBUG_LVL = 2
require 'bundler/setup'
require 'network'
require 'drb/drb'
require 'helper_classes/dputs'
include HelperClasses::DPuts

trap('SIGINT') {
  throw :ctrl_c
}

catch :ctrl_c do
  begin

    def setup
      #DRb.start_service
      Network::Device.start

      $handler = DRbObject.new_with_uri('druby://localhost:9000')
      Network::Device.list
      @device = Network::Device.search_dev({uevent: {driver: 'option'}}).first
    end

    def main
      setup
      test_handler

      exit unless @device
      #test_check_same_2
      #test_send_delete_sms
      #test_list_devices
    end

    def test_handler
      puts $handler.add({})
      sleep 120
    end

    def test_list_devices
    end

    def test_send_delete_sms
      @device.sms_scan
      sleep 2
      @device.sms_list.each { |sms|
        dp sms.inspect
        @device.sms_delete(sms._Index)
      }
      sleep 2
      @device.sms_scan
      sleep 2
      @device.sms_list.inspect
    end

    def test_check_same
      sys_net = [{:class => 'net', :path => '/sys/class/net/br0',
                  :uevent => {'devtype' => 'bridge', 'interface' => 'eth0',
                              'ifindex' => '5'},
                  :dirs => ['brif', 'power', 'bridge', 'queues', 'statistics']}]
      id_1 = [{class: 'net', uevent: {interface: 'eth.*'}, dirs: ['bridge']}]

      puts Network::Device::Stub.check_this(sys_net.first, id_1.first.keys, id_1.first).inspect
    end

    def test_check_same_2
      sys_net = [{:class => 'net',
                  :path => '/sys/class/net/eth1',
                  :dirs => ['power', 'brport', 'queues', 'statistics'],
                  :uevent => {'interface' => 'eth1', 'ifindex' => '3'},
                  :address => 'f0:ad:4e:02:07:40'}]
      id_1 = [{:class => 'net', :uevent => {:interface => 'eth.*'}}]

      puts Network::Device::Stub.check_this(sys_net.first, id_1.first.keys, id_1.first).inspect
    end

    def ussd_send(str)
      $op.modem.ussd_send(str)
      sleep 5
      dp $op.modem.ussd_fetch(str)
      sleep 2
    end

    def test_ussd
      $op.modem.sms_send('62154352', 'test1')
    end

  rescue Exception => e
    dputs(0) { 'Error: QooxView aborted' }
    dputs(0) { "#{e.inspect}" }
    dputs(0) { "#{e.to_s}" }
    puts e.backtrace
  end
end

main
