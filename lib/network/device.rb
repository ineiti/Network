require 'observer'
require 'helper_classes'
require 'fileutils'
include HelperClasses::DPuts

module Network
  module Device
    DEBUG_LVL = 1

    attr_accessor :devices, :present
    extend HelperClasses::DPuts
    extend HelperClasses::System
    include HelperClasses
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

    def install_system
      if Platform.system != :MacOSX
        udev_path = File.expand_path('../../../udev', __FILE__)
        FileUtils.cp "#{udev_path}/90-network-udev.rules", '/lib/udev/rules.d'
        FileUtils.cp "#{udev_path}/device_udev", '/usr/local/bin'
        FileUtils.cp "#{udev_path}/device_udev.rb", '/usr/local/bin'
      end
    end

    def env_to_dev(subs, env, catchpath = false)
      #dputs_func
      sysenv = "/sys/#{env}"
      path = catchpath ? ".*/#{env.sub(/^.*\//, '')}" : sysenv
      dputs(3) { "udev-change: #{subs.inspect}, #{sysenv} - path = #{path}" }
      case subs
        when /usb/
          ret = {bus: 'usb', path: path}
          catchpath or ret.merge!({uevent: file_to_hash("#{sysenv}/uevent"),
                                   dirs: get_dirs(sysenv)})
        when /option/
          ret = {bus: 'usb', path: path}
          catchpath or ret.merge!({uevent: file_to_hash("#{sysenv}/../uevent"),
                                   dirs: get_dirs("#{sysenv}/..")})
          dputs(3) { "option: #{ret}" }
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
      newdev = nil
      HelperClasses::System.rescue_all do
        # dputs_func
        dputs(3) { "Checking whether we find #{dev}" }
        @devices.each { |name, d|
          dputs(4) { "Checking #{dev} for #{name}-#{d}-#{d.ids}" }
          if d.check_compatible(dev)
            path = dev._path.to_s
            if search_dev({path: path}).length > 0 ||
                search_dev({path: File.dirname(path)}).length > 0
              dputs(2) { "This device #{dev} is already instantiated!" }
            else
              dputs(3) { "Adding device #{name} - #{dev.inspect}" }
              newdev = d.new(dev)
              if newdev.dev
                @present.push(newdev)
                changed
                notify_observers(:add, @present.last)
                dputs(3) { 'notified observers' }
              else
                log_msg :Device, "Instantiation failed for #{dev}"
              end
            end
          end
        }
      end
      newdev
    end

    def del_udev(subs, env)
      rescue_all {
        del env_to_dev(subs, env)
      }
    end

    def del(dev)
      #dputs_func
      dev._path += '.*'
      dputs(3) { "#{dev} disappeared" }
      @present.each { |d|
        dputs(3) { "Checking if #{dev} ==" }
        dputs(3) { "#{d}" }
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
      return '' unless File.exists?(f)
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

    def start
      start_drb
      scan
    end

    def start_drb
      install_system
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
      attr_reader :dev, :ids, :operator, :network_dev
      include Observable

      @ids = []
      @dev = nil
      @operator = nil

      def initialize(dev)
        log_msg :Device, "Initialized device #{dev}"
        @dev = dev
        @operator = Operator.search_name(:Direct, self)
      end

      def set_operator(op)
        log_msg :Device, "Forcing operator to #{op}"
        @operator = Operator.search_name(op, self)
      end

      def sms_inject(msg, number = '1234',
                     date = Time.now.strftime('%Y-%m-%d %H:%M:%S'), index = -1)
        sms = sms_new(index, 'unread', number, date, msg)
        log_msg :Operator, "Injected SMS #{sms.inspect}"
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

      def sms_scan
      end

      def self.check_this(dev, attributes, dev_self = @dev)
        # dputs_func
        dputs(3) { "Checking #{dev} against device #{dev_self.inspect} in #{attributes.inspect}" }
        attributes.each { |a|
          att = a.to_sym
          d_self = dev_self[att]
          d_other = dev && dev[att]
          dputs(3) { "Checking #{att} - #{d_self.inspect} - #{d_other.inspect}" }
          return false unless d_other
          case d_self.class.to_s
            when /Array/
              d_self.each { |v| return false unless d_other.index(v) }
            when /Hash/
              if d_other.class.to_s == 'Hash'
                d_self.each { |k, v|
                  do_data = d_other.send("_#{k}")
                  dputs(4) { "Checking #{k.inspect}: #{do_data.inspect} against #{v.inspect}" }
                  return false unless do_data =~ /^#{v}$/ }
              end
            else
              return false unless d_self =~ /^#{d_other}$/
          end
        }
        dputs(3) { "Found device #{dev.inspect} in #{self.class.name}" }
        return true
      end

      def self.check_compatible(dev)
        # dputs_func
        dputs(3) { "New device #{dev}" }
        self.ids.each { |id|
          dputs(3) { "Checking against #{id.inspect}" }
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
end
