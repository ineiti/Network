module Network
  module Operator
    class Tigo < Stub

      @@credit=[
          {cost: 150, volume: 1_000_000, code: 100},
          {cost: 350, volume: 3_000_000, code: 300},
          {cost: 500, volume: 5_000_000, code: 500},
          {cost: 800, volume: 30_000_000, code: 1111},
          {cost: 2_500, volume: 100_000_000, code: 2424},
          {cost: 20_000, volume: 2_000_000_000, code: 7777},
          {cost: 50_000, volume: 10_000_000_000, code: 3030},
          {cost: 30_000, volume: 5_000_000_000, code: 2030}
      ]

      def ussd_send(str)
        @device.ussd_send(str)
      end

      def credit_left(force = false)
        if (force || !@last_credit) ||
            (Time.now - @last_credit > 60 &&
                @device.connection_status == Device::CONNECTED) ||
            (Time.now - @last_credit > 3600 &&
                @device.connection_status == Device::DISCONNECTED)
          ussd_send('*100#')
          @last_credit = Time.now
        end
        if str = @device.ussd_fetch('*100#')
          if left = str.match(/([0-9\.]+)*\s*CFA/)
            return left[1]
          end
        end
      end

      def credit_add(code)
        ussd_send("*123*#{code}#") or return nil
      end

      def credit_send(nbr, credit, pass = '0000')
        ussd_send("*190*#{pass}*#{nbr}*#{credit}#") or return nil
      end

      def internet_left(force = false)
        if (force || !@last_traffic) ||
            (Time.now - @last_traffic > 60 &&
                @device.connection_status == Device::CONNECTED) ||
            (Time.now - @last_traffic > 3600 &&
                @device.connection_status == Device::DISCONNECTED)
          ussd_send('*128#')
          @last_traffic = Time.now
        end
        if str = @device.ussd_fetch('*128#')
          if left = str.match(/([0-9\.]+\s*.[oObB])/)
            bytes, mult = left[1].split
            return -1 unless (bytes && mult)
            (exp = {k: 3, M: 6, G: 9}[mult[0].to_sym]) and
                bytes = (bytes.to_f * 10 ** exp).to_i
            dputs(3) { "Got #{str} and deduced traffic #{left}::#{left[1]}::#{bytes}" }
            return bytes
          end
          return 0
        end
        return -1
=begin
        case sms._Content
          when /100/
            @max_traffic = 3000000
          when /200/
            @max_traffic = 6000000
          when /800/
            @max_traffic = 30000000
        end
        if Date.today.wday % 6 == 0
          @max_traffic *= 2
        end
=end
      end

      def internet_add(volume)
        cr = @@credit.find { |c| c._volume == volume } or return nil
        @device.sms_send(cr._code, 'kattir')
      end

      def internet_cost
        @@credit.collect { |c|
          [c._cost, c._volume]
        }
      end

      def callback(nbr)
        @device.ussd_send("*222*235#{nbr}#")
      end

      def name
        :Tigo
      end
    end
  end
end