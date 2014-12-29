require 'chunky_png'
require 'helperclasses'
require 'time'

include HelperClasses

module Network
  module CheckHosts
    attr_accessor :log_file, :bar_size, :active, :inactive, :host_names,
                  :html_dir
    extend self

    @log_file = '/var/log/check_hosts.log'
    @html_dir = '/srv/http'
    @bar_size = {width: 200, height: 20}
    @host_names = {}
    @active = ChunkyPNG::Color.rgb(0x90, 0xee, 0x90)
    @inactive = ChunkyPNG::Color.rgb(0xff, 0, 0)
    @mixed = ChunkyPNG::Color.rgb(0xff, 0xff, 0)
    @html_head = '<title>Graph for Bakhita</title>'
    @html_style = '
      body {
          background-color: #607860;
      }

      .main {
          margin-left: auto;
          margin-right: auto;
          padding: 10px;
          width: 70%;
          background-color: #b0deb0;
      }

      .cent {
          margin-left: auto;
          margin-right: auto;
      }

      .center {
          text-align: center;
      }'

    def list_logs
      Dir.glob("#{@log_file}*").sort_by { |a| a.sub(/.*\./, '').to_i }
    end

    def date_logs
      list_logs.collect { |l|
        d, _h = IO.readlines(l).first.split('::')
        Time.strptime(d, '%Y-%m-%d_%H.%M.%S')
      }
    end

    def read_log(log)
      IO.readlines(log).collect { |l|
        d, h = l.chomp.split('::')
        hosts = h.split(',').collect { |ho|
          name, state = ho.split(':')
          [name.to_sym, state == 'up']
        }.to_h
        begin
          [Time.strptime(d, '%Y-%m-%d_%H.%M.%S'), hosts]
        rescue ArgumentError => e
          nil
        end
      }.compact
    end

    def graph_day(log, hours = 3)
      log_lines = read_log(log)
      colors = [@inactive, @mixed, @active]
      pngs = {}
      states = {}
      @host_names.each_key { |host|
        pngs[host] = ChunkyPNG::Image.new(@bar_size._width, @bar_size._height)
        states[host] = nil
      }
      t_start = 0
      log_lines.each { |t|
        t_end = (t[0].hour * 60 + t[0].min) * @bar_size._width / 1440
        t[1].each { |host, st|
          state = st ? 1 : -1
          #p "Making from #{t_start} to #{t_end} - #{st} with height #{@bar_size._height} for #{host.inspect}"
          states[host] ||= state
          states[host] *= state == states[host] ? 1 : 0
          if t_start != t_end
            color = colors[states[host] + 1]
            pngs[host] and
                 pngs[host].rect(t_start, 0, t_end, @bar_size._height, color, color)
            states[host] = nil
          end
        }
        t_start = t_end
      }

      if hours > 0
        (1..24/hours).each { |h|
          vert = h * hours * @bar_size._width / 24
          log_lines.first[1].each_key { |host|
            pngs[host].rect(vert, 0, vert, @bar_size._height,
                            ChunkyPNG::Color::BLACK, ChunkyPNG::Color::BLACK)
          }
        }
      end

      d = log_lines.first[0]
      @host_names.collect { |host,_v|
        filename = "#{@html_dir}/bar_#{d.year}_#{d.month}_#{d.day}-#{host}.png"
        pngs[host].save(filename)
        [host, filename]
      }.to_h
    end

    def html_file(nbr)
      "#{@html_dir}/graph_#{nbr}.html"
    end

    def html_link(nbr)
      "graph_#{nbr}.html"
    end

    def make_links(nbr)
      dates = date_logs
      '<table class="cent"><tr>' +
          (nbr+7).step(nbr-7, -1).collect { |n|
            "<td width='6%'>"+
                ((n >= 0 && n < dates.size && n != nbr) ?
                    "<a href='#{html_link(n)}'>#{dates[n].strftime('%m-%d')}</a>" : '') +
                '</td>'
          }.join +
          '</tr></table>'
    end

    def graph_html(log_nbr)
      images = graph_day(list_logs[log_nbr])
      str = "<html><head>#{@html_head}<style>#{@html_style}</style></head><body>" +
          "<div class='main'><h1 class='center'>"+
          "#{date_logs[log_nbr].strftime('%Y-%m-%d')}</h1>" +
          "<table class='cent'>" +
          images.collect { |h, img|
            name = @host_names[h] || h
            "<tr><td>#{name}</td><td><img src='#{File.basename(img)}'</td></tr>\n"
          }.join +
          '</table>' +
          make_links(log_nbr) +
          "</div></body></html>\n"
      IO.write(html_file(log_nbr), str)
    end

    def ping_hosts
      date = Time.now.strftime('%Y-%m-%d_%H.%M.%S')
      hosts = @host_names.sort.collect { |host, name|
        status = System.run_bool "ping -n -W 2 -q -c 1 #{host} > /dev/null"
        "#{host}:#{status ? 'up' : 'down'}"
      }.join(',')
      File.open(@log_file, 'a') { |f|
        f.write("#{date}::#{hosts}\n")
      }
    end
  end
end