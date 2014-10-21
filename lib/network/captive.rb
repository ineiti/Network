module Network
  module Captive
    extend self
# Iptable-rules:
# filter:FCAPTIVE - should be called at the end of the filter:FORWARD-table
#   allows new users and finishes with a BLOCK
# nat:CAPTIVE - should be called at the end of the nat:PREROUTING-table
#   redirects all paying users to the nat:INTERNET rule, before DNATting them
#   to the localhost
# nat:INTERNET - redirects to the proxy or direct
#   internet-access

    @ips_idle = []
    @mac_list = []
    @ip_list = []
    @restricted = []
    @allow_dhcp = %w( 255.255.255.255 )
    @internal_ips = []
    @allow_dst = []
    @allow_src_direct = []
    @allow_src_proxy = []
    @captive_dnat = nil

    @users = []
    @users_connected = {}
    @disconnect_list = []
    @allow_double = true

    def iptables(*cmds)
      System.run_str "iptables #{ cmds.join(' ') }"
    end

    def ipnat(*cmds)
      iptables "-t nat #{cmds.join(' ')}"
    end

    def captive_ip(op, ip)
      iptables "#{op} FCAPTIVE -s #{ip} -j ACCEPT"
      iptables "#{op} FCAPTIVE -d #{ip} -j ACCEPT"
      ipnat "#{op} CAPTIVE -s #{ip} -j INTERNET"
    end

    def captive_ip_drop(op, ip)
      iptables "#{op} FCAPTIVE -s #{ip} -j DROP"
      iptables "#{op} FCAPTIVE -d #{ip} -j DROP"
    end

    def captive_ip_accept(ip)
      captive_ip '-I', ip
    end

    def captive_ip_deny(ip)
      captive_ip '-D', ip
    end

    def captive_ip_check(ip)
      return unless ip
      !@ip_list.index ip
    end

    def captive_ip_add(ip)
      if !captive_ip_check ip
        @ip_list.push ip
        captive_ip_accept ip
      end
    end

    def captive_ip_del(ip)
      @ip_list.remove ip
      captive_ip_deny ip
    end

    def captive_mac_accept(mac)
      if !iptables '-L FCAPTIVE -n' =~ mac
        mac_ipt="-m mac --mac-source #{mac}"
        iptables "-I FCAPTIVE #{mac_ipt} -j ACCEPT"
        ipnat "-I CAPTIVE #{mac_ipt} -j INTERNET"
      end
    end

    def captive_mac_deny(mac)
      if iptables '-L FCAPTIVE -n' =~ mac
        mac_ipt="-m mac --mac-source #{mac}"
        iptables "-I FCAPTIVE #{mac_ipt} -j ACCEPT"
        ipnat "-I CAPTIVE #{mac_ipt} -j INTERNET"
      end
    end

    def captive_mac_check(mac)
      @mac_list.index mac.downcase
    end

    def captive_mac_add(mac)
      m = mac.downcase
      if !captive_mac_check m
        @mac_list.push m
        captive_mac_accept m
      end
    end

    def captive_mac_del(mac)
      m = mac.downcase
      if captive_mac_check m
        @mac_list.delete m
        captive_mac_deny m
      end
    end

    def captive_clear()
      loga 'Clearing IPs and refreshing MACs'
      ipnat '-F CAPTIVE'
      iptables '-F FCAPTIVE'

      @allow_dhcp ||= %w( 255.255.255.255 )
      @internal_ips ||=
          System.run_str ('ip addr | grep "inet " | '+
              'sed -e "s/.*inet \([^\/ ]*\).*/\1/" | grep -v 127.0.0.1)').split
      log "Internal is #{internal_ips}"
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

      if @captive_dnat
        ipnat "-I CAPTIVE -j DNAT --to-dest #{@captive_dnat}"
      end

      @ip_list.each { |ip|
        captive_ip_accept ip
      }
      local mac
      @mac_list.each { |mac|
        captive_mac_accept mac
      }

      @allow_src_proxy.each { |ip|
        log "Allowing requests from #{ip} to go through Proxy"
        ipnat "-A NOCAPTIVE -s #{ip} -j INTERNET"
        ipnat "-A NOCAPTIVE -d #{ip} -j INTERNET"
        iptables "-A FCAPTIVE -s #{ip} -j ACCEPT"
        iptables "-A FCAPTIVE -d #{ip} -j ACCEPT"
      }

      iptables '-A FCAPTIVE -j RETURN'
    end

    def captive_accept_all
      captive_clear
      iptables '-A FCAPTIVE -j ACCEPT'
      ipnat '-I CAPTIVE -j INTERNET'
    end

    def captive_packets_count(ip)
      iptables('-L FCAPTIVE -nv').split("\n").find { |l| l =~ /#{ip}/ }.
          split.first.to_i
    end

    # This can be called from time to time to check on idle people
    def captive_cleanup
      if Connection.status == Connection::DISCONNECTED
        if ips_connected.length > 0
          if Connection.type != Connection::CONNECTION_ALWAYS
            log "Disconnecting everybody as we're not connected"
            users_disconnect_all
          else
            log 'Keeping users while we hope for a return of the connection'
          end
        end
      end

      if ips_connected.length == 0
        if Connection.type == Connection::CONNECTION_ONDEMAND
          Connection.stop
        else
          ips_connected.each { |ip|
            packets = captive_packets_count ip
            log "Checking ip #{ip} - has #{packets} packets"
            if packets == 0
              if @ips_idle.index ip
                loga "No packets, kicking #{ip}"
                user_disconnect_ip ip
                @ips_idle.delete ip
                loga "ips_idle is now #{@ips_idle}"
              else
                loga "#{ip} is idle, adding to list"
                @ips_idle.push ip
              end
            else
              @ips_idle.delete ip
            end
          }
        end
      end

      #  log Clearing counters
      iptables '-Z FCAPTIVE'
    end

    def delete_chain(parent, chain, table = nil)
      ipt = table ? "-t #{table}" : ''
      if iptables(ipt, '-L', parent).index(chain)
        if parent
          iptables ipt, "-D #{parent} -j #{chain}"
        end
        iptables ipt, "-F #{chain}"
        iptables ipt, "-X #{chain}"
      end
      iptables ipt, "-N #{chain}"
      if parent
        iptables ipt, "-I #{parent} -j #{chain}"
      end
    end

    def captive_setup()
      log 'Setting up'

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

      captive_clear

      ips_connected.each { |ip|
        captive_ip_accept ip
      }

      if @restricted
        captive_restriction_set @restricted
      end
    end

    def captive_block(ip)
      log "Blocking #{ip}"
    end

    def captive_rest_addr(cmd)
      %w( 10.1.0.0/24 10.0.0.0/24 10.1.10.0/21 10.2.10.0/21 ).each { |net|
        captive_ip_drop cmd, net
      }
      if cmd == '-I'
        captive_ip_accept '10.9.0.0/16'
        captive_ip_accept '10.1.14.0/24'
      else
        captive_ip_deny '10.9.0.0/16'
        captive_ip_deny '10.1.14.0/24'
      end
    end

    def captive_rest_add(net = nil)
      captive_rest_addr '-I'
      if net
        captive_ip_accept net
      end
    end

    def captive_rest_del(net = nil)
      captive_rest_addr '-D'
      if net
        captive_ip_deny net
      end
    end

    def captive_rest_txt_ip(name)
      case name
        when /info1/
          '10.1.11.0/24'
        when /info2/
          '10.1.12.0/24'
        else
          ''
      end
    end

    def captive_restriction_set(rest = nil)
      @restricted and captive_rest_del @restricted
      case rest
        when /info1/, /info2/
          captive_rest_add(captive_rest_txt_ip rest)
          @restricted = rest
        else
          @restricted = nil
      end
    end

    def users_connected
      @users_connected.collect { |u, ip| u }
    end

    def ips_connected
      @users.connected.collect { |u, ip| ip }
    end

    def user_connect(ip, name)
      Connection.start

      if @users_connected.has_key? name
        log "User #{name} already connected"
        return unless @allow_double
      end

      same_ip = @users_connected.key ip
      log "Connecting user #{name} - #{ip}"
      @users_connected[name] = ip
      captive_ip_accept ip

      same_ip and user_disconnect(same_ip, ip)
    end

    def user_disconnect_name(name)
      return unless ip = @users_connected[name]
      user_disconnect(name, ip)
    end

    def user_disconnect_ip(ip)
      return unless name = @users_connected.key(ip)
      user_disconnect(name, ip)
    end

    def users_disconnect_all
      @users_connected.dup.each { |name, ip|
        user_disconnect name, ip
      }
    end

    def user_disconnect(name, ip)
      log "user_disconnect #{name}:#{ip}"

      return unless ip = @users_connected.has_key?(name)
      @users_disconnect.delete name
      captive_ip_deny ip

      @users_connected.length == 0 and isp_may_disconnect
    end
  end
end