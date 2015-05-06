#!/usr/bin/env ruby

DEBUG_LVL=0

%w(../../lib ../../../HelperClasses/lib).each{|path|
  $LOAD_PATH.push File.expand_path(path, __FILE__)
}
require 'network/device'

Network::Device.install_system

puts 'Udev-handler successfully installed on system'