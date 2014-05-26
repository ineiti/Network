require 'hilink'

module Network
  class HuaweiHilink < Modem
    def credit_left
    end
    def credit_add
    end
    def credit_mn
    end
    def credit_mb
    end
    def connection_start
    end
    def connection_stop
    end
    def connection_status
    end
    def sms_list
      list = Hilink::SMS.list
      if list._Count.to_i == 0
        []
      else
        list
      end
    end
    def sms_send
    end
    def sms_delete
    end
    def self.modem_present?
      Kernel.system( 'lsusb -d 12d1:14db > /dev/null' )
    end
  end
end