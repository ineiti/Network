DEBUG_LVL=2
require 'network'
include Network

Captive.setup
sleep 3
#Operator.chose('Direct')
#sleep 2

Captive.user_connect '192.168.10.146', 'ineiti'
puts Captive.users_connected.inspect
sleep 5
Captive.cleanup
sleep 1
15.times{Captive.cleanup}
#exit
#Captive.user_disconnect_name :ineiti
puts Captive.users_connected.inspect
