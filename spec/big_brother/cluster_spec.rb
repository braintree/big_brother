require 'spec_helper'

describe BigBrother::Cluster do
  describe "#start_monitoring!" do
    it "marks the cluster as monitored" do
      cluster = Factory.cluster
      cluster.should_not be_monitored
      cluster.start_monitoring!
      cluster.should be_monitored
    end

    it "starts the service in IPVS" do
      cluster = Factory.cluster(:fwmark => 100, :scheduler => 'wrr')

      cluster.start_monitoring!
      @recording_executor.commands.should include('ipvsadm --add-service --fwmark-service 100 --scheduler wrr')
    end
  end

  describe "#stop_monitoring!" do
    it "marks the cluster as unmonitored" do
      cluster = Factory.cluster(:fwmark => 100)

      cluster.start_monitoring!
      cluster.should be_monitored

      cluster.stop_monitoring!
      cluster.should_not be_monitored
      @recording_executor.commands.should include("ipvsadm --delete-service --fwmark-service 100")
    end
  end

  describe "#monitor_nodes" do
    it "marks the cluster as no longer requiring monitoring" do
      cluster = Factory.cluster
      cluster.needs_check?.should be_true
      cluster.monitor_nodes
      cluster.needs_check?.should be_false
    end

    it "updates the weight for each node" do
      node = Factory.node(:address => '127.0.0.1')
      node.should_receive(:current_health).and_return(56)
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])

      cluster.monitor_nodes

      @recording_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56")
    end
  end
end
