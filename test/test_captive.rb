DEBUG_LVL=2
require 'network'
include Network

Captive.internal_ips = %w( 192.168.37.1 )
Captive.setup
sleep 3
#Operator.chose('Direct')
#sleep 2


Captive.restriction_set('info1')
puts Captive.iptables '-L -nv'
puts

Captive.restriction_set()
puts Captive.iptables '-L -nv'
puts

Captive.restriction_set('info1')
puts Captive.iptables '-L -nv'
puts

exit

Captive.user_connect 'ineiti', '192.168.10.146'
puts Captive.users_connected.inspect
puts Captive.iptables '-L -nv'
sleep 2
Captive.user_disconnect 'ineiti'
puts Captive.users_connected.inspect
puts Captive.iptables '-L -nv'
sleep 2
Captive.user_connect 'ineiti', '192.168.10.146'
puts Captive.users_connected.inspect
puts Captive.iptables '-L -nv'
sleep 2

exit


Captive.cleanup
sleep 1
15.times{Captive.cleanup}
#exit
#Captive.user_disconnect_name :ineiti
puts Captive.users_connected.inspect
