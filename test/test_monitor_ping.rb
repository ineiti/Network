DEBUG_LVL=2
require 'network'
require 'FileUtils'
include Network

def main
  CheckHosts.html_dir = 'images'
  FileUtils.mkdir_p 'images'
  test_bars
end

def test_links
  CheckHosts.log_file = 'log/check_hosts.log'
  p CheckHosts.make_links(0)
  p CheckHosts.make_links(2)
  p CheckHosts.make_links(4)
end

def test_bars
  CheckHosts.host_names = {ns1:'College', ns2:'Colline'}
  CheckHosts.log_file = 'log/check_hosts.log'
  #ll = CheckHosts.list_logs
  #CheckHosts.graph_day(ll.last, 4)
  CheckHosts.graph_html(0)
end

def test_ping
  CheckHosts.host_names = {met: 'Router', dp: 'Dreamplug', dp2: 'Unknown'}
  FileUtils.rm_f CheckHosts.log_file = 'log/check_test.log'
  CheckHosts.ping_hosts
  p IO.readlines(CheckHosts.log_file)
end

main