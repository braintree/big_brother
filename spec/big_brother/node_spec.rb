require 'spec_helper'

describe BigBrother::Node do

  describe "#monitor" do
    it "updates the weight for the node" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      @recording_executor.commands.clear

      node.monitor(cluster)

      @recording_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56")
    end

    it "sets the weight to 100 for each node if an up file exists" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      @recording_executor.commands.clear

      BigBrother::StatusFile.new('up', 'test').create('Up for testing')

      node.monitor(cluster)

      @recording_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 100")
    end

    it "sets the weight to 0 for each node if a down file exists" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      @recording_executor.commands.clear

      BigBrother::StatusFile.new('down', 'test').create('Down for testing')

      node.monitor(cluster)

      @recording_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 0")
    end

    it "does not run multiple ipvsadm commands if the health does not change" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      @recording_executor.commands.clear

      node.monitor(cluster)
      node.monitor(cluster)

      @recording_executor.commands.should == ["ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56"]
    end

    it "will run multiple ipvsadm commands if the health does change" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      @recording_executor.commands.clear

      node.monitor(cluster)
      node.monitor(cluster)
      BigBrother::HealthFetcher.stub(:current_health).and_return(41)
      node.monitor(cluster)

      @recording_executor.commands.should == [
        "ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56",
        "ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 41"
      ]
    end

    it "does not update the weight if the cluster is no longer monitored" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.stop_monitoring!

      @recording_executor.commands.clear
      node.monitor(cluster)

      @recording_executor.commands.should == []
    end
  end
end
