#!/usr/bin/env ruby
require 'helperclasses'
require 'fileutils'
require 'tmpdir'
require_relative 'traffic_user'

module Network
  module Monitor
    module Traffic
      attr_accessor :config, :vlans, :hosts, :bw, :db, :table, :thread,
                    :imgs_dir
      extend self
      include HelperClasses
      extend DPuts

      def setup_config(conf = {}, arg = nil)
        case conf.class.name
          when /String/
            @config = ReadConfig.ruby(arg || ReadConfig.file_name(file))
          when /Hash/
            @config = conf.dup
          else
            Raise 'Config not found'
        end

        @vlans = @config._vlans || []
        @hosts = @config._hosts || []
        @host_ips = config._host_ips || {}
        @bw = @config._bw || false
        @db = @config._db || 'traffic.rrd'
        @config._bw_upper ||= 1_000_000
        @table = @config._table || 'mangle'
        @table_count = @config._table_count || 'COUNT'
        @old_values=[0] * ((@bw ? 3 : 0) + @vlans.length + @hosts.length)
        @imgs_dir = @config._imgs_dir || '/srv/http/traffic'
        @thread
      end

      def create_rrb(replace = true)
        return if (File.exists?(@db) and !replace)
        bw_int = @bw ? {bw_min: 'GAUGE',
                        bw_max: 'GAUGE',
                        total: 'COUNTER'}.collect { |label, type|
          "DS:#{label}:#{type}:60:0:#{@config._bw_internet}"
        }.join(' ') : ''

        counters = @vlans.collect { |v|
          "DS:vlan#{v}:COUNTER:60:0:#{@config._bw_upper}"
        }.concat(
            @hosts.collect { |h|
              "DS:host#{h}:COUNTER:60:0:#{@config._bw_upper}"
            }).join(' ')

        ranges = [[1, 600], [6, 1440], [60, 1728]].collect { |step, len|
          %w( AVERAGE MIN MAX ).collect { |label|
            "RRA:#{label}:0.5:#{step}:#{len}"
          }.join(' ')
        }.join(' ')

        File.exists?(@db) and FileUtils.rm_f(@db)
        System.run_str("rrdtool create #{@db} --step 10 #{bw_int} #{counters} #{ranges}")
      end

      def ld(*args)
        dputs(3) { args.join(' ') }
      end

      def color(nbr)
        c = (@config._colors and @config._colors[nbr]) || '0ff'
        c.scan(/./).collect { |c| c+c }.join.upcase
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
        @vlans.each { |v|
          defs += " DEF:vlan#{v}=#{@db}:vlan#{v}:AVERAGE"
          cdefs += " CDEF:bvlan#{v}=vlan#{v},8,*"
          col = color(v)
          lines += " AREA:bvlan#{v}##{col}:#{@config._names_vlans[v]}:STACK"
        }
        @hosts.each { |h|
          defs += " DEF:host#{h}=#{@db}:host#{h}:AVERAGE"
          cdefs += " CDEF:bhost#{h}=host#{h},8,*"
          col = color(h)
          lines +=" AREA:bhost#{h}##{col}:#{@config._name_hosts[h]}:STACK"
        }

        Dir.mktmpdir { |d|
          [['traffic1-hour.png', -1800, 10],
           ['traffic2-halfday.png', -43200, 240],
           ['traffic3-week.png', -86400 * 7, 3600]].each { |png, start, step|
            file = "#{d}/tmp"
            args = "graph -u #{@config._bw_upper} #{file} --start #{start} --step #{step} "
            args += "-a PNG -t 'Traffic to internet' --vertical-label 'bps' -w 600 -h 150 -r "
            args += [bw_defs, defs, bw_cdefs, cdefs].join(' ')
            args += " LINE1:0 #{lines} #{bw_lines}"
            # This is some obscure bug in Archlinux with regard to fonts
            #System.run_str('rm /var/cache/fontconfig/*')
            System.run_str("rrdtool #{args}")
            File.chmod(0444, file)
            FileUtils.mkdir_p @imgs_dir
            FileUtils.mv file, "#{@imgs_dir}/#{png}"
          }
        }
      end

      def iptables(*args)
        if !@ipt_cmd
          if System.exists?('iptables')
            @ipt_cmd = 'iptables'
            @iptables_wait = (System.run_str('iptables --help') =~ / -w /) ? '-w' : ''
          else
            @ipt_cmd = ''
          end
        end

        if @ipt_cmd != ''
          System.run_str(dp "iptables #{@iptables_wait} #{args.join(' ')}")
        else
          return ''
        end
      end

      def ipt(*args)
        iptables("-t #{@table} #{args.join(' ')}")
      end

      def measure_hosts
        values = ipt("-L POST_#{@table_count} -nvx").split("\n")
        @hosts.collect { |h|
          host = h.to_sym
          [host, values.select { |val|
                 val =~ / #{@host_ips[host]} /
               }.map { |val|
                 val.split[1].to_i
               }]
        }.to_h
      end

      def measure
        #values = %x[ iptables -t #{table} -L POST_COUNT -nvx | grep -v 172.16.0.1 ].splitn
        values = ipt("-L POST_#{@table_count} -nvx").split("\n")
        ld values.join("\n")
        data = []
        if @bw
          bws = System.run_str("tail -n 2 /var/log/check-bandwidth.log | sed -e 's/.* //'").split("\n").to_i
          ld bws.inspect
          data.push(bws.min, bws.max)
          internet = System.run_str("grep #{@config._internet_dev} /proc/net/dev | sed -e 's/.*://' ]").split
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
          bytes = values.select { |val|
            val =~ / #{@host_ips[h]} /
          }.map { |val|
            val.split[1] }.collect { |a| a.to_i }
          ld h, bytes.inspect
          data.push bytes[1]
        }

        if @db != ''
          ld "Updating #{Time.now}"
          ld data.join(':')
          ld @vlans.join(':')
          ld @hosts.join(':')
          labels = @bw ? 'bw_min:bw_max:total:' : ''
          labels += (@vlans.collect { |v| "vlan#{v}" } +
              @hosts.collect { |h| "host#{h}" }).join(':')
          System.run_str("rrdtool update #{@db} -t #{labels} N:#{data.join(':')}")
          graph_traffic
        end

        start = @bw ? 3 : 0
        ld (vals = @old_values.zip(data)[start..-1].collect { |a, b|
             (b.to_i - a.to_i) * 8 / 10 }).join(':')
        ld vals.inject(:+)
        @old_values = data
      end

      def run_measure
        @thread = Thread.new {
          loop do
            dputs(2) { "Measuring and graphing at #{Time.now.to_s}" }
            measure
            sleep 20
          end
        }
      end

      def create_iptables
        @table='mangle'

        [%w( PRE -i -d ),
         %w( POST -o -s )].each { |prefix, dir, target|
          target_other = (target == '-d') ? '-s' : '-d'
          mangle="#{prefix}ROUTING"
          count="#{prefix}_#{@table_count}"
          # Cleaning up
          if ipt('-L -n') =~ /#{count}/
            ld 'Cleaning up'
            while ipt("-L #{mangle} -nv") =~ / #{count} /
              ipt '-D', mangle, '-j', count
            end
            ipt '-F', count
            ipt '-X', count
          end

          ld 'Creating new chain'
          ipt '-N', count
          ipt '-I', mangle, '-j', count

          @vlans.each { |v|
            ipt '-A', count, dir, v, target, '192.168.0.0/16 -j RETURN'
            ipt '-A', count, dir, v, '-j RETURN'
          }
          ipt '-A', count, '-s 192.168.0.0/16 -d 192.168.0.0/16 -j RETURN'
          @hosts.each { |h|
            ipt '-A', count, target, @host_ips[h.to_sym]
            ipt '-A', count, target_other, @host_ips[h.to_sym]
          }
        }
      end

      def ip_add(ip, name)
        return if @hosts.index name
        @host_ips[name.to_sym] = ip
        @hosts.push name.to_sym
        [%w( PRE -i -d ),
         %w( POST -o -s )].each { |prefix, dir, target|
          count="#{prefix}_COUNT"
          target_other = (target == '-d') ? '-s' : '-d'
          ipt '-A', count, target, ip
          ipt '-A', count, target_other, ip
        }
      end

      def ip_del(ip)
        return unless name = @host_ips.key(ip)
        [%w( PRE -i -d ),
         %w( POST -o -s )].each { |prefix, dir, target|
          count="#{prefix}_COUNT"
          target_other = (target == '-d') ? '-s' : '-d'
          ipt '-D', count, target, ip
          ipt '-D', count, target_other, ip
        }
        @host_ips.delete(name)
        @hosts.delete name
      end

      # Removes monitoring an IP for a given name
      def ip_del_name(name)
        return unless ip = @host_ips[name.to_sym]
        ip_del(ip)
      end
    end
  end
end
