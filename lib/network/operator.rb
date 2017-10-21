require 'helper_classes/system.rb'
require 'helper_classes/virtual.rb'
require 'observer'
include HelperClasses::System

module Network
  module Operator
    attr_accessor :operators, :start_loaded,
                  :cost_base, :cost_shared, :allow_free, :phone_main

    include HelperClasses
    extend HelperClasses::DPuts
    extend self
    DEBUG_LVL = 1

    MISSING = -1
    CONNECTED = 1
    DISCONNECTED = 2
    ERROR = 3

    CONNECTION_ALWAYS = 1
    CONNECTION_ONDEMAND = 2

    @operators = {}
    @cost_base = 10
    @cost_shared = 10
    @allow_free = false
    @phone_main = nil
    @start_loaded = false

    def search_name(name, dev)
      #dputs_func
      dputs(3) { "Looking for #{name} in #{dev}" }
      op = @operators.select { |k, v|
        dputs(3) { "Searching #{name} in #{k} - #{v.name.inspect}" }
        v.operator_match(name)
        #name.to_s.downcase =~ /#{v.name.downcase}/
      }
      ret = op.size > 0 ? op.first.last.new(dev) : nil
      dputs(3) { "And found #{ret.inspect} for #{op.inspect}" }
      ret
    end

    def load
      Dir[File.dirname(__FILE__) + '/operators/*.rb'].each { |f|
        dputs(3) { "Adding operator-file #{f}" }
        require(f)
      }
    end

    def list
      @operators.inspect
    end

    def list_names
      @operators.keys
    end

    def clean_config
      @cost_base &&= @cost_base.to_i
      @cost_shared &&= @cost_shared.to_i
      @allow_free = @allow_free == 'true'
      @start_loaded = @start_loaded == 'true'
    end

=begin
      Methods needed:

      :internet_left, :internet_add, :internet_cost,
      :credit_left, :credit_add, :credit_send,
      :has_promo, :user_cost_max
=end
    class Stub
      attr_accessor :connection_type, :last_promotion, :cash_password
      attr_reader :credit_left, :internet_left, :cash_left, :services
      virtual :cash_update, :cash_send, :cash_to_credit

      extend HelperClasses::DPuts
      include Observable

      def initialize(dev)
        @device = dev
        dev.add_observer(self)
        @connection_type = CONNECTION_ALWAYS
        @internet_left = Network::Operator.start_loaded ? 100_000_000 : -1
        @credit_left = -1
        @cash_left = -1
        @services = {}
      end

      # (credit|internet)_(added_total)
      # Methods to be called when something happens
      def credit_added(add)
        @credit_left += add
        log_msg :Operator, "Added credit #{add}: #{@credit_left}"
        changed
        rescue_all {
          notify_observers(:credit_added, add)
        }
      end

      def credit_total(tot)
        @credit_left = tot
        dputs(2) { "Total credit #{@credit_left}" }
        changed
        rescue_all {
          notify_observers(:credit_total)
        }
      end

      def internet_added(add)
        @internet_left += add
        log_msg :Operator, "Added internet #{add.inspect}: #{@internet_left}"
        changed
        rescue_all {
          notify_observers(:internet_added, add)
        }
      end

      def internet_total(tot)
        @internet_left = tot
        dputs(2) { "Total internet #{@internet_left}" }
        changed
        rescue_all {
          notify_observers(:internet_total)
        }
      end

      def str_to_internet(nbr, e)
        (exp = {k: 3, M: 6, G: 9}[e.to_s[0].to_sym]) and
            bytes = (nbr.to_f * 10 ** exp).to_i
        dputs(3) { "Got #{nbr}::#{e} and deduced traffic #{bytes}" }
        bytes
      end

      def user_cost_max
        Operator.cost_base.to_i + Operator.cost_shared.to_i
      end

      def user_cost_now
        connected = Captive.users_connected.length
        Operator.cost_base + Operator.cost_shared / [1, connected].max
      end

      def name
        self.class.name
      end

      def update(operation, dev = nil)
        if operation =~ /del/
          log_msg :Operator, "Killing #{self}"
        end
      end

      def self.inherited(other)
        dputs(2) { "Inheriting operator #{other.inspect}" }
        Operator.operators[other.to_s.sub(/.*::/, '')] = other
        super(other)
      end

      def self.operator_match(n)
        name = self.name.gsub(/^.*::/, '').downcase
        n.to_s.downcase == name
      end

      def has_promo
        false
      end

      def update_internet_left(force = false)
      end

      def update_credit_left(force = false)
      end

      def internet_add(vol)
        log :Operator, "Adding volume #{vol} to non-prepared operator"
      end

      def internet_add_cost(cost)
        log :Operator, "Adding cost #{cost} to non-prepared operator"
      end

      def internet_cost
        [[-1, nil]]
      end

      def internet_cost_available
        internet_cost.select { |c, v| c <= @credit_left }.sort_by { |c, v| c.to_i }
      end

      def internet_cost_smallest
        internet_cost.sort.first.first.to_i
      end

      # Automatic restart of the connection after a certain amount of traffic:
      # Operator Tigo in Chad limits downloads to a certain amount for small internet-
      # fees. This function restarts the connection in that case.
      # Doesn't apply to fees >= 800CFA
      def limit_transfer(pt)
        @thread_reset = Thread.new {
          rescue_all {
            #dputs_func
            while @device do
              if @last_promotion > 0
                pt.find { |promotion, limit|
                  if promotion >= @last_promotion
                    dputs(3) { "#{promotion}:#{limit}:#{@last_promotion} - #{@internet_left}" }
                    v = System.run_str("grep '#{@device.network_dev}' /proc/net/dev").
                        sub(/^ */, '').split(/[: ]+/)
                    rx, tx = v[1].to_i, v[9].to_i
                    dputs(3) { "#{@device.network_dev} - Tx: #{tx}, Rx: #{rx} - #{v.inspect}" }
                    if rx + tx > limit
                      log_msg :Serial_reset, 'Resetting due to excessive download'
                      @device.connection_restart
                    end
                    true
                  end
                }
              end
              sleep 20
            end
            log_msg :Serial_reset, 'Stopping reset-loop'
          }
        }
      end
    end
  end

  Operator.load
end
