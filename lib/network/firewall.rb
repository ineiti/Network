include 'helper_classes'

module Network
  module Firewall
    extend self

    def setup
      @tc = System.run_str('which tc')
      if @iptables = System.run_str('which iptables')
        @arg_w = System.run_str("#{@iptables} --help") =~ /-w/ ? '-w' : ''
      end
    end

    def tc(*a)
      return unless @tc
      System.run_bool "#{@tc} #{a.join(' ')}"
    end

    def ipt(*a)
      return unless @iptables
      System.run_str("#{@iptables} #{arg_w} #{a.join(' ')}")
    end

    def setup_iptables
      log_msg :Firewall, 'setting up iptables'
      tables = %w(PREROUTING POSTROUTING OUTPUT INPUT FORWARD)

      if ipt '-L -n' =~ /FASTLANE/
        ipt '-F FASTLANE'
      end
      tables.each { |t|
        ipt "-D #{t} -j FASTLANE"
      }
      ipt '-X FASTLANE'
      ipt '-N FASTLANE'
      tables.each{|t|
        ipt "-A #{t} -j FASTLANE"
      }
    end

    # Sets up tc for _dev_ with a maximum capacity of _kbps_
    # marks is an array of [kbps, marks]-values where _marks_ is the
    # "-j MARK --set-mark=" for iptables.
    # The first tuple is the default qdisc!
    def setup_speed_limit(dev, kbps, marks)
      setup_iptables

      log_msg :Firewall, 'setting up speed limit'
      tc "qdisc del dev #{dev} root"

      qdisc = "qdisc add dev #{dev}"
      cl = "class add dev #{dev}"
      filter = "filter add dev #{dev}"
      tc "#{qdisc} root handle 1: htb default 10"
      tc "#{cl} parent 1: classid 1:1 htb rate #{kbps}kbit burst 15k"

      id = 10
      marks.each{|kb, mark|
        tc "#{cl} parent 1:1 classid 1:#{id} htb rate #{kb.to_i}kbit"
        tc "#{qdisc} parent 1:#{id} handle #{id}: sfq perturb 10"
        tc "#{filter} parent 1:0 prio 1 protocol ip handle #{mark} fw flowid 1:#{id}"
        id += 10
      }

      setup_iptables
    end

    def mark_ip(ip, mark, action = 'A')
      log_msg :Firewall, "Putting action -#{action}- on #{ip} for mark #{mark}"
      ipt "-#{action} FASTLANE -d #{ip} -j MARK --set-mark=#{mark}"
      ipt "-#{action} FASTLANE -s #{ip} -j MARK --set-mark=#{mark}"
    end

    def unmark_ip(ip, mark)
      return unless ipt '-L FASTLANE' =~ /[^0-9]#{ip}[^0-9]/
      mark_ip ip, mark, 'D'
    end
  end
end