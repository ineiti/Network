module Network
  module Operator
    class Airtel < Stub
      attr_accessor :modem

      @@credit=[
          {cost: 250, volume: 10_000_000, code: 10},
          {cost: 1_250, volume: 50_000_000, code: 50},
          {cost: 2_500, volume: 100_000_000, code: 100},
          {cost: 12_500, volume: 1_000_000_000, code: 1},
          {cost: 20_000, volume: 2_000_000_000, code: 2},
          {cost: 50_000, volume: 5_000_000_000, code: 5}
      ]

      def ussd_send(str)
        begin
          @modem.ussd_send(str)
        rescue 'USSDinprogress' => e
          return nil
        end
      end

      def credit_left(force = false)
        dp 'cl'
        @last_credit ||= Time.now - 60
        if Time.now - @last_credit > 60 &&
            (force || @modem.connection_status == Connection::CONNECTED)
          ussd_send('*342#')
          ussd_send('4')
          @last_credit = Time.now
        end
        if str = @modem.ussd_fetch('*137#')
          if left = str.match(/PPL\s*([0-9\.]+)*\s*F/)
            return left[1]
          end
        end
      end

      def credit_add(code)
        ussd_send("*136*#{code}#") or return nil
      end

      def credit_send(nbr, credit)
        raise 'NotSupported'
      end

      def internet_left(force = false)
        dp 'il'
        @last_traffic ||= Time.now - 60
        if Time.now - @last_traffic > 60 &&
            (force || @modem.connection_status == Connection::CONNECTED)
          ussd_send('*137#') or return nil
          @last_traffic = Time.now
        end
        if str = @modem.ussd_fetch('*137#')
          if left = str.match(/([0-9\.]+\s*.[oObB])/)
            bytes, mult = left[1].split
            (exp = {k: 3, M: 6, G: 9}[mult[0].to_sym]) and
                bytes = (bytes.to_f * 10 ** exp).to_i
            ddputs(3) { "Got #{str} and deduced traffic #{left}::#{left[1]}::#{bytes}" }
            return bytes.to_i
          end
          return 0
        end
        return -1
      end

      def internet_add(volume)
        cr = @@credit.find { |c| c._volume == volume } or return
        dputs(2) { "Adding #{cr.inspect} to internet" }
        @modem.ussd_send("*242*#{cr._code}#")
      end

      def internet_cost
        @@credit.collect { |c|
          [c._cost, c._volume]
        }
      end

      def name
        :Airtel
      end
    end
  end
end