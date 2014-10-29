module Network
  extend HelperClasses::DPuts
  module Device
    attr_accessor :devices, :present
    extend HelperClasses::DPuts
    extend self

    ERROR=-1
    CONNECTED=1
    CONNECTING=2
    DISCONNECTING=3
    DISCONNECTED=4
    ERROR_CONNECTION=5

    @devices = {}
    @present = []

    def env_to_dev(env)
      env
    end

    def add_udev(env)
      add env_to_dev(env)
    end

    def add(dev)
      ddputs(4) { "Checking whether we find #{dev}" }
      @devices.each { |name, d|
        dputs(4) { "Checking #{dev} for #{name}-#{d}-#{d.ids}" }
        if d.check_new(dev)
          log_msg :Listener, "Adding device #{name} - #{dev.inspect}"
          @present.push d.new(dev)
        end
      }
    end

    def del_udev(env)
      del env_to_dev(env)
    end

    def del(dev)
      @present.each { |d|
        if d.check_this(dev)
          log_msg :Listener, "Deleting device #{d.name} - #{dev.inspect}"
          d.down
          @present.delete d
        end
      }
    end

    def file_to_hash(f)
      case IO.readlines(f).first
        when /=/
          IO.readlines(f).collect { |l|
            l.split(/=/).collect { |v| v.downcase.chomp }
          }.to_h
        else
          IO.readlines(f).first.chomp
      end
    end

    def files_to_hash(dir, files)
      files.select { |f| File.exists?("#{dir}/#{f}") }.
          collect { |f| [f.to_sym, file_to_hash("#{dir}/#{f}")] }.to_h
    end

    def get_dirs(dir)
      Dir["#{dir}/*"].select { |f| File.ftype(f) == 'directory' }.
          collect { |d| d.sub(/^.*\//, '') }
    end

    def scan
      return unless File.exists? '/sys'
      Dir['/sys/bus/usb/devices/*'].each { |usb|
        add({bus: 'usb', path: usb, uevent: file_to_hash("#{usb}/uevent"),
             dirs: get_dirs(usb)})
      }
      Dir['/sys/class/net/*'].each { |net|
        add({class: 'net', path: net, dirs: get_dirs(net)}.
                merge(files_to_hash(net, %w(uevent address))))
      }
    end

    class Stub
      extend HelperClasses::DPuts
      attr_reader :dev, :ids

      @ids = []
      @dev = nil

      def initialize(dev)
        @dev = dev
      end

      def self.inherited(other)
        dputs(2) { "Inheriting device #{other.inspect} - #{other.class.name}" }
        Device.devices[other.to_s.sub(/.*::/, '')] = other
        super(other)
      end

      def check_me(dev)
        Stub.check_this(dev, [:path], @dev)
      end

      def self.check_this(dev, attributes, dev_self)
        attributes.each { |a|
          att = a.to_sym
          ds = dev_self[att]
          d = dev[att]
          case ds.class.to_s
            when /Array/
              ds.each { |v| return false unless d.index(v) }
            when /Hash/
              ds.each { |k, v| return false unless d[k.to_s] =~ /^#{v}$/ }
            else
              return false unless ds =~ /^#{d}$/
          end
        }
        return true
      end

      def self.check_new(dev)
        self.ids.each { |id|
          return true if self.check_this(dev, id.keys, id)
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