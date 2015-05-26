require 'test/unit'
include Network

class NET_Op_Tigo < Test::Unit::TestCase

  def setup
    Device::Simulation.load
    @simul = Device.search_dev(bus: 'simulation').first
    @tigo = Operator.search_name('Tigo', @simul)
  end

  def teardown

  end

  def test_sms_internet
    assert_equal -1, @tigo.internet_left
    @tigo.new_sms(nbr: '192',
                  msg:'Souscription reussie:GPRS 3030. 10240MB valable 30 jours. Cout 50000F .')
    assert_equal 10_240_000_000, @tigo.internet_left
  end

  def test_ussd_credit
    assert_equal -1, @tigo.credit_left
    @tigo.new_ussd('*123*5091987046410#', 'Vous avez recharge 10000.00 F. Kattir 1500 ! 100Mb a 1500F valide 7jrs. SMS au 1500Votre solde est 50484.00 F.')
    assert_equal 50484, @tigo.credit_left
  end
end