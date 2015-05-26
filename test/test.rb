#!/usr/bin/env ruby
require 'bundler/setup'
require 'test/unit'
require 'fileutils'

DEBUG_LVL=0

require 'network'

tests = Dir.glob('net_*.rb')
tests = %w( operator_tigo )

$LOAD_PATH.push '.'
tests.each { |t|
  begin
    require "net_#{t}"
  rescue LoadError => e
    require t
  end
}
