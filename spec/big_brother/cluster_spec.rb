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

  describe "#needs_check?" do
    it "requires the cluster to be monitored" do
      cluster = Factory.cluster
      cluster.needs_check?.should be_false
      cluster.start_monitoring!
      cluster.needs_check?.should be_true
    end
  end

  describe "#monitor_nodes" do
    it "marks the cluster as no longer requiring monitoring" do
      cluster = Factory.cluster
      cluster.start_monitoring!
      cluster.needs_check?.should be_true
      cluster.monitor_nodes
      cluster.needs_check?.should be_false
    end

    it "calls monitor on each of the nodes" do
      node1 = Factory.node
      node2 = Factory.node
      cluster = Factory.cluster(:nodes => [node1, node2])

      node1.should_receive(:monitor).with(cluster)
      node2.should_receive(:monitor).with(cluster)

      cluster.monitor_nodes
    end
  end

  describe "#resume_monitoring!" do
    it "marks the cluster as monitored" do
      cluster = Factory.cluster

      cluster.monitored?.should be_false
      cluster.resume_monitoring!
      cluster.monitored?.should be_true
    end
  end

  describe "#to_s" do
    it "is the clusters name and fwmark" do
      cluster = Factory.cluster(:name => 'name', :fwmark => 100)
      cluster.to_s.should == "name (100)"
    end
  end

  describe "#up_file_exists?" do
    it "returns true when an up file exists" do
      cluster = Factory.cluster(:name => 'name')
      cluster.up_file_exists?.should be_false

      BigBrother::StatusFile.new('up', 'name').create('Up for testing')

      cluster.up_file_exists?.should be_true
    end
  end

  describe "#down_file_exists?" do
    it "returns true when an down file exists" do
      cluster = Factory.cluster(:name => 'name')
      cluster.down_file_exists?.should be_false

      BigBrother::StatusFile.new('down', 'name').create('down for testing')

      cluster.down_file_exists?.should be_true
    end
  end
end
