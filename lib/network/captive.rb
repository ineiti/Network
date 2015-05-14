require 'helper_classes'
require 'network/monitor/traffic'

module Network
  module Captive
    extend self
    extend HelperClasses::DPuts
    extend HelperClasses
    include HelperClasses
    attr_accessor :usage_daily, :ips_idle, :mac_list, :ip_list, :restricted,
                  :allow_dhcp, :internal_ips, :allow_dst, :allow_src_direct,
                  :allow_src_proxy, :captive_dnat, :prerouting, :http_proxy,
                  :openvpn_allow_double, :allow_double, :cleanup_skip,
                  :keep_idle_minutes, :traffic
# Iptable-rules:
# filter:FCAPTIVE - should be called at the end of the filter:FORWARD-table
#   allows new users and finishes with a BLOCK
# nat:CAPTIVE - should be called at the end of the nat:PREROUTING-table
#   redirects all paying users to the nat:INTERNET rule, before DNATting them
#   to the localhost
# nat:INTERNET - redirects to the proxy or direct
#   internet-access

    @traffic = nil
    @prerouting = nil
    @http_proxy = nil
    @allow_dst = []
    @internal_ips = []
    @captive_dnat = ''
    @openvpn_allow_double = false
    @allow_src_direct = []
    @allow_src_proxy = []
    @keep_idle_minutes = 3

    @allow_dhcp = %w( 255.255.255.255 )
    @restricted = nil

# Countdown for all idle IPs. Can be positive (keep_idle_minutes) or
# negative (user_keep). Disconnected on 0
    @ips_idle = {}
    @mac_list = []
    @ip_list = []

    @users = []
    @users_conn = {}
    @disconnect_list = []
    @allow_double = true

    @operator = nil
    @device = nil

    @usage_daily = 0
    @cleanup_skip = false

    def log(msg)
      dputs(3) { msg }
    end

    def log_(msg)
      log_msg :Captive, msg
    end

    def iptables(*args)
      System.iptables(args)
    end

    def ipnat(*cmds)
      iptables "-t nat #{cmds.join(' ')}"
    end

    def ip_check(ip)
      return unless ip
      !@ip_list.index ip
    end

    def ip_drop(ip, apply)
      log "Drop: Applying #{apply.inspect} for #{ip}"
      if apply or iptables('-L FCAPTIVE -nv') =~ /DROP.*#{ip}/
        op = apply ? '-I' : '-D'
        iptables "#{op} FCAPTIVE -s #{ip} -j DROP"
        iptables "#{op} FCAPTIVE -d #{ip} -j DROP"
      else
        log "Unapplying while #{ip} is not yet there"
      end
    end

    def ip_accept(ip, apply)
      log "Accept: Applying #{apply.inspect} for #{ip}"
      if apply or iptables('-L FCAPTIVE -nv') =~ /ACCEPT.*#{ip}/
        op = apply ? '-I' : '-D'
        iptables "#{op} FCAPTIVE -s #{ip} -j ACCEPT"
        iptables "#{op} FCAPTIVE -d #{ip} -j ACCEPT"
      else
        log "Unapplying while #{ip} is not yet there"
      end
    end

    def ip_forward(ip, allow)
      log "#{ip}:#{allow.inspect} - #{@ip_list.inspect}"
      if allow
        return if @ip_list.index(ip)
        @ip_list.push ip
      else
        return unless @ip_list.index(ip)
        @ip_list.delete ip
      end

      op = allow ? '-I' : '-D'
      iptables "#{op} FCAPTIVE -s #{ip} -j ACCEPT"
      iptables "#{op} FCAPTIVE -d #{ip} -j ACCEPT"
      ipnat "#{op} CAPTIVE -s #{ip} -j INTERNET"

      log "Dropping with #{allow.inspect}"
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
        iptables "-D FCAPTIVE #{mac_ipt} -j ACCEPT"
        ipnat "-D CAPTIVE #{mac_ipt} -j INTERNET"
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

    def var_array_nil(name, splitchar = ',')
      val = self.send("#{name}") || ''
      val = (val.length > 0 ? val.split(splitchar) : nil)
      self.send("#{name}=", val)
      log "#{name} was #{val} and is #{self.send("#{name}").inspect}"
    end

    def var_array(name, splitchar = ',')
      val = self.send("#{name}") || ''
      val = (val.length > 0 ? val.split(splitchar) : [])
      self.send("#{name}=", val)
      log "#{name} was #{val} and is #{self.send("#{name}").inspect}"
    end

    def var_string_nil(name)
      val = self.send("#{name}")
      self.send("#{name}=", (val && val.length > 0) ? val : nil)
      log "#{name} was #{val} and is #{self.send("#{name}").inspect}"
    end

    def var_bool(name)
      val = self.send("#{name}") or return false
      bool = if val.length > 0 then
               val.to_s == 'true' ? true : false
             else
               false
             end
      self.send("#{name}=", bool)
      log "#{name} was #{val} and is #{self.send("#{name}").inspect}"
    end

    def var_int(name)
      val = self.send("#{name}") or return false
      self.send("#{name}=", val.to_i)
      log "#{name} was #{val} and is #{self.send("#{name}").inspect}"
    end

    def clean_config
      %w( prerouting http_proxy captive_dnat restricted ).each { |var|
        var_string_nil(var)
      }
      %w( allow_dst internal_ips ).each { |var|
        var_array_nil(var)
      }
      %w( allow_src_direct allow_src_proxy mac_list ).each { |var|
        var_array(var)
      }
      %w( openvpn_allow_double ).each { |var|
        var_bool(var)
      }
      %w( keep_idle_minutes ).each { |var|
        var_int(var)
      }
    end

    def clear
      log_ 'Clearing IPs and refreshing MACs'
      ipnat '-F CAPTIVE'
      ipnat '-F NOCAPTIVE'
      iptables '-F FCAPTIVE'
      iptables '-F NOFCAPTIVE'

      @allow_dhcp ||= %w( 255.255.255.255 )
      if System.exists? 'ip'
        @internal_ips ||=
            System.run_str('ip addr | grep "inet " | ' +
                               'sed -e "s/.*inet \([^\/ ]*\).*/\1/" | grep -v 127.0.0.1').split
      else
        @internal_ips ||= []
      end
      @allow_dst ||= @internal_ips
      log "Internal is #{internal_ips}"
      log "Allow_dhcp is #{allow_dhcp} - allow_dst is #{allow_dst}"
      (allow_dhcp + internal_ips + allow_dst).each { |ip|
        log "Allowing requests to #{ip} to go through"
        ipnat "-A NOCAPTIVE -d #{ip} -j ACCEPT"
        iptables "-A NOFCAPTIVE -d #{ip} -j ACCEPT"
      }

      @allow_src_direct.each { |ip|
        log "Allowing requests from #{ip} to go through"
        ipnat "-A NOCAPTIVE -s #{ip} -j ACCEPT"
        ipnat "-A NOCAPTIVE -d #{ip} -j ACCEPT"
        iptables "-A NOFCAPTIVE -s #{ip} -j ACCEPT"
        iptables "-A NOFCAPTIVE -d #{ip} -j ACCEPT"
      }

      if !@captive_dnat
        if System.exists?('ip') &&
            System.run_str('ip addr | grep "inet .*\.1\/.* brd"') =~ /inet (.*)\/.* brd/
          @captive_dnat = $1
          log "Found local gateway and defining as captive: #{@captive_dnat}"
        end
      end
      if @captive_dnat
        log "Captive dnatting #{@captive_dnat}"
        ipnat "-I CAPTIVE -j DNAT --to-dest #{@captive_dnat}"
      end

      #@ip_list.each { |ip|
      #  log "Accepting IP #{ip}"
      #  ip_accept ip, true
      #}
      #@mac_list.each { |mac|
      #  log "Accepting mac #{mac}"
      #  mac_accept mac
      #}

      @allow_src_proxy.each { |ip|
        log "Allowing requests from #{ip} to go through Proxy"
        ipnat "-A NOCAPTIVE -s #{ip} -j INTERNET"
        ipnat "-A NOCAPTIVE -d #{ip} -j INTERNET"
        iptables "-A NOFCAPTIVE -s #{ip} -j ACCEPT"
        iptables "-A NOFCAPTIVE -d #{ip} -j ACCEPT"
      }

      iptables '-A FCAPTIVE -j RETURN'
      iptables '-A NOFCAPTIVE -j RETURN'
      log 'Finished cleaning up'
    end

    def accept_all
      clear
      iptables '-A FCAPTIVE -j ACCEPT'
      ipnat '-I CAPTIVE -j INTERNET'
    end

    def iptables_count(ip, pos)
      if packets = iptables('-L FCAPTIVE -nv').split("\n").select { |l| l =~ /#{ip}[^0-9]/ }
        s = packets.collect { |p| p.split[pos] }.inject(0) { |c, i| c + i.to_i }
        dputs(3) { "Sum for #{ip} with pos #{pos} in #{packets} is #{s}" }
        s
      else
        0
      end
    end

    def packets_count(ip)
      iptables_count(ip, 0)
    end

    def bytes_count(ip)
      iptables_count(ip, 1)
    end

# This can be called from time to time to check on idle people
    def cleanup
      return if @cleanup_skip
      dputs_func

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

      log "ips_connected is #{ips_connected.inspect}"
      if ips_connected.length == 0
        @device.connection_stop if @operator.connection_type == Operator::CONNECTION_ONDEMAND
      else
        ips_connected.each { |ip|
          packets = packets_count ip
          log "Checking ip #{ip} - has #{packets} packets - " +
                  "keep_idle_minutes is #{@keep_idle_minutes.inspect}"
          if packets == 0
            if min = @ips_idle[ip]
              if @ips_idle[ip] == 0
                log_ "No packets from #{ip} for #{@keep_idle_minutes}, kicking"
                user_disconnect_ip ip
                @ips_idle.delete ip
              else
                @ips_idle[ip] -= min.abs / min
              end
              log_ "ips_idle for #{ip} is now #{@ips_idle.inspect}"
            else
              log_ "#{ip} is idle, adding to list for #{@keep_idle_minutes}"
              @ips_idle[ip] = @keep_idle_minutes
            end
          else
            @ips_idle.delete ip
          end
        }
      end

      log 'Clearing counters'
      iptables '-Z FCAPTIVE'
    end

    def reset_chain(par, ch, table = nil)
      chain = ch.to_s
      ipt = table ? "-t #{table}" : ''
      if iptables(ipt, '-L', par, '-n').index(chain)
        if par
          while iptables(ipt, "-L #{par.to_s} -nv") =~ / #{chain} /
            iptables ipt, "-D #{par.to_s} -j #{chain}"
          end
        end
        iptables ipt, "-F #{chain}"
        iptables ipt, "-X #{chain}"
      end
      iptables ipt, "-N #{chain}"
      if par
        iptables ipt, "-A #{par.to_s} -j #{chain}"
      end
    end

    def setup(dev = nil, traffic_str = '')
      if dev
        log_ "Setting up with #{dev.class.name} - #{dev.operator}"
        @device = dev
        @operator = dev.operator
      end

      reset_chain :PREROUTING, :NOCAPTIVE, :nat
      reset_chain :PREROUTING, :CAPTIVE, :nat

      reset_chain nil, :INTERNET, :nat
      if @http_proxy
        ipnat "-A INTERNET -p tcp --dport 80 -j DNAT --to-dest #{@http_proxy}"
      end
      ipnat '-A INTERNET -j ACCEPT'

      reset_chain :FORWARD, :NOFCAPTIVE
      reset_chain :FORWARD, :FCAPTIVE
      if @allow_free != :all
        iptables '-P FORWARD DROP'
      end

      clear
      Monitor::Traffic.setup_config
      Monitor::Traffic.create_iptables
      if traffic_str.to_s.length > 0
        @traffic = Monitor::Traffic::User.from_json traffic_str
      else
        @traffic = Monitor::Traffic::User.new
      end

      @ip_list.clear
      ips_connected.each { |ip|
        log_ "Re-connecting #{ip}"
        ip_forward ip, true
        Monitor::Traffic.ip_add(ip, name)
      }
      @mac_list.each { |mac|
        log "Accepting mac #{mac}"
        mac_accept mac
      }

      if @restricted
        log_ "Setting restrictions of #{@restricted.inspect}"
        restriction_set @restricted
      end
    end

    def block(ip)
      log "Blocking #{ip}"
    end

# Restriction for a particular center - should be made more general...
    def restr_man(net, block)
      %w( 10.1.0.0/24 10.1.8.0/21 10.2.8.0/21 ).each { |default|
        ip_drop default, block
      }
      ip_accept net, block
    end

    def restriction_set(rest = nil)
      @restricted and restr_man(@restricted, false)
      rest and users_disconnect_all
      case rest
        when /info1/
          @restricted = '10.1.11.0/24'
          restr_man(@restricted, true)
        when /info2/
          @restricted = '10.1.12.0/24'
          restr_man(@restricted, true)
        else
          @restricted = nil
      end
    end

    def users_connected
      @users_conn.collect { |u, ip| u }
    end

    def user_connected(name)
      @users_conn.has_key? name.to_s
    end

    def ips_connected
      @users_conn.collect { |u, ip| ip }
    end

    def user_connect(n, ip, free = false)
      @device and @device.connection_start
      name = n.to_s

      if user_connected name
        if @users_conn[name] == ip
          log_ "User #{name} already connected from #{ip}"
          return
        else
          if @allow_double
            log_ "User #{name} connecting more than once"
          else
            log_ "User #{name} already connected, disconnecting other"
            user_disconnect_name(name)
          end
        end
      end

      same_ip = @users_conn.key ip
      log_ "Connecting user #{name} - #{ip}"
      @users_conn[name] = ip

      same_ip and user_disconnect(same_ip, ip)
      ip_forward ip, true
      Monitor::Traffic.ip_add(ip, name)
    end

    def user_disconnect_name(n)
      name = n.to_s
      return unless ip = @users_conn[name]
      user_disconnect(name, ip)
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

    def user_disconnect(n, ip = nil)
      name = n.to_s
      log_ "user_disconnect #{name}:#{ip} - #{@users_conn.inspect}"

      ip or (return unless ip = @users_conn[name])
      log_ "really disconnecting #{name.inspect} from #{ip}"
      @users_conn.delete name
      ip_forward ip, false
      Monitor::Traffic.ip_del_name name

      @users_conn.length == 0 and @device and @device.connection_may_stop
    end

    def user_cost_now
      10
    end

    def user_keep(n, min, force = false)
      name = n.to_s
      log "user_keep #{n} for #{min} and forcing #{force} - #{@users_conn.inspect}"
      return unless ip = @users_conn[name]
      if @ips_idle.has_key?(ip) && (@ips_idle[ip] > 0 || force)
        log "Keeping #{name} from #{ip} for #{min.inspect} minutes"
        @ips_idle[ip] = -min
      end
    end
  end
end
