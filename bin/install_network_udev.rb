#!/usr/bin/env ruby

LOAD_PATH.push File.expand_path("../lib", __FILE__)
require 'network/device'

Network::Device.install_system

puts 'Udev-handler successfully installed on system'