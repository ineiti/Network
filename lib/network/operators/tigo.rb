module Network
  module Operator
    class Tigo < Stub
      # Old credit
      @@credit=[
          {cost: 250, volume: 10_000_000, code: 250},
          {cost: 600, volume: 30_000_000, code: 600},
          {cost: 1_200, volume: 70_000_000, code: 1200},
          {cost: 2_000, volume: 120_000_000, code: 2000},
          {cost: 3_000, volume: 256_000_000, code: 3000},
          {cost: 12_000, volume: 1_250_000_000, code: 12000},
          {cost: 35_500, volume: 5_000_000_000, code: 35500},
          {cost: 60_000, volume: 10_000_000_000, code: 60000},
          {cost: 205_000, volume: 35_000_000_000, code: 205000}
      ]

      def initialize(device)
        super(device)
        # If there is not at least 50 CFAs left, Tigo will not connect!
        @tigo_base_credit = 50
        if Kernel.const_defined? :Entities
          @last_promotion = Entities.Statics.get(:Tigo).data_str.to_i
        else
          @last_promotion = 0
        end

        # If there is less than 25MB left, chances are that we need to reconnect
        # every 500kB!
        limit_transfer([[3_000_000, 250_000],
                        [15_000_000, 500_000],
                        [25_000_000, 1_000_000]])

        # TODO: once serialmodem turns into a class, add an observer here
        device.serial_sms_new.push(Proc.new { |sms| new_sms(sms) })
        device.serial_ussd_new.push(Proc.new { |code, str| new_ussd(code, str) })
        @services = %i(connection sms ussd credit promotion umts)
      end

      def last_promotion_set(value)
        log_msg :Tigo, "Updating last_promotion to #{value}"
        @last_promotion = value
        if Kernel.const_defined? :Entities
          Entities.Statics.get(:Tigo).data_str = value
        end
      end

      def new_sms(sms)
        str = sms._msg or return
        case sms._number
          when 'CPTInternet'
            if left = str.match(/(Votre solde est de|Il vous reste) ([0-9\.]+\s*.[oObB])/)
              bytes, mult = left[2].split
              (exp = {k: 3, M: 6, G: 9}[mult[0].to_sym]) and
                  bytes = (bytes.to_f * 10 ** exp).to_i
              dputs(3) { "Got internet: #{bytes} :: #{str}" }
              internet_total(bytes.to_i)
            elsif str =~ /Vous n avez aucun abonnement/
              dputs(3) { "Got internet-none: 0 :: #{str}" }
              internet_total(0)
              last_promotion_set(0)
            end
          when 'TigoCash'
            if str =~ /Solde Tigo Cash: ([0-9]+) CFA/i
              @cash_left = $1
              log_msg :Tigo_cash, "New Tigo cash: #{@cash_left}"
            elsif str =~ /(.*). Votre nouveau solde est de ([0-9]*) CFA/
              @cash_left = $2
              log_msg :Tigo_cash, "Transfer: #{$1} - New cash: #{$2}"
            end
          when '192'
            if str =~ /Votre solde est de ([0-9]+)\./
              credit_total $1.to_i
            end
          else
            if left = str.match(/Vous avez \w* ([0-9\.]+).00 CFA/)
              @credit_left < 0 and @credit_left = 0
              credit_added(left[1].to_i)
            elsif int = str.match(/Souscription reussie:.* ([0-9]+)\s*([MG]B)/)
              @internet_left < 0 and @internet_left = 0
              internet_added(str_to_internet(int[1], int[2]))
            elsif str =~ /vous n avez plus de MB/
              internet_total(0)
              last_promotion_set(0)
            end
        end
      end

      def new_ussd(code, str)
        #dputs_func
        dputs(3) { "#{code} - #{str.inspect}" }
        if str =~ /Apologies, there has been a system error./
          log_msg :Tigo, "Saw apologies-message for #{code} - retrying"
          ussd_send code
        else
          case code
            when '*100#'
              if left = str.match(/([0-9\.]+)*\s*CFA/)
                credit_total left[1].to_i
              end
            when '*128#'
              dputs(3) { "Got string #{str}" }
              if left = str.match(/([0-9\.]+\s*.[oObB])/)
                bytes, mult = left[1].split
                return unless (bytes && mult)
                internet_total str_to_internet bytes, mult
                if @last_promotion <= 0
                  last_promotion_set @internet_left
                end
              elsif str =~ /pas de promotions/ || str =~ /SMS KATTIR/
                dputs(3) { 'Setting internet-left to 0' }
                internet_total 0
                last_promotion_set 0
              end
            when /^\*123/
              if str =~ /Votre solde est ([0-9]+)\./
                credit_total $1.to_i
              else
                update_credit_left(true)
              end
            else
              case str
                # This is Airtel, but perhaps Tigo'll have something like that, too
                when /Cher client,vous n avez plus de MB/
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
            (Time.now - @last_credit > 300 &&
                @device.connection_status == Device::CONNECTED) ||
            (Time.now - @last_credit > 3600 &&
                @device.connection_status == Device::DISCONNECTED)
          ussd_send('*100#')
          @last_credit = Time.now
        end
        @credit_left
      end

      def credit_add(code)
        ussd_send("*123*#{code}#") or return nil
      end

      def credit_send(nbr, credit, pass = '1234')
        ussd_send("*190*#{pass}*#{nbr}*#{credit}#") or return nil
      end

      def cash_update(force = false)
        if (force || !@last_cash) ||
            (Time.now - @last_cash >= 300)
          ussd_send("*800*4*1*#{@cash_password}#")
          @last_cash = Time.now
        end
        return @cash_left
      end

      def cash_send(number, amount)
        ussd_send("*800*1*#{number}*#{amount}*#{@cash_password}")
      end

      def cash_to_credit(amount)

      end

      def update_internet_left(force = false)
        if (force || !@last_traffic) ||
            (Time.now - @last_traffic > 300 &&
                @device.connection_status == Device::CONNECTED) ||
            (Time.now - @last_traffic > 3600 &&
                @device.connection_status == Device::DISCONNECTED)
          ussd_send('*128#')
          @last_traffic = Time.now
        end
        @internet_left
      end

      def internet_add(volume)
        cr = @@credit.find { |c| c._volume == volume } or return nil
        log_msg :Tigo, "Asking for credit #{cr._code} for volume #{volume}"
        # @device.sms_send(cr._code, 'kattir')
        @device.ussd_send("*3*#{cr._code}#")
        @credit_left -= cr._cost
        last_promotion_set cr._volume
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
          [c._cost + @tigo_base_credit, c._volume]
        }
      end

      def callback(nbr)
        @device.ussd_send("*222*235#{nbr}#")
      end

      def internet_cost_smallest
        internet_cost.sort.first.first
      end

      def name
        :Tigo
      end

      def self.operator_match(n)
        n =~ /^(62203|tigo|M-Budget Mobile|ortel)/i
      end

      def has_promo
        true
      end
    end
  end
end