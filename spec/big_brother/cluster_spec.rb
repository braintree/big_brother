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
      cluster = Factory.cluster
      cluster.start_monitoring!
      cluster.should be_monitored
      cluster.stop_monitoring!
      cluster.should_not be_monitored
    end
  end

  describe "#monitor_nodes" do
    it "marks the cluster as no longer requiring monitoring" do
      cluster = Factory.cluster
      cluster.needs_check?.should be_true
      cluster.monitor_nodes
      cluster.needs_check?.should be_false
    end

    it "checks each node" do
      node = Factory.node
      node.should_receive(:current_health)
      cluster = Factory.cluster(:nodes => [node])

      cluster.monitor_nodes
    end
  end
end
