module Network
  module Operator
    class Tigo < Stub
      attr_accessor :credit_left, :internet_left

      @@credit=[
          {cost: 150, volume: 3_000_000, code: 100},
          {cost: 300, volume: 15_000_000, code: 200},
          {cost: 500, volume: 25_000_000, code: 500},
          {cost: 800, volume: 40_000_000, code: 1111},
          {cost: 1_500, volume: 100_000_000, code: 1500},
          {cost: 2_500, volume: 256_000_000, code: 2424},
          {cost: 5_000, volume: 512_000_000, code: 5030},
          {cost: 10_000, volume: 1_000_000_000, code: 1030},
          {cost: 20_000, volume: 2_000_000_000, code: 7777},
          {cost: 30_000, volume: 5_000_000_000, code: 2030},
          {cost: 50_000, volume: 10_000_000_000, code: 3030}
      ]

      def initialize(device)
        super(device)
        # If there is not at least 50 CFAs left, Tigo will not connect!
        @tigo_base_credit = 50
        @last_promotion = Entities.Statics.get(:Tigo).data_str.to_i

        # If there is less than 25MB left, chances are that we need to reconnect
        # every 500kB!
        limit_transfer([[3_000_000, 250_000],
                        [15_000_000, 500_000],
                        [25_000_000, 1_000_000]])

        # TODO: once serialmodem turns into a class, add an observer here
        device.serial_sms_new.push(Proc.new { |sms| new_sms(sms) })
        device.serial_ussd_new.push(Proc.new { |code, str| new_ussd(code, str) })
      end

      def last_promotion_set(value)
        log_msg :Tigo, "Updating last_promotion to #{value}"
        @last_promotion = value
        Entities.Statics.get(:Tigo).data_str = value
      end

      def new_sms(sms)
        treated = false
        str = sms._msg or return
        case sms._number
          when 'CPTInternet'
            if left = str.match(/(Votre solde est de|Il vous reste) ([0-9\.]+\s*.[oObB])/)
              bytes, mult = left[2].split
              (exp = {k: 3, M: 6, G: 9}[mult[0].to_sym]) and
                  bytes = (bytes.to_f * 10 ** exp).to_i
              dputs(3) { "Got internet: #{bytes} :: #{str}" }
              internet_total bytes.to_i
              treated = true
            elsif str =~ /Vous n avez aucun abonnement/
              dputs(3) { "Got internet-none: 0 :: #{str}" }
              internet_total 0
              last_promotion_set 0
              treated = true
            end
          else
            if left = str.match(/Vous avez recu ([0-9\.]+).00 CFA/)
              credit_added left[1].to_i
            elsif int = str.match(/Souscription reussie:.* ([0-9]+)\s*([MG]B)/)
              internet_added str_to_internet(int[1], int[2])
            elsif str =~ /vous n avez plus de MB/
              internet_total 0
              last_promotion_set 0
            end
        end
        if treated
          sleep 5
          @device.sms_delete sms._id
        end
      end

      def new_ussd(code, str)
        #dputs_func
        ddputs(3) { "#{code} - #{str.inspect}" }
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
              update_credit_left(true)
            else
              case str
                # This is Airtel, but perhaps Tigo'll have something like that, too
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

      def credit_send(nbr, credit, pass = '0000')
        ussd_send("*190*#{pass}*#{nbr}*#{credit}#") or return nil
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
        @device.sms_send(cr._code, 'kattir')
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
        n =~ /^(62203|tigo)/i
      end

      def has_promo
        true
      end
    end
  end
end