#!/usr/bin/env ruby
require 'drb/drb'

exit unless dev = DRbObject.new_with_uri 'druby://localhost:9000'

Kernel.system("echo #{ARGV.inspect} >> /tmp/dudev")

case ARGV.first
  when /add/
    dev.add_udev(*ARGV[1..2])
  when /del/
    dev.del_udev(*ARGV[1..2])
end
