require 'spec_helper'

describe BigBrother::Ticker do
  describe ".schedule!" do
    it "schedules the ticker to run ten times every second" do
      EventMachine.should_receive(:add_periodic_timer).with(0.1)

      BigBrother::Ticker.schedule!
    end
  end

  describe ".tick" do
    describe "end-to-end" do
      run_in_reactor
      with_litmus_server '127.0.0.1', 8081, 74
      with_litmus_server public_ip_address, 8082, 76

      it "monitors clusters requiring monitoring" do
        BigBrother.clusters['test'] = Factory.cluster(
          :fwmark => 100,
          :nodes => [
            Factory.node(:address  => '127.0.0.1', :port => 8081),
            Factory.node(:address  => public_ip_address, :port => 8082)
          ]
        )
        BigBrother.clusters['test'].start_monitoring!
        @recording_executor.commands.clear

        BigBrother::Ticker.tick

        @recording_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 74")
        @recording_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server #{public_ip_address} --ipip --weight 76")
      end

      it "only monitors a cluster once in the given interval" do
        BigBrother.clusters['test'] = Factory.cluster(
          :fwmark => 100,
          :nodes => [Factory.node(:address  => '127.0.0.1', :port => 8081)]
        )
        BigBrother.clusters['test'].start_monitoring!
        @recording_executor.commands.clear

        BigBrother::Ticker.tick
        BigBrother::Ticker.tick

        @recording_executor.commands.should == ["ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 74"]
      end
    end

    it "monitors clusters requiring monitoring" do
      BigBrother.clusters['one'] = Factory.cluster
      BigBrother.clusters['two'] = Factory.cluster
      BigBrother.clusters['two'].start_monitoring!

      BigBrother.clusters['two'].should_receive(:monitor_nodes)

      BigBrother::Ticker.tick
    end
  end
end
