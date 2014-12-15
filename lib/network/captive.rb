require 'helperclasses'

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
                  :keep_idle_minutes
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

    @iptables_wait = ''
    @iptables_present = System.exists? 'iptables'

    @usage_daily = 0
    @cleanup_skip = false

    def log(msg)
      dputs(3) { msg }
    end

    def log_(msg)
      log_msg :Captive, msg
    end

    def iptables(*cmds)
      if @iptables_present
        log cmds.join(' ')
        System.run_str "iptables #{@iptables_wait} #{ cmds.join(' ') }"
      else
        log cmds.join(' ')
        ''
      end
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
      iptables '-F FCAPTIVE'

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
        iptables "-A FCAPTIVE -d #{ip} -j ACCEPT"
      }

      @allow_src_direct.each { |ip|
        log "Allowing requests from #{ip} to go through"
        ipnat "-A NOCAPTIVE -s #{ip} -j ACCEPT"
        ipnat "-A NOCAPTIVE -d #{ip} -j ACCEPT"
        iptables "-A FCAPTIVE -s #{ip} -j ACCEPT"
        iptables "-A FCAPTIVE -d #{ip} -j ACCEPT"
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

      @ip_list.each { |ip|
        log "Accepting IP #{ip}"
        ip_accept ip, true
      }
      @mac_list.each { |mac|
        log "Accepting mac #{mac}"
        mac_accept mac
      }

      @allow_src_proxy.each { |ip|
        log "Allowing requests from #{ip} to go through Proxy"
        ipnat "-A NOCAPTIVE -s #{ip} -j INTERNET"
        ipnat "-A NOCAPTIVE -d #{ip} -j INTERNET"
        iptables "-A FCAPTIVE -s #{ip} -j ACCEPT"
        iptables "-A FCAPTIVE -d #{ip} -j ACCEPT"
      }

      iptables '-A FCAPTIVE -j RETURN'
      log 'Finished cleaning up'
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
      return if @cleanup_skip

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
              @ips_idle[ip] -= min.abs / min
              if @ips_idle[ip] == 0
                log_ "No packets from #{ip} for #{@keep_idle_minutes}, kicking"
                user_disconnect_ip ip
                @ips_idle.delete ip
              end
              log "ips_idle is now #{@ips_idle.inspect}"
            else
              log "#{ip} is idle, adding to list"
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
      if dev
        log_ "Setting up with #{dev.class.name} - #{dev.operator}"
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
          log_ "User #{name} already connected"
          return unless @allow_double
        end
      end

      same_ip = @users_conn.key ip
      log_ "Connecting user #{name} - #{ip}"
      @users_conn[name] = ip

      same_ip and user_disconnect(same_ip, ip)
      ip_forward ip, true
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

      @users_conn.length == 0 and @device and @device.connection_may_stop
    end

    def user_cost_now
      10
    end

    def user_keep(n, min)
      name = n.to_s
      return unless ip = @users_conn[name]
      if @ips_idle.has_key?(ip) && @ips_idle[ip] > 0
        log "Keeping #{name} from #{ip} for #{min} minutes"
        @ips_idle[ip] = -min
      end
    end
  end
end
