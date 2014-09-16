module Network
  module Captive
# Iptable-rules:
# filter:FCAPTIVE - should be called at the end of the filter:FORWARD-table
#   allows new users and finishes with a BLOCK
# nat:CAPTIVE - should be called at the end of the nat:PREROUTING-table
#   redirects all paying users to the nat:INTERNET rule, before DNATting them
#   to the localhost
# nat:INTERNET - redirects to the proxy or direct
#   internet-access

    IPS_IDLE=$RUN/ips_idle
    MAC_LIST=$LOG/allowed_macs
    IP_LIST=$LOG/allowed_ips
    RESTRICTED=$RUN/restricted
    touch $MAC_LIST $IP_LIST $IPS_IDLE $RESTRICTED

    def iptables(cmds)
      %x[ iptables #{ cmds } ]
    end

    IPNAT="iptables -t nat"
    def ipnat(cmds)
      iptables "-t nat #{cmds}"
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
      if ["$1"]; then
        grep -q $1 $IP_LIST
      end
    end

    def captive_ip_add()
      if !captive_ip_check $1; then
        echo $1 >> $IP_LIST
        captive_ip_accept $1
      end
    end

    def captive_ip_del()
      grep -v $1 $IP_LIST > /tmp/i ps
      mv /tmp/i ps $IP_LIST
      captive_ip_deny $1
    end

    def captive_mac_accept()
      if !iptables -L
        FCAPTIVE -n | grep -qi $1; then
        MAC_IPT="-m mac --mac-source $1"
        iptables -I FCAPTIVE $MAC_IPT -j ACCEPT
        $IPNAT -I CAPTIVE $MAC_IPT -j INTERNET
      end
    end

    def captive_mac_deny()
      if iptables -L
        FCAPTIVE -n | grep -qi $1; then
        MAC_IPT="-m mac --mac-source $1"
        iptables -D FCAPTIVE $MAC_IPT -j ACCEPT
        $IPNAT -D CAPTIVE $MAC_IPT -j INTERNET
      end
    end

    def captive_mac_check()
      if ["$1"]; then
        grep -q $1 $MAC_LIST
      end
    end

    def captive_mac_add()
      if !captive_mac_check $1; then
        echo $1 >> $MAC_LIST
        captive_mac_accept $1
      end
    end

    def captive_mac_del()
      grep -v $1 $MAC_LIST > /tmp/m acs
      mv /tmp/m acs $MAC_LIST
      captive_mac_deny $1
    end

    def captive_clear()
      local ip
      loga Clearing IPs and refreshing MACs
      $IPNAT -F CAPTIVE
      iptables -F FCAPTIVE

      ALLOW_DHCP= $ {ALLOW_DHCP: -255.255 .255 .255}
      INTERNAL_IPS= $ {INTERNAL_IPS: - $ (ip addr | grep "inet " | sed -e "s/.*inet \([^\/ ]*\).*/\1/" | grep -v 127.0 .0 .1)}
      log Internal is $INTERNAL_IPS
      for ip in $ALLOW_DHCP
        $INTERNAL_IPS $ALLOW_DST; do
        log Allowing requests to $ip to go through
        $IPNAT -A NOCAPTIVE -d $ip -j ACCEPT
        iptables -A FCAPTIVE -d $ip -j ACCEPT
      end

      for ip in $ALLOW_SRC_DIRECT;
        do
        log Allowing requests from $ip to go through
        $IPNAT -A NOCAPTIVE -s $ip -j ACCEPT
        $IPNAT -A NOCAPTIVE -d $ip -j ACCEPT
        iptables -A FCAPTIVE -s $ip -j ACCEPT
        iptables -A FCAPTIVE -d $ip -j ACCEPT
      end

      FIRST_INTERNAL= $ (echo $INTERNAL_IPS | sed -e "s/ .*//")
      if ["$CAPTIVE_DNAT"]; then
        echo CAPTIVE IS $CAPTIVE_DNAT
        $IPNAT -I CAPTIVE -j DNAT --to-dest ${CAPTIVE_DNAT : -$FIRST_INTERNAL}
      end

      for ip in
        $ (cat $IP_LIST); do
        captive_ip_accept $ip
      end
      local mac
      for mac in
        $ (cat $MAC_LIST); do
        captive_mac_accept $mac
      end

      for ip in $ALLOW_SRC_PROXY;
        do
        log Allowing requests from $ip to go through Proxy
        $IPNAT -A NOCAPTIVE -s $ip -j INTERNET
        $IPNAT -A NOCAPTIVE -d $ip -j INTERNET
        iptables -A FCAPTIVE -s $ip -j ACCEPT
        iptables -A FCAPTIVE -d $ip -j ACCEPT
      end

      iptables -A FCAPTIVE -j RETURN
    end

    def captive_accept_all()
      captive_clear
      iptables -A FCAPTIVE -j ACCEPT
      $IPNAT -I CAPTIVE -j INTERNET
    end

    def captive_packets_count()
      TOT=0
      local a
      for a in
        $ (iptables -L FCAPTIVE -nv | grep $1 | head -n 1 |
            sed -e "s/ *\([^ ]*\).*/\1/"); do
        TOT= $ ((TOT + a))
      end
      echo $TOT
    end

# This can be called from time to time to check on idle people
    def captive_cleanup()
      users_check_connected
      local CS= $ (isp_connection_status)
      local ip
      if ["$CS"
        = 0]; then
        if ["$( ips_connected )"]; then
          if ["$CONNECTION_TYPE" != "permanent"]; then
            log "Disconnecting everybody as we're not connected"
            users_disconnect_all
          else
            log "Keeping users while we hope for a return of the connection"
          end
        end
        return
        elif ["$CS" -lt 4]; then
        log not really connected
        return
      end
      if ["$( ips_connected )"]; then
        for ip in
          $ (ips_connected); do
          PACKETS= $ (captive_packets_count $ip)
          log Checking ip $ip - has $PACKETS packets
          if [!"$PACKETS"]; then
            loga Still in $USERS_CONNECTED, but not in iptables
            users_connected_delete $ip
            remove_line "^$ip\$" $IPS_IDLE
            elif ["$PACKETS" = 0]; then
            if egrep -q
              "^$ip\$" $IPS_IDLE; then
              loga No packets, kicking $ip
              user_disconnect_ip $ip
              remove_line "^$ip\$" $IPS_IDLE
              loga Lines_idle is now $IPS_IDLE
            else
              loga $ip is idle, adding to list
              echo $ip >> $IPS_IDLE
            end
          else
            remove_line "^$ip\$" $IPS_IDLE
          end
        end
        elif ["$CONNECTION_TYPE" = "ondemand"]; then
        isp_connection_stop
      end
#  log Clearing counters
      iptables -Z FCAPTIVE
      #  cp $USERS_CONNECTED $USERS_CONNECTED.tmp
    end

    def delete_chain()
      PARENT="$1"
      CHAIN="$2"
      IPT="iptables"
      if ["$3"]; then
        IPT="$IPT -t $3"
      end
      if $IPT -L
        $PARENT -n | grep -q $CHAIN; then
        if ["$PARENT"]; then
          $IPT -D $PARENT -j $CHAIN
        end
        $IPT -F $CHAIN
        $IPT -X $CHAIN
      end
      $IPT -N $CHAIN
      if ["$PARENT"]; then
        $IPT -I $PARENT -j $CHAIN
      end
    end

    def captive_setup()
      log Setting up
      PREROUTING= $ {PREROUTING: -PREROUTING}
      delete_chain $PREROUTING CAPTIVE nat

      delete_chain $PREROUTING NOCAPTIVE nat

      delete_chain "" INTERNET nat
      if ["$HTTP_PROXY"]; then
        $IPNAT -A INTERNET -p tcp --dport 80 -j DNAT --to-dest $HTTP_PROXY
      end
      $IPNAT -A INTERNET -j ACCEPT

      delete_chain FORWARD FCAPTIVE
      #iptables -I FCAPTIVE -j RETURN
      if ["$ALLOW_FREE" != "all"]; then
        iptables -P FORWARD DROP
      end

      captive_clear

      local ip
      for ip in
        $ (ips_connected); do
        captive_ip_accept $ip
      end

      if ["$( captive_restriction_get )"]; then
        captive_restriction_set $(captive_restriction_get)
      end
    end

    def captive_block()
      log Blocking $1
    end

    def captive_rest_addr()
      local ip
      for ip in 10.1
        .0 .0/24 10.0 .0 .0/24 10.1 .10 .0/21 10.2 .10 .0/21; do
        captive_ip_drop $1 $ip
      end
      if ["$1"
        = "-I"]; then
        captive_ip_accept 10.9 .0 .0/16
        captive_ip_accept 10.1 .14 .0/24
      else
        captive_ip_deny 10.9 .0 .0/16
        captive_ip_deny 10.1 .14 .0/24
      end
    end

    def captive_rest_add()
      captive_rest_addr -I
      if ["$1"]; then
        captive_ip_accept $1
      end
    end

    def captive_rest_del()
      captive_rest_addr -D
      if ["$1"]; then
        captive_ip_deny $1
      end
    end

    def captive_rest_txt_ip()
      case "$1" in
      info1)
      echo 10.1 .11 .0/24
      ;;
      info2)
      echo 10.1 .12 .0/24
      ;;
      *)
      echo ""
      ;;
      esac
    end

    def captive_restriction_set()
      log restricting -$REST- in file -$RESTRICTED-
                                          OLDREST=$ (captive_restriction_get)
      if ["$OLDREST"]; then
        captive_rest_del $(captive_rest_txt_ip $OLDREST)
      end
      REST=$1
      case $REST in
      info1|info2)
      captive_rest_add $(captive_rest_txt_ip $REST)
      ;;
      *)
      REST=""
      esac
      echo -n $REST > $RESTRICTED
    end

    def captive_restriction_get()
      log Restriction get $(cat $RESTRICTED)
      cat $RESTRICTED
    end

  end
end