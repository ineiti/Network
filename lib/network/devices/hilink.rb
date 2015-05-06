require 'helperclasses'

begin
  require 'hilinkmodem'

  module Network
    module Device
      class Hilink < Stub
        include HelperClasses::DPuts

        @ids = [{bus: 'usb', id: '12d1:14db'}]

        def connection_start
          dputs(3) { 'Starting connection' }
          HilinkModem::Dialup.connect
        end

        def connection_stop
          dputs(3) { 'Stopping connection' }
          HilinkModem::Dialup.disconnect
        end

        def connection_status
          if status = HilinkModem::Monitoring.status
            dputs(3) { "#{status.inspect}" }
            case HilinkModem::Monitoring.status._ConnectionStatus.to_i
              when 20, 112..115
                DISCONNECTED
              when 900
                CONNECTING
              when 901
                CONNECTED
              when 902
                DISCONNECTED
              when 903
                DISCONNECTING
              when 26, 32
                ERROR_CONNECTION
              else
                ERROR_CONNECTION
            end
          else
            dputs(1) { "No status received" }
            ERROR
          end
        end

        def sms_list
          list = HilinkModem::SMS.list
          if !list or list._Count.to_i == 0
            []
          else
            list._Messages._Message.map { |msg|
              msg.keep_if { |k, v| %w( Index Phone Content Date ).index k.to_s }.to_sym
            }.sort_by { |m| m._Index.to_i }
          end
        end

        def sms_send(nbr, msg)
          HilinkModem::SMS.send(nbr, msg)
        end

        def sms_delete(index)
          HilinkModem::SMS.delete(index)
        end

        def traffic_stats
          if stats = HilinkModem::Monitoring.traffic_statistics
            dputs(3) { stats.inspect }
            {:rx => stats._TotalDownload, :tx => stats._TotalUpload}
          else
            {:rx => -1, :tx => -1}
          end
        end

        def traffic_reset
          HilinkModem::Monitoring.traffic_reset
        end

        def set_2g
          HilinkModem::Network.set_connection_type('2g')
        end

        def reset
          System.run_bool('netctl eth2 restart')
        end

        def down
          System.run_bool('netctl eth2 down')
        end
      end
    end
  end

rescue LoadError
  dputs(0) { 'HilinkModem is not in path' }
end