#!/usr/bin/env ruby
require 'helperclasses'

module Network
  module Monitor
    module Traffic
      extend self
      include HelperClasses

      class Array
        def to_i
          collect { |v| v.to_i }
        end
      end

      class String
        def splitn
          split("\n")
        end
      end

      def setup_config(file = 'grapher.conf.rb', arg = nil)
        @config = ReadConfig.ruby(arg || ReadConfig.file_name(file))

        @vlans = @config._vlans || []
        @hosts = @config._hosts || []
        @bw = @config._bw
        @db = @config._db
        @table = 'mangle'
        @old_values=[0] * ((@bw ? 3 : 0) + @vlans.length + @hosts.length)
      end

      def create_rrb
        bw_int = @bw ? {bw_min: 'GAUGE',
                        bw_max: 'GAUGE',
                        total: 'COUNTER'}.collect { |label, type|
          "DS : #{label} : #{type} : 20 : 0 : #{@config._bw_internet}"
        }.join(' ') : ''

        counters = @vlans.collect { |v|
          "DS:vlan#{v}:COUNTER:20:0:#{@config._bw_upper}"
        }.concat(
            @hosts.collect { |h|
              "DS:host#{h}:COUNTER:20:0:#{@config._bw_upper}"
            }).join(' ')

        ranges = [[1, 600], [6, 1440], [60, 1728]].each { |step, len|
          %w( AVERAGE MIN MAX ).collect { |label|
            "RRA : #{label} : 0.5 : #{step} : #{len} "
          }.join(' ')
        }.join(' ')

        File.exists?(@db) and FileUtils.rm_f(@db)
        System.run_bool("rrdtool create #{@db} --step 10 #{bw_int} #{counters} #{ranges}")
      end

      def ld(*args)
        puts args.join(' ')
      end

      def color(nbr)
        c = @config._colors[nbr] || '0ff'
        c.scan(/./).collect { |c| c+c }.join
      end

      def graph_traffic
        bw_defs, bw_cdefs, bw_lines = '', '', ''
        if @bw
          bw_defs="DEF:bw_min=#{@db}:bw_min:MIN
           DEF:bw_max=#{@db}:bw_max:MAX
           DEF:internet=#{@db}:total:AVERAGE "
          bw_cdefs='CDEF:bbw_min=bw_min,8,*
            CDEF:bbw_max=bw_max,8,*
            CDEF:binternet=internet,8,* '
          bw_lines='LINE2:bbw_min#FFCCDD:bw_min LINE2:bbw_max#66CC66:bw_max
            LINE2:binternet#AAAAFF:internet'
        end

        defs, cdefs, lines = '', '', ''
        @vlans.split.each { |v|
          defs += " DEF:vlan#{v}=#{@db}:vlan#{v}:AVERAGE"
          cdefs += " CDEF:bvlan#{v}=vlan#{v},8,*"
          col = color(v)
          lines += " AREA:bvlan#{v}##{col}:#{@config._names_vlans[v]}:STACK"
        }
        @hosts.split.each { |h|
          defs += " DEF:host#{h}=#{@db}:host#{h}:AVERAGE"
          cdefs += " CDEF:bhost#{h}=host#{h},8,*"
          col = color(v)
          lines +=" AREA:bhost#{h}##{col}:#{@config._names_hosts[h]}:STACK"
        }

        Dir.mktmpdir { |d|
          [['vlans-hour.png', -1800, 10],
           ['vlans-halfday.png', -43200, 240],
           ['vlans-week.png', 86400 * 7, 3600]].each { |png, start, step|
            file = "#{d}/tmp"
            args = "graph -u #{@config._bw_upper} #{file} --start #{start} --step #{step} "
            args += "-a PNG -t 'Traffic to internet' --vertical-label 'bps' -w 800 -h 200 -r"
            args += [bw_defs, defs, bw_cdefs, cdefs].join(' ')
            args += "LINE1 : 0 #{lines} #{bw_lines}"
            System.run_bool("rrdtool #{args}")
            File.chmod(0444, file)
            File.mv file, png
          }
        }
      end

      def measure
        #values = %x[ iptables -t #{table} -L POST_COUNT -nvx | grep -v 172.16.0.1 ].splitn
        values = %x[ iptables -t #{table} -L POST_COUNT -nvx ].splitn
        ld values.join("\n")
        data = []
        if @bw
          bws = %x[ tail -n 2 /var/log/check-bandwidth.log | sed -e 's/.* //' ].splitn.to_i
          ld bws.inspect
          data.push(bws.min, bws.max)
          internet = %x[ grep #{@config._internet_dev} /proc/net/dev | sed -e "s/.*://" ].split
          ld internet.inspect
          data.push internet[0].to_i
        end

        @vlans.each { |v|
          bytes = values.select { |val| val =~ / vlan#{v} / }.map { |val|
            val.split[1] }.to_i
          ld v, bytes.inspect
          data.push bytes[1]
        }
        @hosts.each { |h|
          bytes = values.select { |val| val =~ / #{@config._host_ips[h]} / }.map { |val|
            val.split[1] }.to_i
          ld h, bytes.inspect
          data.push bytes[1]
        }
        ld data.inspect

        ld "Updating #{Time.now}"
        ld data.join(':')
        ld @vlans.join(':')
        ld @hosts.join(':')
        labels = @bw ? 'bw_min:bw_max:total:' : ''
        labels += (@vlans + @hosts).join(':')
        system("rrdtool update #{@db} -t #{labels} N:#{data.join(':')}")
        graph_traffic
        total = 0
        puts (vals = @old_values.zip(data)[3..-1].collect { |a, b| (b - a) * 8 / 10 }).join(':')
        puts vals.inject(:+)
        @old_values = data
        sleep 10
      end

      def ipt(*args)
        System.run_bool("iptables -t #{@table} #{args.join(' ')}")
      end

      def create_iptables
        @table='mangle'

        [%w( PRE -i -d ),
         %w( POST -o -s )].each { |prefix, dir, target|
          mangle="#{prefix}ROUTING"
          count="#{prefix}_COUNT"
          # Cleaning up
          if ipt('-L', 'mangle') =~ /count/
            ld 'Cleaning up'
            ipt '-D', mangle, '-j', count
            ipt '-F', count
            ipt '-X', count
          end

          ld 'Creating new chain'
          ipt '-N', count
          ipt '-I', mangle, '-j', count

          @vlans.each { |v|
            ipt '-A', count, dir, v, target, '172.16.0.1 -j RETURN'
            ipt '-A', count, dir, v, '-j RETURN'
          }
          @hosts.each { |h|
            ipt '-A', count, target, "#{config._hosts_ips[h]} -j RETURN"
          }
        }
      end
    end
  end
end
