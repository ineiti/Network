require 'network'
#require 'modem'

modem = Network::Modem.present or ( puts "no modem"; exit )

p modem.sms_list
