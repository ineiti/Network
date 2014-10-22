module Network
  module Operator
    class Tigo < Stub
      attr_accessor :modem

      @@credit=[
          {cost: 150, volume: 1_000_000, code: 100},
          {cost: 350, volume: 3_000_000, code: 300},
          {cost: 500, volume: 5_000_000, code: 500},
          {cost: 800, volume: 30_000_000, code: 1111},
          {cost: 2_500, volume: 100_000_000, code: 2424},
          {cost: 14_000, volume: 1_000_000_000, code: 7777},
          {cost: 50_000, volume: 5_000_000_000, code: 3030},
          {cost: 50_000, volume: 4_000_000_000, code: 2030}
      ]

      def ussd_send(str)
        begin
          @modem.ussd_send(str)
        rescue 'USSDinprogress' => e
          return nil
        end
      end

      def credit_left
        ussd_send('100#') or return nil
        if str = @modem.ussd_fetch('*100#')
          if left = str.match(/([0-9\.]+)*\s*CFA/)
            return left[1]
          end
        end
      end

      def credit_add(code)
        ussd_send("*123*#{code}#") or return nil
      end

      def credit_send(nbr, credit)
        ussd_send("*190*1234*#{nbr}*#{credit}#") or return nil
      end

      def internet_left(force = false)
        @last_traffic ||= Time.now - 60
        if Time.now - @last_traffic > 60 &&
            (force || @modem.connection_status == Connection::CONNECTED)
          ussd_send('*128#')
          @last_traffic = Time.now
        end
        if str = @modem.ussd_fetch('*128#')
          if left = str.match(/([0-9\.]+\s*.[oObB])/)
            bytes, mult = left[1].split
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
        @modem.sms_send(cr._code, 'kattir')
      end

      def internet_cost
        @@credit.collect { |c|
          [c._cost, c._volume]
        }
      end

      def name
        :Tigo
      end
    end
  end
end
