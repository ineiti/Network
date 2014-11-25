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
        @device.serial_ussd_new.push(Proc.new { |code, str| new_ussd(code, str) })
        @internet_left = -1
        @credit_left = -1
      end

      def new_sms(list, id)
        if list[id][1] == '"CPTInternet"'
          if str = list[id][4]
            if left = str.match(/(Votre solde est de|Il vous reste) ([0-9\.]+\s*.[oObB])/)
              bytes, mult = left[2].split
              (exp = {k: 3, M: 6, G: 9}[mult[0].to_sym]) and
                  bytes = (bytes.to_f * 10 ** exp).to_i
              dputs(2) { "Got internet: #{bytes} :: #{str}" }
              @internet_left = bytes.to_i
            elsif str =~ /Vous n avez aucun abonnement/
              dputs(2) { "Got internet-none: 0 :: #{str}" }
              @internet_left = 0
            end
          end
          sleep 5
          #@device.serial_sms_to_delete.push id
          @device.sms_delete id
        end
      end

      def new_ussd(code, str)
        dputs(2) { "#{code} - #{str.inspect}" }
        if code == '*137#'
          if left = str.match(/PPL\s*([0-9\.]+)*\s*F/)
            @credit_left = left[1].to_i
            dputs(2) { "Got credit: #{@credit_left} :: #{str}" }
          end
        else
          case str
            when /epuise votre forfait Internet/
              @internet_left = 0
          end
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
        return @credit_left
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
          ussd_send %w( *342# 4 )
          @last_traffic = Time.now
        end
        @internet_left
      end

      def internet_left=(i)
        @internet_left = i
      end

      def internet_add(volume)
        cr = @@credit.find { |c| c._volume == volume } or return
        dputs(2) { "Adding #{cr.inspect} to internet" }
        @device.ussd_send("*242*#{cr._code}#")
      end

      def internet_add_cost(c)
        cost = c.to_i
        dputs(3) { "searching for costs #{cost}" }
        costs = internet_cost.reverse.find { |c, v|
          cost >= c
        } and internet_add(costs.last)
      end

      def internet_cost
        @@credit.collect { |c|
          [c._cost, c._volume]
        }
      end

      def internet_cost_smallest
        dp internet_cost.sort.first.first
      end

      def has_promo
        true
      end

      def name
        :Airtel
      end
    end
  end
end
