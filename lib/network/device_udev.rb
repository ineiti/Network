#!/usr/bin/env ruby
require 'drb/drb'

dev = DRbObject.new_with_uri 'druby://localhost:9000'

Kernel.system("echo #{ARGV.inspect} >> /tmp/dudev")

case ARGV.first
  when /add/
    dev.add_udev(ARGV.last)
  when /del/
    dev.del_udev(ARGV.last)
end
