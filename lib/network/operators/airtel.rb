module Network
  module Operators
    class Airtel < Network::Operator
      @@credit=[
          {cost: 250, volume: 10_000_000, code: 10 },
          {cost: 1_250, volume: 50_000_000, code: 50 },
          {cost: 2_500, volume: 100_000_000, code: 100 },
          {cost: 12_500, volume: 1_000_000_000, code: 1 },
          {cost: 20_000, volume: 2_000_000_000, code: 2 },
          {cost: 50_000, volume: 5_000_000_000, code: 5 }
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
        @modem.ussd_send("*242*#{cr.code}#")
      end

      def internet_cost
        @@credit.collect{|c|
          [c._cost, c._volume]
        }
      end
    end
  end
end
