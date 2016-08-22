require 'spec_helper'

describe "active_passive clusters" do
  describe "#start_monitoring!" do
    it "starts only the node with the least priority in IPVS" do
      cluster = Factory.active_passive_cluster(
        :fwmark => 100,
        :scheduler => 'wrr',
        :nodes => [
          Factory.node(:priority => 0, :address => "127.0.0.1"),
          Factory.node(:priority => 1, :address => "127.0.0.2"),
        ],
      )

      cluster.start_monitoring!
      @stub_executor.commands.should include('ipvsadm --add-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 1')
      @stub_executor.commands.should_not include('ipvsadm --add-server --fwmark-service 100 --real-server 127.0.0.2 --ipip --weight 1')
    end

    it "monitors a node before adding it to ipvs" do
      cluster = Factory.active_passive_cluster(
        :fwmark => 100,
        :scheduler => 'wrr',
        :nodes => [
          Factory.node(:priority => 0, :address => "127.0.0.1"),
          Factory.node(:priority => 1, :address => "127.0.0.2"),
        ],
      )

      cluster.start_monitoring!
      @stub_executor.commands.should include("ipvsadm --add-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 1")
    end
  end

  describe "#monitor_nodes" do
    it "edit node weight changes in ipvs when the active node is not down" do
      node1 = Factory.node(:priority => 0, :address => "127.0.0.1", :weight => 90)
      node3 = Factory.node(:priority => 2, :address => "127.0.0.3", :weight => 88)
      node2 = Factory.node(:priority => 1, :address => "127.0.0.2", :weight => 87)
      cluster = Factory.active_passive_cluster(:nodes => [node1, node2, node3], :fwmark => 1)
      node1.stub(:monitor).and_return(93)
      node2.stub(:monitor).and_return(92)
      node3.stub(:monitor).and_return(90)

      cluster.start_monitoring!
      cluster.monitor_nodes

      cluster.active_node
      cluster.active_node.address.should == "127.0.0.1"
      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 1 --real-server 127.0.0.1 --ipip --weight 93")
      node1.weight.should == 93
    end

    it "replaces active node in ipvs with new weight when the active node is down" do
      node1 = Factory.node(:priority => 0, :address => "127.0.0.1", :weight => 90)
      node3 = Factory.node(:priority => 2, :address => "127.0.0.3", :weight => 88)
      node2 = Factory.node(:priority => 1, :address => "127.0.1.1", :weight => 87)
      cluster = Factory.active_passive_cluster(:nodes => [node1, node2, node3], :fwmark => 1)
      node1.stub(:monitor).and_return(0)
      node2.stub(:monitor).and_return(92)
      node3.stub(:monitor).and_return(90)

      cluster.start_monitoring!
      cluster.monitor_nodes

      cluster.monitor_nodes

      cluster.active_node
      cluster.active_node.address.should == "127.0.1.1"
      @stub_executor.commands.should include("ipvsadm --delete-server --fwmark-service 1 --real-server 127.0.0.1")
      @stub_executor.commands.should include("ipvsadm --add-server --fwmark-service 1 --real-server 127.0.1.1 --ipip --weight 92")
    end

    it "replaces the unhealthy least priority node with the next priority node" do
      node1 = Factory.node(:priority => 0, :address => "127.0.0.1", :weight => 90)
      node3 = Factory.node(:priority => 2, :address => "127.0.0.3", :weight => 88)
      node2 = Factory.node(:priority => 1, :address => "127.0.0.2", :weight => 87)
      cluster = Factory.active_passive_cluster(:nodes => [node1, node2, node3], :fwmark => 1)
      node1.stub(:monitor).and_return(0)
      node2.stub(:monitor).and_return(92)
      node3.stub(:monitor).and_return(90)

      cluster.start_monitoring!
      cluster.monitor_nodes

      cluster.active_node
      cluster.active_node.address.should == "127.0.0.2"
    end

    it "sets the weight of the current_active_node to 0 in ipvs if all nodes are down" do
      node1 = Factory.node(:priority => 0, :address => "127.0.0.1", :weight => 90)
      node3 = Factory.node(:priority => 2, :address => "127.0.0.3", :weight => 88)
      node2 = Factory.node(:priority => 1, :address => "127.0.0.2", :weight => 87)
      cluster = Factory.active_passive_cluster(:nodes => [node1, node2, node3], :fwmark => 1)
      node1.stub(:monitor).and_return(0)
      node2.stub(:monitor).and_return(0)
      node3.stub(:monitor).and_return(0)

      cluster.start_monitoring!
      cluster.monitor_nodes

      cluster.active_node
      cluster.active_node.address.should == "127.0.0.1"
      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 1 --real-server 127.0.0.1 --ipip --weight 0")
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

  describe "synchronize!" do
    it "continues to monitor clusters that were already monitored" do
      BigBrother.ipvs.stub(:running_configuration).and_return({})
      cluster = Factory.cluster(:fwmark => 1)

      cluster.synchronize!

      cluster.should_not be_monitored
    end

    it "removes current active node if its priority is no longer the least priority" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.1.1']})
      cluster = Factory.active_passive_cluster(
        :fwmark => 1,
        :nodes => [
          Factory.node(:address => '127.0.1.1', :priority => 8, :weight => 55),
          Factory.node(:address => '127.0.0.1', :priority => 3, :weight => 75),
        ],
      )

      cluster.synchronize!

      @stub_executor.commands.should include("ipvsadm --delete-server --fwmark-service 1 --real-server 127.0.1.1")
      @stub_executor.commands.should include("ipvsadm --add-server --fwmark-service 1 --real-server 127.0.0.1 --ipip --weight 75")
    end

    it "removes current active node if the node no longer exist" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.1.1']})
      cluster = Factory.active_passive_cluster(
        :fwmark => 1,
        :nodes => [
          Factory.node(:address => '127.0.1.2', :priority => 2, :weight => 45),
          Factory.node(:address => '127.0.0.1', :priority => 3, :weight => 55),
        ],
      )

      cluster.synchronize!

      @stub_executor.commands.should include("ipvsadm --delete-server --fwmark-service 1 --real-server 127.0.1.1")
      @stub_executor.commands.should include("ipvsadm --add-server --fwmark-service 1 --real-server 127.0.1.2 --ipip --weight 45")
    end

    it "does not remove current active node if it has the least priority" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.1.1']})
      cluster = Factory.active_passive_cluster(
        :fwmark => 1,
        :nodes => [
          Factory.node(:address => '127.0.1.1', :priority => 0),
          Factory.node(:address => '127.0.0.1', :priority => 1),
        ],
      )

      cluster.synchronize!

      @stub_executor.commands.should be_empty
      cluster.active_node.address.should == '127.0.1.1'
    end
  end
end
