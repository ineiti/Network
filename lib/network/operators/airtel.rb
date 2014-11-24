module Network
  module Operator
    class Airtel < Stub
      attr_accessor :device

      @@credit=[
          {cost: 250, volume: 10_000_000, code: 10},
          {cost: 1_250, volume: 50_000_000, code: 50},
          {cost: 2_500, volume: 100_000_000, code: 100},
          {cost: 12_500, volume: 1_000_000_000, code: 1},
          {cost: 20_000, volume: 2_000_000_000, code: 2},
          {cost: 50_000, volume: 5_000_000_000, code: 5}
      ]

      def initialize(device)
        super(device)
        @device.serial_sms_new.push(Proc.new { |list, id| new_sms(list, id) })
        @internet_left = -1
      end

      def new_sms(list, id)
        if list[id][1] == '"CPTInternet"'
          if str = list[id][4]
            if left = str.match(/([0-9\.]+\s*.[oObB])/)
              bytes, mult = left[1].split
              (exp = {k: 3, M: 6, G: 9}[mult[0].to_sym]) and
                  bytes = (bytes.to_f * 10 ** exp).to_i
              ddputs(3) { "Got #{str} and deduced traffic #{left}::#{left[1]}::#{bytes}" }
              @internet_left = bytes.to_i
            end
          end
          @device.serial_sms_to_delete.push id
        end
      end

      def ussd_send(str)
        @device.ussd_send(str)
      end

      def credit_left(force = false)
        if (force || !@last_credit) ||
            (Time.now - @last_credit >= 300 &&
                @device.status == Device::CONNECTED)
          ussd_send('*137#')
          @last_credit = Time.now
        end
        if str = @device.ussd_fetch('*137#')
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
        if (force || !@last_traffic) ||
            (Time.now - @last_traffic >= 300 &&
                @device.connection_status == Device::CONNECTED)
          ussd_send('*342#')
          ussd_send('4')
          @last_traffic = Time.now
        end
        @internet_left
      end

      def internet_add(volume)
        cr = @@credit.find { |c| c._volume == volume } or return
        dputs(2) { "Adding #{cr.inspect} to internet" }
        @device.ussd_send("*242*#{cr._code}#")
      end

      def internet_add_cost(cost)
        dputs(2){"searching for costs #{cost}"}
        internet_add internet_cost.reverse.find { |c, v|
          cost >= c
        }._volume
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
