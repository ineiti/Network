require 'helperclasses'

module Network
  module Monitor
    module Connection
      attr_accessor :checks
      extend self

      @checks = %w(ppp default host ping httping openvpn )
      @vpn_config = Dir.glob('/etc/openvpn/*.conf').first
      @error_action = :restart
      @host = 'google.com'
      @count_failed = 0
      @count_max = 5
      @state = :unsure

      # Any of :ok, :unsure, :failed
      def new_state(s)
        if s != @state
          @state = s
        end
      end

      def check
        network_dev = ''
        netctl_dev = ''
        @checks.each { |c|
          res = case c
                  when /ppp/
                    IO.read('/proc/net/dev') =~ /^\s*#{network_dev}:/
                  when /default/
                    System.run_str('/usr/bin/route -n') =~ /^0\.0\.0\.0/
                  when /host/
                    System.run_bool("/usr/bin/host #{@host}")
                  when /ping/
                    System.run_bool("/usr/bin/ping -w 10 -c 3 #{@host}")
                  when /httping/
                    System.run_bool("/usr/bin/httping -t 10 -c 2 #{@host}")
                  when /openvpn/
                    IO.read('/proc/net/dev') =~ /^\s*tun0:/
                  else
                    dputs(1) { "Don't know about check #{c}" }
                    true
                end
          if res
            dputs(3) { "Check #{c} returns true" }
          else
            dputs(2) { "Check #{c} failed" }
            if @count_failed += 1 >= @count_max
              failed(c)
            end
            break
          end
        }
      end

      def is_broken

      end
    end
  end
end