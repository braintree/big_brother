require 'spec_helper'

describe BigBrother::Node do

  describe "#monitor" do
    it "updates the weight for the node" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      @stub_executor.commands.clear

      node.monitor(cluster)

      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56")
    end

    it "a node's health should increase linearly over the specified ramp up time" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(100)
      Time.stub(:now).and_return(1345043600)

      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:ramp_up_time => 60, :fwmark => 100, :nodes => [node])
      cluster.start_monitoring!

      Time.stub(:now).and_return(1345043630)
      node.monitor(cluster)
      @stub_executor.commands.last.should == "ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 50"

      Time.stub(:now).and_return(1345043645)
      node.monitor(cluster)
      @stub_executor.commands.last.should == "ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 75"

      Time.stub(:now).and_return(1345043720)
      node.monitor(cluster)
      @stub_executor.commands.last.should == "ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 100"
    end

    it "sets the weight to 100 for each node if an up file exists" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1', :weight => 10)
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      @stub_executor.commands.clear

      BigBrother::StatusFile.new('up', 'test').create('Up for testing')

      node.monitor(cluster)

      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 100")
    end

    it "sets the weight to 0 for each node if a down file exists" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      @stub_executor.commands.clear

      BigBrother::StatusFile.new('down', 'test').create('Down for testing')

      node.monitor(cluster)

      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 0")
    end

    it "does not run multiple ipvsadm commands if the health does not change" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      @stub_executor.commands.clear

      node.monitor(cluster)
      node.monitor(cluster)

      @stub_executor.commands.should == ["ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56"]
    end

    it "will run multiple ipvsadm commands if the health does change" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      @stub_executor.commands.clear

      node.monitor(cluster)
      node.monitor(cluster)
      BigBrother::HealthFetcher.stub(:current_health).and_return(41)
      node.monitor(cluster)

      @stub_executor.commands.should == [
        "ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56",
        "ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 41"
      ]
    end

    it "does not update the weight if the cluster is no longer monitored" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.stop_monitoring!

      @stub_executor.commands.clear
      node.monitor(cluster)

      @stub_executor.commands.should == []
    end
  end

  describe "#==" do
    it "is true when two nodes have the same address and port" do
      node1 = Factory.node(:address => "127.0.0.1", :port => "8000")
      node2 = Factory.node(:address => "127.0.0.1", :port => "8001")
      node1.should_not == node2

      node2 = Factory.node(:address => "127.0.0.2", :port => "8000")
      node1.should_not == node2

      node2 = Factory.node(:address => "127.0.0.1", :port => "8000")
      node1.should == node2
    end
  end

  describe "age" do
    it "is the time in seconds since the node started" do
      Time.stub(:now).and_return(1345043612)
      node = Factory.node(:address => "127.0.0.1")

      node.age.should == 0
    end
  end

  describe "incorporate_state" do
    it "takes the weight and the start time from the other node, but leaves rest of config" do
      original_start_time = Time.now
      node_with_state = Factory.node(:path => '/old/path', :start_time => original_start_time, :weight => 65)
      node_from_config = Factory.node(:path => '/new/path', :start_time => Time.now, :weight => 100)

      node_from_config.incorporate_state(node_with_state)

      node_from_config.path.should == '/new/path'
      node_from_config.start_time.should == original_start_time
      node_from_config.weight.should == 65
    end
  end
end
