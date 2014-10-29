module Network
  extend HelperClasses::DPuts
  module Device
    attr_accessor :devices, :present
    extend HelperClasses::DPuts
    extend self

    @devices = {}
    @present = []

    def env_to_dev(env)
      env
    end

    def add_udev(env)
      add env_to_dev(env)
    end

    def add( dev )
      @devices.each { |name,d|
        ddputs(4){"Checking #{dev} for #{name}-#{d}-#{d.ids}"}
        if d.check_new(dev)
          log :Listener, "Adding device #{name} - #{dev.inspect}"
          @present.push d.new(dev)
        end
      }
    end

    def del_udev(env)
      del env_to_dev(env)
    end

    def del( dev )
      @present.each { |d|
        if d.check_same(dev)
          log :Listener, "Deleting device #{d.name} - #{dev.inspect}"
          d.down
          @present.delete d
        end
      }
    end

    def scan
      return unless File.exists? '/sys'
      Dir['/sys/bus/usb/devices/*'].each{|usb|
        add({bus:'usb'})
      }
      Dir['/sys/class/net/*'].each{|usb|
        add({class:'net'})
      }
    end

    class Stub
      extend HelperClasses::DPuts
      attr_reader :dev, :ids

      @ids = []
      @dev = nil

      def self.inherited(other)
        dputs(2) { "Inheriting device #{other.inspect} - #{other.class.name}" }
        Device.devices[other.to_s.sub(/.*::/, '')] = other
        super(other)
      end

      def check_same(dev, attributes)
        Stub.check_same( dev, attributes, @dev)
      end

      def self.check_same( dev, attributes, dev_self)
        attributes.each { |a|
          att = a.to_sym
          return false if dev_self[att] != dev[att]
        }
        return true
      end

      def self.check_new( dev )
        self.ids.each{|id|
          return true if self.check_same( dev, id.keys, id)
        }
        return false
      end

      def self.ids
        @ids || []
      end
    end
  end

  Dir[File.dirname(__FILE__) + '/devices/*.rb'].each { |f|
    dputs(3) { "Adding device-file #{f}" }
    require(f)
  }

  DRb.start_service 'druby://:9000', Network::Device
  dputs(0) { "Server running at #{DRb.uri}" }
  trap('INT') { DRb.stop_service }

  Device.scan
end