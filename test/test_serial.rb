DEBUG_LVL=5

require 'network'
require 'helperclasses'

Network::Modem.present? or ( puts "no modem"; exit )

