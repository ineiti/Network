require 'helperclasses'

module Network
  module Captive
    extend self
    extend HelperClasses::DPuts
    attr_accessor :usage_daily, :ips_idle, :mac_list, :ip_list, :restricted,
                  :allow_dhcp, :internal_ips, :allow_dst, :allow_src_direct,
                  :allow_src_proxy, :captive_dnat, :prerouting, :http_proxy,
                  :openvpn_allow_double, :allow_double
# Iptable-rules:
# filter:FCAPTIVE - should be called at the end of the filter:FORWARD-table
#   allows new users and finishes with a BLOCK
# nat:CAPTIVE - should be called at the end of the nat:PREROUTING-table
#   redirects all paying users to the nat:INTERNET rule, before DNATting them
#   to the localhost
# nat:INTERNET - redirects to the proxy or direct
#   internet-access

    @prerouting = nil
    @http_proxy = nil
    @allow_dst = []
    @internal_ips = []
    @captive_dnat = '192.168.3.148'
    @openvpn_allow_double = false
    @allow_src_direct = []
    @allow_src_proxy = []

    @allow_dhcp = %w( 255.255.255.255 )
    @restricted = nil

    @ips_idle = []
    @mac_list = []
    @ip_list = []

    @users = []
    @users_conn = {}
    @disconnect_list = []
    @allow_double = true

    @operator = nil
    @device = nil

    @iptables_wait = ''

    @usage_daily = 0

    def log(msg)
      ddputs(2) { msg }
    end

    def log_(msg)
      log_msg :Captive, msg
    end

    def iptables(*cmds)
      ddputs(3) { cmds.join(' ') }
      System.run_str "iptables #{@iptables_wait} #{ cmds.join(' ') }"
    end

    def ipnat(*cmds)
      iptables "-t nat #{cmds.join(' ')}"
    end

    def ip_check(ip)
      return unless ip
      !@ip_list.index ip
    end

    def ip_drop(ip, apply)
      if apply or iptables('-L FCAPTIVE -nv') =~ /#{ip}.*DROP/
        op = apply ? '-I' : '-D'
        iptables "#{op} FCAPTIVE -s #{ip} -j DROP"
        iptables "#{op} FCAPTIVE -d #{ip} -j DROP"
      else
        log "Unapplying while #{ip} is not yet there"
      end
    end

    def ip_forward(ip, allow)
      if allow
        return if @ip_list.index(ip)
      else
        return unless @ip_list.index(ip)
      end
      @ip_list.push ip

      op = allow ? '-I' : '-D'
      iptables "#{op} FCAPTIVE -s #{ip} -j ACCEPT"
      iptables "#{op} FCAPTIVE -d #{ip} -j ACCEPT"
      ipnat "#{op} CAPTIVE -s #{ip} -j INTERNET"

      dp "Dropping with #{allow.inspect}"
      ip_drop(ip, !allow)
    end

    def mac_accept(mac)
      if !iptables '-L FCAPTIVE -n' =~ mac
        mac_ipt="-m mac --mac-source #{mac}"
        iptables "-I FCAPTIVE #{mac_ipt} -j ACCEPT"
        ipnat "-I CAPTIVE #{mac_ipt} -j INTERNET"
      end
    end

    def mac_deny(mac)
      if iptables '-L FCAPTIVE -n' =~ mac
        mac_ipt="-m mac --mac-source #{mac}"
        iptables "-I FCAPTIVE #{mac_ipt} -j ACCEPT"
        ipnat "-I CAPTIVE #{mac_ipt} -j INTERNET"
      end
    end

    def mac_check(mac)
      @mac_list.index mac.downcase
    end

    def mac_add(mac)
      m = mac.downcase
      if !mac_check m
        @mac_list.push m
        mac_accept m
      end
    end

    def mac_del(mac)
      m = mac.downcase
      if mac_check m
        @mac_list.delete m
        mac_deny m
      end
    end

    def var_array(name, splitchar = ',')
      val = self.send("#{name}") or return []
      self.send("#{name}=", val.split(splitchar))
      dputs(3) { "#{name} was #{val} and is #{self.send("#{name}").inspect}" }
    end

    def var_string_nil(name)
      val = self.send("#{name}")
      self.send("#{name}=", (val && val.length > 0) ? val : nil)
      dputs(3) { "#{name} was #{val} and is #{self.send("#{name}").inspect}" }
    end

    def var_bool(name)
      val = self.send("#{name}") or return false
      bool = if val.length > 0 then
               val.to_s == 'true' ? true : false
             else
               false
             end
      self.send("#{name}=", bool)
      dputs(3) { "#{name} was #{val} and is #{self.send("#{name}").inspect}" }
    end

    def clean_config
      %w( prerouting http_proxy captive_dnat restricted ).each { |var|
        var_string_nil(var)
      }
      %w( allow_dst internal_ips allow_src_direct allow_src_proxy ).each { |var|
        var_array(var)
      }
      %w( openvpn_allow_double ).each { |var|
        var_bool(var)
      }
    end

    def clear
      log_ 'Clearing IPs and refreshing MACs'
      ipnat '-F CAPTIVE'
      iptables '-F FCAPTIVE'

      @allow_dhcp ||= %w( 255.255.255.255 )
      @internal_ips ||=
          System.run_str ('ip addr | grep "inet " | '+
              'sed -e "s/.*inet \([^\/ ]*\).*/\1/" | grep -v 127.0.0.1)').split
      log_ "Internal is #{internal_ips}"
      (allow_dhcp + internal_ips + allow_dst).each { |ip|
        log_ "Allowing requests to #{ip} to go through"
        ipnat "-A NOCAPTIVE -d #{ip} -j ACCEPT"
        iptables "-A FCAPTIVE -d #{ip} -j ACCEPT"
      }

      @allow_src_direct.each { |ip|
        log_ "Allowing requests from #{ip} to go through"
        ipnat "-A NOCAPTIVE -s #{ip} -j ACCEPT"
        ipnat "-A NOCAPTIVE -d #{ip} -j ACCEPT"
        iptables "-A FCAPTIVE -s #{ip} -j ACCEPT"
        iptables "-A FCAPTIVE -d #{ip} -j ACCEPT"
      }

      if @captive_dnat
        log_ "Captive dnatting #{@captive_dnat}"
        ipnat "-I CAPTIVE -j DNAT --to-dest #{@captive_dnat}"
      end

      @ip_list.each { |ip|
        log_ "Accepting IP #{ip}"
        ip_accept ip
      }
      @mac_list.each { |mac|
        log_ "Accepting mac #{mac}"
        mac_accept mac
      }

      @allow_src_proxy.each { |ip|
        log_ "Allowing requests from #{ip} to go through Proxy"
        ipnat "-A NOCAPTIVE -s #{ip} -j INTERNET"
        ipnat "-A NOCAPTIVE -d #{ip} -j INTERNET"
        iptables "-A FCAPTIVE -s #{ip} -j ACCEPT"
        iptables "-A FCAPTIVE -d #{ip} -j ACCEPT"
      }

      iptables '-A FCAPTIVE -j RETURN'
      log_ 'Finished clean up'
    end

    def accept_all
      clear
      iptables '-A FCAPTIVE -j ACCEPT'
      ipnat '-I CAPTIVE -j INTERNET'
    end

    def packets_count(ip)
      if packets = iptables('-L FCAPTIVE -nv').split("\n").find { |l| l =~ /#{ip}/ }
        packets.split.first.to_i
      else
        0
      end
    end

    # This can be called from time to time to check on idle people
    def cleanup
      if @device.connection_status == Device::DISCONNECTED
        if ips_connected.length > 0
          if @operator.type != Operator::CONNECTION_ALWAYS
            log_ "Disconnecting everybody as we're not connected"
            users_disconnect_all
          else
            log_ 'Keeping users while we hope for a return of the connection'
          end
        end
      end

      if ips_connected.length == 0
        @device.connection_stop if @operator.connection_type == Operator::CONNECTION_ONDEMAND
      else
        ips_connected.each { |ip|
          packets = packets_count ip
          log "Checking ip #{ip} - has #{packets} packets"
          if packets == 0
            if @ips_idle.index ip
              log_ "No packets, kicking #{ip}"
              user_disconnect_ip ip
              @ips_idle.delete ip
              log "ips_idle is now #{@ips_idle}"
            else
              log "#{ip} is idle, adding to list"
              @ips_idle.push ip
            end
          else
            @ips_idle.delete ip
          end
        }
      end

      dputs(2) { 'Clearing counters' }
      iptables '-Z FCAPTIVE'
    end

    def delete_chain(par, ch, table = nil)
      chain = ch.to_s
      ipt = table ? "-t #{table}" : ''
      if iptables(ipt, '-L', par, '-n').index(chain)
        if par
          iptables ipt, "-D #{par.to_s} -j #{chain}"
        end
        iptables ipt, "-F #{chain}"
        iptables ipt, "-X #{chain}"
      end
      iptables ipt, "-N #{chain}"
      if par
        iptables ipt, "-I #{par.to_s} -j #{chain}"
      end
    end

    def setup(dev = nil)
      log_ "Setting up with #{dev.inspect}"
      if dev
        @device = dev
        @operator = dev.operator
      end

      delete_chain :PREROUTING, :CAPTIVE, :nat
      delete_chain :PREROUTING, :NOCAPTIVE, :nat

      delete_chain nil, :INTERNET, :nat
      if @http_proxy
        ipnat "-A INTERNET -p tcp --dport 80 -j DNAT --to-dest #{@http_proxy}"
      end
      ipnat '-A INTERNET -j ACCEPT'

      delete_chain :FORWARD, :FCAPTIVE
      if @allow_free != :all
        iptables '-P FORWARD DROP'
      end

      clear

      ips_connected.each { |ip|
        log_ "Re-connecting #{ip}"
        ip_forward ip, true
      }

      if @restricted
        log "Setting restrictions of #{@restricted.inspect}"
        restriction_set @restricted
      end
    end

    def block(ip)
      log "Blocking #{ip}"
    end

    # Restriction for a particular center - should be made more general...
    def restr_man(net, block)
      %w( 10.1.0.0/24 10.1.10.0/21 10.2.10.0/21 ).each { |default|
        ip_drop default, block
      }
      ip_drop net, !block
    end

    def restriction_set(rest = nil)
      @restricted and restr_man(@restricted, false)
      @restricted = rest
      case rest
        when /info1/
          restr_man('10.1.11.0/24', true)
        when /info2/
          restr_man('10.1.12.0/24', true)
        else
          @restricted = nil
      end
    end

    def users_connected
      @users_conn.collect { |u, ip| u }
    end

    def user_connected(name)
      @users_conn.has_key? name
    end

    def ips_connected
      @users_conn.collect { |u, ip| ip }
    end

    def user_connect(ip, n, free = false)
      @device and @device.connection_start
      name = n.to_s

      if user_connected name
        log "User #{name} already connected"
        return unless @allow_double
      end

      same_ip = @users_conn.key ip
      log "Connecting user #{name} - #{ip}"
      @users_conn[name] = ip

      same_ip and user_disconnect(same_ip, ip)
      ip_forward ip, true
    end

    def user_disconnect_name(name)
      return unless ip = @users_conn[name.to_s]
      user_disconnect(name.to_s, ip)
    end

    def user_disconnect_ip(ip)
      return unless name = @users_conn.key(ip)
      user_disconnect(name, ip)
    end

    def users_disconnect_all
      @users_conn.dup.each { |name, ip|
        user_disconnect name, ip
      }
    end

    def user_disconnect(name, ip)
      log_ "user_disconnect #{name}:#{ip}"

      return unless ip = @users_conn[name]
      @users_conn.delete name
      ip_forward ip, false

      @users_conn.length == 0 and @device.connection_may_stop
    end

    def user_cost_now
      10
    end
  end
end
