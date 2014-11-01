require 'singleton'
require 'helperclasses'
require 'thread'

module Network
  extend HelperClasses::DPuts

  class Connection
    attr_accessor :device, :operator
    extend HelperClasses::DPuts

    @device = nil
    @operator = nil

    def initialize(dev, op = nil)
      @device = dev
      @operator = Operator.search_name(op ? op : @device.get_operator, dev)
    end

    def start
      @device.connection_start
    end

    def stop
      @device.connection_stop
    end

    def status
      @device.connection_status
    end

    def status_old
      case status
        when Device::CONNECTED
          4
        when Device::CONNECTING
          3
        else
          0
      end
    end

    def may_stop
      @device.connection_may_stop
    end
  end
end
