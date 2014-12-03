require 'observer'

module Network
  extend HelperClasses::DPuts
  module Device
    DEBUG_LVL = 3

    attr_accessor :devices, :present
    extend HelperClasses::DPuts
    extend self
    extend Observable

    ERROR=-1
    CONNECTED=1
    CONNECTING=2
    DISCONNECTING=3
    DISCONNECTED=4
    ERROR_CONNECTION=5

    @devices = {}
    @present = []

    def env_to_dev(subs, env, catchpath = false)
      sysenv = "/sys/#{env}"
      path = catchpath ? ".*/#{env.sub(/^.*\//, '')}" : sysenv
      dputs(3) { "udev-change: #{subs.inspect}, #{sysenv} - path = #{path}" }
      case subs
        when /usb/
          ret = {bus: 'usb', path: path}
          catchpath or ret.merge!({uevent: file_to_hash("#{sysenv}/uevent"),
                                   dirs: get_dirs(sysenv)})
        when /net/
          ret = {class: 'net', path: path}
          catchpath or ret.merge!({dirs: get_dirs(sysenv)}.
                                      merge(files_to_hash(sysenv, %w(uevent address))))
      end
      ret
    end

    def add_udev(subs, env)
      rescue_all {
        add env_to_dev(subs, env)
      }
    end

    def add(dev)
      #dputs_func
      dputs(3) { "Checking whether we find #{dev}" }
      @devices.each { |name, d|
        dputs(4) { "Checking #{dev} for #{name}-#{d}-#{d.ids}" }
        if d.check_new(dev)
          dputs(2) { "Adding device #{name} - #{dev.inspect}" }
          @present.push d.new(dev)
          changed
          notify_observers(:add, @present.last)
          dputs(3) { 'notified observers' }
        end
      }
    end

    def del_udev(subs, env)
      rescue_all{
        del env_to_dev(subs, env, true)
      }
    end

    def del(dev)
      @present.each { |d|
        if d.check_me(dev)
          log_msg :Listener, "Deleting device #{d.dev.inspect}"
          d.down
          changed
          notify_observers(:del, d)
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

    def load
      Dir[File.dirname(__FILE__) + '/devices/*.rb'].each { |f|
        dputs(3) { "Adding device-file #{f}" }
        require(f)
      }
    end

    def start_drb
      DRb.start_service 'druby://localhost:9000', Network::Device
      log_msg :Device, "Server running at #{DRb.uri}"
      trap('INT') { DRb.stop_service }
    end

    def scan
      return unless File.exists? '/sys'
      Dir['/sys/bus/usb/devices/*'].each { |usb|
        begin
          add({bus: 'usb', path: usb, uevent: file_to_hash("#{usb}/uevent"),
               dirs: get_dirs(usb)})
        rescue Errno::ENOENT => e
          log_msg :Devices, "Oups - #{usb} just disappeared"
        end
      }
      Dir['/sys/class/net/*'].each { |net|
        begin
          add({class: 'net', path: net, dirs: get_dirs(net)}.
                  merge(files_to_hash(net, %w(uevent address))))
        rescue Errno::ENOENT => e
          log_msg :Devices, "Oups - #{net} just disappeared"
        end
      }
    end

    def list
      @present.each { |p|
        dputs(1) { "Present: #{p.dev._path}" }
      }
    end

    def search_dev(filter)
      @present.select { |p|
        Stub.check_this(p.dev, filter.keys, filter)
      }
    end

=begin
      Methods needed:

      connection_start, connection_stop, connection_may_stop, connection_status
      reset, down

=end
    class Stub
      include HelperClasses::DPuts
      extend HelperClasses::DPuts
      attr_reader :dev, :ids, :operator
      include Observable

      @ids = []
      @dev = nil
      @operator = nil

      def initialize(dev)
        @dev = dev
        @operator = Operator.search_name(:Direct, self)
      end

      def self.inherited(other)
        dputs(2) { "Inheriting device #{other.inspect} - #{other.class.name}" }
        Device.devices[other.to_s.sub(/.*::/, '')] = other
        super(other)
      end

      def check_me(dev)
        Stub.check_this(dev, dev.keys.to_sym, @dev)
        Stub.check_this(dev, [:path], @dev)
      end

      def down
        changed
        notify_observers(:down)
      end

      def connection_may_stop
        log_msg :Device, "Connection could've ended"
      end

      def connection_status_old
        case connection_status
          when Device::CONNECTED
            4
          when Device::CONNECTING
            3
          else
            0
        end
      end

      def self.check_this(dev, attributes, dev_self = @dev)
        dputs(3) { "Checking #{dev} against device #{dev_self.inspect}" }
        attributes.each { |a|
          att = a.to_sym
          ds = dev_self[att]
          return false unless (d = dev[att])
          dputs(3) { "Checking #{att} - #{ds.inspect} - #{d.inspect}" }
          case ds.class.to_s
            when /Array/
              ds.each { |v| return false unless d.index(v) }
            when /Hash/
              ds.each { |k, v| return false unless d[k.to_s] =~ /^#{v}$/ }
            else
              return false unless ds =~ /^#{d}$/
          end
        }
        log_msg( :Device, "Found device #{dev.inspect} in #{self.class.name}")
        return true
      end

      def self.check_new(dev)
        dputs(3) { "New device #{dev}" }
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

  Device.load
  Device.start_drb
  Device.scan
end
