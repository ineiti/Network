module Network
  module Operator
    class Airtel < Stub
      @@credit=[
          {cost: 200, volume: 5_000_000, code: 15},
          {cost: 250, volume: 10_000_000, code: 10},
          {cost: 500, volume: 20_000_000, code: 20},
          {cost: 1_000, volume: 50_000_000, code: 50},
          {cost: 1_500, volume: 100_000_000, code: 100},
          {cost: 2_000, volume: 200_000_000, code: 200},
          {cost: 5_000, volume: 500_000_000, code: 500},
          {cost: 10_000, volume: 1_000_000_000, code: 1_000},
          {cost: 20_000, volume: 2_000_000_000, code: 2_000},
          {cost: 30_000, volume: 5_000_000_000, code: 5_000},
          {cost: 50_000, volume: 10_000_000_000, code: 10_000}
      ]

      def initialize(device)
        super(device)

        # TODO: once serialmodem turns into a class, add an observer here
        device.serial_sms_new.push(Proc.new { |sms| new_sms(sms) })
        device.serial_ussd_new.push(Proc.new { |code, str| new_ussd(code, str) })
        @services = %i(connection sms ussd credit promotion umts)
      end

      def new_sms(sms)
        treated = false
        case sms._number
          when 'CPTInternet', '342'
            if str = sms._msg
              if left = str.match(/(Votre solde est de|Il vous reste) ([0-9\.]+\s*.[oObB])/)
                bytes, mult = left[2].split
                internet_total str_to_internet bytes, mult
                treated = true
              elsif left = str.match(/(Vous avez achete le forfait) ([0-9\.]+\s*.[oObB])/)
                bytes, mult = left[2].split
                internet_add str_to_internet bytes, mult
                treated = true
              elsif str =~ /Vous n avez aucun abonnement/
                internet_total 0
                treated = true
              end
            end
          when '432'
            case str = sms._msg
              when /^601:/
                if credit = str.match(/transfere ([0-9]+) CFA/)
                  credit_add credit[1].to_i
                end
            end
        end
        if treated
          sleep 5
          @device.sms_delete sms._id
        end
      end

      def new_ussd(code, str)
        dputs(3) { "#{code} - #{str.inspect}" }
        if str =~ /Apologies, there has been a system error./
          log_msg :Airtel, "Saw apologies-message for #{code} - retrying"
          ussd_send code
        else
          case code
            when '*137#'
              if left = str.match(/(Solde principal|PPL|Solde: )\s*([0-9\.]+)*\s*F/)
                credit_total left[2].to_i
              end
            when /^\*136/
              if left = str.match(/Vous avez recharge ([0-9]+) F/)
                credit_added left[1].to_i
              end
            else
              case str
                when /epuise votre forfait Internet/
                  internet_total 0
              end
          end
        end
      end

      def ussd_send(str)
        @device.ussd_send(str)
      end

      def update_credit_left(force = false)
        if (force || !@last_credit) ||
            (Time.now - @last_credit >= 300 &&
                @device.connection_status == Device::CONNECTED)
          ussd_send('*137#')
          @last_credit = Time.now
        end
        return @credit_left
      end

      def credit_add(code)
        ussd_send("*136*#{code.gsub(/[^0-9]/, '')}#") or return nil
      end

      def credit_send(nbr, credit)
        raise 'NotSupported'
      end

      def update_internet_left(force = false)
        if (force || !@last_traffic) ||
            (Time.now - @last_traffic >= 300 &&
                @device.connection_status == Device::CONNECTED)
          ussd_send '*242#'
          @last_traffic = Time.now
        end
        @internet_left
      end

      def internet_add(volume)
        cr = @@credit.find { |c| c._volume == volume } or return
        log_msg :Airtel, "Adding #{cr.inspect} to internet"
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

      def has_promo
        true
      end

      def name
        :Airtel
      end

      def self.operator_match(n)
        n =~ /^(62201|airtel)/i
      end

    end
  end
end
