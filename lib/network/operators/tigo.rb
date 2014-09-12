module Network
  module Operators
    class Tigo
      @@credit=[
          {cost: 150, volume: 1_000_000, code: 100 },
          {cost: 350, volume: 3_000_000, code: 300 },
          {cost: 500, volume: 5_000_000, code: 500 },
          {cost: 800, volume: 30_000_000, code: 1111 },
          {cost: 2_500, volume: 100_000_000, code: 2424 },
          {cost: 14_000, volume: 1_000_000_000, code: 7777 },
          {cost: 50_000, volume: 5_000_000_000, code: 3030 },
          {cost: 50_000, volume: 4_000_000_000, code: 2030 }
      ]

      def credit_left
        @modem.ussd_send('*100#')
        if str = @modem.ussd_fetch('*100#')
          if left = str.match(/([0-9\.])*\s*CFA/)
            return left[1]
          end
        end
      end

      def credit_add( code )
        @modem.ussd_send("*123*#{code}#")
      end

      def credit_send( nbr, credit)
        @modem.ussd_send("*190*1234*#{nbr}*#{credit}#")
      end

      def internet_left
        @modem.ussd_send('*128#')
        if str = @modem.ussd_fetch('*128#')
          if left = str.match(/([0-9\.]*\s*.[oObB])/)
            return left[1]
          end
        end
        return -1
      end

      def internet_add( volume )
        cr = @@credit.find{|c| c._volume == volume}
        @modem.sms_send(cr._code, 'kattir')
      end

      def internet_cost
        @@credit.collect{|c|
          [c._cost, c._volume]
        }
      end
    end
  end
end
