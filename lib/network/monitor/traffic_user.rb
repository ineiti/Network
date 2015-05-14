require 'helper_classes/dputs'
require 'json'

module Network
  module Monitor
    module Traffic
      # Holds all traffic for different hosts / nets / vlans
      # The traffic is seperated into seconds/mins/.../years
      # Every seperation holds the total during that time-period.
      # Only the year-period is used modulo 10
      class User
        include HelperClasses::DPuts

        attr_reader :traffic

        def initialize(traffic = {}, last_update = Time.now)
          @traffic = traffic
          @last_update = last_update
        end

        # Add a new +host+ to the table and set all values to 0. The
        # +traffic+ is an array of absolute values [rx, tx]. It holds
        # the last interval and the current one, concatenated, so that
        # one can easily extract up to the next intervals duration in
        # the past.
        #
        # For debugging purposes you can give the +time+
        def traffic_init(host, traffic, time = Time.now)
          dputs(3) { "Initialising #{host}" }
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

        # Updates the host +h+ with +traffic+ at time +time+. The
        # +traffic+ is an array of absolute, increasing [rx, tx]-bytes
        def update_host(h, traffic, time = Time.now)
          #dputs_func
          host = h.to_sym
          traffic_host = @traffic[host] || traffic_init(host, traffic, time)
          last_time = @traffic[host]._last_time
          dputs(3) { "*** Updating #{host} at time #{time} from #{last_time}" }
          advanced = 0
          if !traffic_host._last_traffic ||
              traffic_host._last_traffic.inject(:+) > traffic.inject(:+)
            traffic_host._last_traffic = [0, 0]
          end
          %i(sec min hour day month year).zip([0, 0, 0, 1, 1, 0]).reverse.
              each { |t, first|
            index, last_index = time.send(t) - first, last_time.send(t) - first
            if t == :year
              index, last_index = index % 10, last_index % 10
            end
            th = traffic_host[t]
            len = th.length / 2
            offset = if t == :day
                       31 - Date.new(time.year, time.month).prev_month.
                           to_time.end_of_month.day
                     else
                       0
                     end
            if advanced == 0
              advanced = (index + len - last_index - offset) % len
            elsif advanced == 1
              th[offset...len] = th[len..-1-offset]
              th[len..-1] = Array.new(len) { [0, 0] }
              advanced = 2 if index > 0
            elsif advanced >= 2
              th = Array.new(2 * len) { [0, 0] }
            end
            dputs(3) { "#{t}: #{advanced} - #{traffic} - #{traffic_host._last_traffic}" }
            rxtx = traffic.zip(traffic_host._last_traffic).
                collect { |a, b| a.to_i - b.to_i }
            th[len+index] = th[len+index].zip(rxtx).collect { |a, b| a + b }
            dputs(3) { "#{len} - #{index} - #{rxtx} - #{th[len+index]}" }
            traffic_host[t] = th
          }
          traffic_host._last_time = time
          traffic_host._last_traffic = traffic
          if host == :ineiti
            str = "#{traffic_host._last_time.strftime('%a %y.%m.%d-%H:%M:%S')} - "+
                "#{traffic_host._last_traffic}\n" +
                (Internet.operator ? "#{Internet.operator.internet_left}" : '::') +
                " - #{traffic_host._day[31..-1]}\n"
            IO.write('/var/tmp/traffic.ineiti', str, mode: 'a')
          end
        end

        # Updates the counters for all hosts. For debugging purposes
        # you can pass +new_values+
        def update(new_values = nil)
          #dputs_func
          if !new_values
            new_values = Traffic.measure_hosts
          end
          dputs(3) { "New values: #{new_values}" }
          new_values.each { |h, t|
            host = h.to_sym
            dputs(3) { "Host #{host} has #{t} traffic" }
            update_host host, t
          }
          (@traffic.collect { |h, t| h } - new_values.collect { |h, t| h }).each { |h|
            dputs(3) { "Updating #{h} with 0 traffic" }
            update_host h.to_sym, [0, 0]
          }
          dputs(3) { @traffic.inspect }
        end

        # General get-range function
        # +interval+:: sec, min, ..., year
        # +size+:: the size of the interval
        # +h+:: the host you're interested
        # +s+:: where to start
        # +range+:: how many elements
        # +first_index+:: where the index starts
        #
        # If range is negative, it starts that many elements before. Don't
        # ask more elements than "size" in advance, as they might not be there.
        def get_range(interval, size, h, s, range, first_index = 0)
          host = h.to_sym
          return [0, 0] * range.abs unless t = @traffic[host]
          start = s.send(interval.to_sym) - first_index
          if range < 0
            return t[interval.to_sym][size + start + range + 1..size + start]
          else
            return t[interval.to_sym][size + start...size + start + range]
          end
        end

        # Gets the second-+range+ of host +h+, see #get_range
        def get_sec(h, range = -60, time = Time.now)
          get_range(:sec, 60, h, time, range)
        end

        # Gets the minute-+range+ of host +h+, see #get_range
        def get_min(h, range = -60, time = Time.now)
          get_range(:min, 60, h, time, range)
        end

        # Gets the hour-+range+ of host +h+, see #get_range
        def get_hour(h, range = -24, time = Time.now)
          get_range(:hour, 24, h, time, range)
        end

        # Gets the day-+range+ of host +h+, see #get_range
        def get_day(h, range = -31, time = Time.now)
          get_range(:day, 31, h, time, range, 1)
        end

        # Serialize internal data
        def save_json
          {traffic: @traffic,
           last_update: @last_update}.to_json
        end

        # Take on where we left
        def self.from_json(str)
          n = JSON.parse(str).to_sym
          n._traffic = n._traffic.collect { |h, tr|
            [h, tr.collect { |k, v|
                [k, k == :last_time ? Time.parse(v) : v]
              }.to_h]
          }.to_h
          User.new(n._traffic, Time.parse(n._last_update))
        end
      end
    end
  end
end
