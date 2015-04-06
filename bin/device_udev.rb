#!/usr/bin/env ruby
require 'drb/drb'

exit unless dev = DRbObject.new_with_uri('druby://localhost:9000')

Kernel.system("echo device_udev: #{ARGV.inspect} >> /tmp/dudev")

case ARGV.first
  when /add/
    Kernel.system('echo adding >> /tmp/dudev')
    dev.add_udev(*ARGV[1..2])
  when /del/
    Kernel.system('echo deleting >> /tmp/dudev')
    dev.del_udev(*ARGV[1..2])
end
