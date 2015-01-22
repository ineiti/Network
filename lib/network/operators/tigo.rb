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
        @device.serial_sms_new.push(Proc.new { |list, id| new_sms(list, id) })
        @device.serial_ussd_new.push(Proc.new { |code, str| new_ussd(code, str) })
        @internet_left = -1
        @credit_left = -1
      end

      def new_sms(list, id)
        treated = false
        if list[id][1] == '"CPTInternet"'
          if str = list[id][4]
            if left = str.match(/(Votre solde est de|Il vous reste) ([0-9\.]+\s*.[oObB])/)
              bytes, mult = left[2].split
              (exp = {k: 3, M: 6, G: 9}[mult[0].to_sym]) and
                  bytes = (bytes.to_f * 10 ** exp).to_i
              dputs(2) { "Got internet: #{bytes} :: #{str}" }
              @internet_left = bytes.to_i
              treated = true
            elsif str =~ /Vous n avez aucun abonnement/
              dputs(2) { "Got internet-none: 0 :: #{str}" }
              @internet_left = 0
              treated = true
            end
          end
        end
        if treated
          sleep 5
          #@device.serial_sms_to_delete.push id
          @device.sms_delete id
        end
      end

      def new_ussd(code, str)
        dputs(2) { "#{code} - #{str.inspect}" }
        if str =~ /Apologies, there has been a system error./
          log_msg :Airtel, "Saw apologies-message for #{code} - retrying"
          ussd_send code
        else
          case code
            when '*100#'
              if left = str.match(/([0-9\.]+)*\s*CFA/)
                @credit_left = left[1].to_i
              end
            when '*128#'
              dp "Got string #{str}"
              if left = str.match(/([0-9\.]+\s*.[oObB])/)
                bytes, mult = left[1].split
                @internet_left = -1 unless (bytes && mult)
                (exp = {k: 3, M: 6, G: 9}[mult[0].to_sym]) and
                    bytes = (bytes.to_f * 10 ** exp).to_i
                ddputs(3) { "Got #{str} and deduced traffic #{left}::#{left[1]}::#{bytes}" }
                @internet_left = bytes
              end
            when /^\*123/
              update_credit_left(true)
            else
              case str
                # This is Airtel, but perhaps Tigo'll have something like that, too
                when /epuise votre forfait Internet/
                  @internet_left = 0
              end
          end
        end
      end

      def ussd_send(str)
        @device.ussd_send(str)
      end

      def update_credit_left(force = false)
        if (force || !@last_credit) ||
            (Time.now - @last_credit > 60 &&
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
            (Time.now - @last_traffic > 60 &&
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
        dputs(2){"Asking for credit #{cr._code} for volume #{volume}"}
        @device.sms_send(cr._code, 'kattir')
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