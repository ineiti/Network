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
        attr_reader :traffic
        # You can give a starting-hash of the number of bytes
        # Default interval is:
        #   15s - 1m - 30m - 24h - 30d - 12months
        def initialize(ips = nil, intervals: [15, 4, 30, 48, 30, 12])
          @intervals = intervals
          #@traffic = @invervals.collect{|i| Array.new(2*i){0}}
          @traffic = Traffic.hosts.collect { |h| [h.to_sym, [[0, 0]]*2] }.to_h
          @last_update = Time.now
        end

        # Updates the counters, both _diff_ and _total_
        def update(new_values = nil)
          if !new_values
            dp new_values = Traffic.measure_hosts
            #dp 'not implemented yet'
            #return false
          end
          Traffic.hosts.collect { |h|
            host = h.to_sym
            @traffic[host] ||= [[0, 0]] * 2
            dp @traffic.inspect
            dp host
            old = @traffic[host].unshift(new_values[host]).pop
          }
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
