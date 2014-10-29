DEBUG_LVL = 3
require 'network'
require 'drb/drb'

DRb.start_service

handler = DRbObject.new_with_uri('druby://localhost:9000')
#puts handler.add( {} )
