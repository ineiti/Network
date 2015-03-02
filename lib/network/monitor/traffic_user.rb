require 'helperclasses/dputs'

module Network
  module Monitor
    module Traffic
      # This class holds data for all ip/vlans that are listed. For each listener,
      # one class can be instantiated, so multiple listeners can poll the data at
      # the interval of their wish
      #
      # 1) only implement diff and total
      # 2) add intervals
      # 3) serialize
      class User
        include HelperClasses::DPuts

        attr_reader :traffic

        def initialize
          #@traffic = @invervals.collect{|i| Array.new(2*i){0}}
          @traffic = {}
          @last_update = Time.now
        end

        def traffic_init(host, traffic, time = Time.now)
          ddputs(3) { "Initialising #{host}" }
          @traffic[host.to_sym] = {
              sec: Array.new(60*2) { [0, 0] },
              min: Array.new(60*2) { [0, 0] },
              hour: Array.new(24*2) { [0, 0] },
              day: Array.new(31*2) { [0, 0] },
              month: Array.new(12*2) { [0, 0] },
              year: Array.new(10*2) { [0, 0] },
              last_time: time,
              last_traffic: traffic
          }
        end

        def update_host(h, traffic, time = Time.now)
          dputs_func
          host = h.to_sym
          traffic_host = @traffic[host] || traffic_init(host, traffic, time)
          last_time = @traffic[host]._last_time
          dputs(3) { "*** Updating at time #{time} from #{last_time}" }
          advanced = 0
          %i(sec min hour day month year).zip([0, 0, 0, 1, 1, 0]).reverse.
              each { |t, first|
            index, last_index = time.send(t) - first, last_time.send(t) - first
            if t == :year
              index, last_index = index % 10, last_index % 10
            end
            th = traffic_host[t]
            len = th.length / 2
            if advanced == 0
              advanced = (index + len - last_index) % len unless advanced > 0
            elsif advanced == 1
              th[0...len] = th[len..-1]
              th[len..-1  ] = Array.new(len) { [0, 0] }
              advanced = 2 if index > 0
            elsif advanced >= 2
              th = Array.new(2 * len) { [0, 0] }
            end
            dp "#{t}: #{advanced} - #{traffic} - #{traffic_host._last_traffic}"
            rxtx = traffic.zip(traffic_host._last_traffic).collect { |a, b| a - b }
            th[len+index] = th[len+index].zip(rxtx).collect { |a, b| a + b }
            dp "#{len} - #{index} - #{rxtx} - #{th[len+index]}"
            traffic_host[t] = th
          }
          traffic_host._last_time = time
          traffic_host._last_traffic = traffic
        end

        # Updates the counters, both _diff_ and _total_
        def update(new_values = nil)
          dputs_func
          if !new_values
            new_values = Traffic.measure_hosts
          end
          dputs(3) { "New values: #{new_values}" }
          Traffic.hosts.collect { |h|
            dp host = h.to_sym
            old = @traffic[host][0].unshift(new_values[host]).pop
          }
          dputs(3) { @traffic.inspect }
        end

        # Returns the total of rx/tx-bytes
        def total(name)
          (t = @traffic[name.to_sym]) ? t[0].inject(:+) : 0
        end

        # Returns the diff to last 'update' rx/tx-bytes
        def diff(name)
          (t = @traffic[name.to_sym]) ? t[0].inject(:+) - t[1].inject(:+) : 0
        end

        # Returns rx/tx-bytes of _ip_ for the last _sec_onds
        def time(name, sec)

        end

        # Serialize internal data
        def to_json

        end

        # Take on where we left
        def self.from_json

        end

      end
    end
  end
end
