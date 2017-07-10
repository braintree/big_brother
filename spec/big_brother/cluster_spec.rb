require 'spec_helper'

describe BigBrother::Cluster do
  before { BigBrother::HealthFetcher.stub(:current_health).and_return(10) }

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
      @stub_executor.commands.should include('ipvsadm --add-service --fwmark-service 100 --scheduler wrr')
    end
  end

  describe "#stop_monitoring!" do
    it "marks the cluster as unmonitored" do
      cluster = Factory.cluster(:fwmark => 100)

      cluster.start_monitoring!
      cluster.should be_monitored

      cluster.stop_monitoring!
      cluster.should_not be_monitored
      @stub_executor.commands.should include("ipvsadm --delete-service --fwmark-service 100")
    end

    it "invalidates recorded weights and sets them to 0 after a stop" do
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      cluster.monitor_nodes

      cluster.stop_monitoring!

      node.weight.should be_zero
    end

    it "invalidates recorded weights, so it properly updates after a stop/start" do
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      cluster.monitor_nodes

      cluster.stop_monitoring!
      cluster.start_monitoring!

      BigBrother::HealthFetcher.stub(:current_health).and_return(15)
      cluster.monitor_nodes

      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 15")
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
    it "does not run multiple ipvsadm commands if the health does not change" do
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.active_passive_cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      @stub_executor.commands.clear
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      cluster.monitor_nodes

      @stub_executor.commands.should == ["ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56"]
    end

    it "will run multiple ipvsadm commands if the health does change" do
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.active_passive_cluster(:fwmark => 100, :nodes => [node])
      cluster.start_monitoring!
      @stub_executor.commands.clear

      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      cluster.monitor_nodes
      BigBrother::HealthFetcher.stub(:current_health).and_return(41)
      cluster.monitor_nodes

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
      cluster.monitor_nodes

      @stub_executor.commands.should == []
    end

    it "marks the cluster as no longer requiring monitoring" do
      cluster = Factory.cluster

      BigBrother::HealthFetcher.stub(:current_health).and_return(10)

      cluster.start_monitoring!
      cluster.needs_check?.should be_true
      cluster.monitor_nodes
      cluster.needs_check?.should be_false
    end

    it "calls monitor on each of the nodes" do
      node1 = Factory.node
      node2 = Factory.node
      cluster = Factory.cluster(:nodes => [node1, node2])
      cluster.start_monitoring!

      node1.should_receive(:monitor).with(cluster)
      node2.should_receive(:monitor).with(cluster)

      cluster.monitor_nodes
    end

    it "enables a downpage if none of the nodes have health > 0" do
      node1 = Factory.node
      node2 = Factory.node
      cluster = Factory.cluster(:has_downpage => true, :nodes => [node1, node2])

      BigBrother::HealthFetcher.stub(:current_health).and_return(0)

      cluster.start_monitoring!
      cluster.monitor_nodes
      cluster.downpage_enabled?.should be_true
    end

    it "does not enable a downpage if the cluster does not have a downpage enabled" do
      node1 = Factory.node
      node2 = Factory.node
      cluster = Factory.cluster(:has_downpage => false, :nodes => [node1, node2])

      BigBrother::HealthFetcher.stub(:current_health).and_return(0)

      cluster.start_monitoring!
      cluster.monitor_nodes
      cluster.downpage_enabled?.should be_false
    end

    it "adds a downpage node to IPVS when down" do
      node1 = Factory.node
      node2 = Factory.node
      cluster = Factory.cluster(:has_downpage => true, :nodes => [node1, node2], :fwmark => 1)

      BigBrother::HealthFetcher.stub(:current_health).and_return(0)

      cluster.start_monitoring!
      cluster.monitor_nodes

      @stub_executor.commands.last.should == "ipvsadm --add-server --fwmark-service 1 --real-server 169.254.254.254 --ipip --weight 1"
    end

    it "removes downpage node from IPVS if it exists and cluster is up" do
      node1 = Factory.node
      node2 = Factory.node
      cluster = Factory.cluster(:has_downpage => true, :nodes => [node1, node2], :fwmark => 1)

      BigBrother::HealthFetcher.stub(:current_health).and_return(0)

      cluster.start_monitoring!
      cluster.monitor_nodes

      BigBrother::HealthFetcher.stub(:current_health).and_return(10)
      cluster.monitor_nodes

      @stub_executor.commands.last.should == "ipvsadm --delete-server --fwmark-service 1 --real-server 127.0.0.1"
    end

    context "nagios" do
      it "sends critical if at least half of all nodes are down" do
        node1 = Factory.node(:address => '192.168.0.1')
        node2 = Factory.node(:address => '192.168.0.2')
        cluster = Factory.cluster(:nodes => [node1, node2], :nagios => {:host => "prod.load", :check => "test1_check", :server => "server.foo"})

        node1.stub(:monitor).and_return(0)
        node2.stub(:monitor).and_return(10)

        cluster.start_monitoring!
        cluster.monitor_nodes
        @stub_executor.commands.should include("echo 'prod.load,test1_check,2,CRITICAL 50% of nodes are down' | send_nsca -H server.foo -d ,")
      end

      it "does not resend a Nagios check if the state does not change" do
        node1 = Factory.node(:address => '192.168.0.1')
        node2 = Factory.node(:address => '192.168.0.2')
        cluster = Factory.cluster(:nodes => [node1, node2], :nagios => {:host => "prod.load", :check => "test1_check", :server => "server.foo"})

        node1.stub(:monitor).and_return(0)
        node2.stub(:monitor).and_return(10)

        cluster.start_monitoring!
        cluster.monitor_nodes
        @stub_executor.clear_commands!

        cluster.monitor_nodes
        @stub_executor.commands.should_not include("echo 'prod.load,test1_check,2,CRITICAL 50% of nodes are down' | send_nsca -H server.foo -d ,")
      end

      it "sends info if at least half of one node is down" do
        node1 = Factory.node(:address => '192.168.0.1')
        node2 = Factory.node(:address => '192.168.0.2')
        node3 = Factory.node(:address => '192.168.0.3')
        cluster = Factory.cluster(:nodes => [node1, node2, node3], :nagios => {:host => "prod.load", :check => "test1_check", :server => "server.foo"})

        node1.stub(:monitor).and_return(0)
        node2.stub(:monitor).and_return(10)
        node3.stub(:monitor).and_return(10)

        cluster.start_monitoring!
        cluster.monitor_nodes
        @stub_executor.commands.should include("echo 'prod.load,test1_check,1,WARNING a node is down' | send_nsca -H server.foo -d ,")
      end

      it "sends ok if all nodes back up" do
        node1 = Factory.node(:address => '192.168.0.1')
        node2 = Factory.node(:address => '192.168.0.2')
        cluster = Factory.cluster(:nodes => [node1, node2], :nagios => {:host => "prod.load", :check => "test1_check", :server => "server.foo"})
        node1.stub(:monitor).and_return(0)
        node2.stub(:monitor).and_return(10)

        cluster.start_monitoring!
        cluster.monitor_nodes
        @stub_executor.commands.should include("echo 'prod.load,test1_check,2,CRITICAL 50% of nodes are down' | send_nsca -H server.foo -d ,")
        @stub_executor.clear_commands!

        node1.stub(:monitor).and_return(10)
        node2.stub(:monitor).and_return(10)
        cluster.monitor_nodes
        @stub_executor.commands.should include("echo 'prod.load,test1_check,0,OK all nodes up' | send_nsca -H server.foo -d ,")
      end
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
      BigBrother.ipvs.stub(:running_configuration).and_return('1' => ['127.0.0.1'])
      cluster = Factory.cluster(:fwmark => 1)

      cluster.synchronize!

      cluster.should be_monitored
    end

    it "does not monitor clusters that were already monitored" do
      BigBrother.ipvs.stub(:running_configuration).and_return({})
      cluster = Factory.cluster(:fwmark => 1)

      cluster.synchronize!

      cluster.should_not be_monitored
    end

    it "does not attempt to re-add the services it was monitoring" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.0.1']})
      cluster = Factory.cluster(:fwmark => 1, :nodes => [Factory.node(:address => '127.0.0.1')])

      cluster.synchronize!

      @stub_executor.commands.should be_empty
    end

    it "removes nodes that are no longer part of the cluster" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.0.1', '127.0.1.1']})
      cluster = Factory.active_active_cluster(:fwmark => 1, :nodes => [Factory.node(:address => '127.0.0.1')])

      cluster.synchronize!

      @stub_executor.commands.should == ["ipvsadm --delete-server --fwmark-service 1 --real-server 127.0.1.1", "ipvsadm --delete-server --fwmark-service 10001 --real-server 127.0.1.1"]
    end

    it "adds new nodes to the cluster" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.0.1']})
      cluster = Factory.cluster(:fwmark => 1, :nodes => [Factory.node(:address => '127.0.0.1'), Factory.node(:address => "127.0.1.1")])

      cluster.synchronize!

      @stub_executor.commands.should include("ipvsadm --add-server --fwmark-service 1 --real-server 127.0.1.1 --ipip --weight 0")
    end
  end

  describe "#to_s" do
    it "is the clusters name and fwmark" do
      cluster = Factory.cluster(:name => 'name', :fwmark => 100)
      cluster.to_s.should == "name (100)"
    end
  end

  describe "#==" do
    it "is true if two clusters have the same fwmark" do
      cluster1 = Factory.cluster(:fwmark => '100')
      cluster2 = Factory.cluster(:fwmark => '200')

      cluster1.should_not == cluster2

      cluster2 = Factory.cluster(:fwmark => '100')
      cluster1.should == cluster2
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

  describe "incorporate_state" do
    it "finds any equivalent nodes from the provided cluster, incorporates their state, and returns self" do
      original_node1 = Factory.node(:address => '127.0.0.1')
      original_node2 = Factory.node(:address => '127.0.1.1')
      original_cluster = Factory.cluster(:nodes => [original_node1, original_node2])

      config_node1 = Factory.node(:address => '127.0.0.1')
      config_node2 = Factory.node(:address => '127.0.1.1')
      config_cluster = Factory.cluster(:nodes => [config_node1, config_node2])

      config_node1.should_receive(:incorporate_state).with(original_node1)
      config_node2.should_receive(:incorporate_state).with(original_node2)

      retval = config_cluster.incorporate_state(original_cluster)

      retval.should == config_cluster
    end

    it "Stops the relay fwmark if shifting from multi_datacenter" do
      original_cluster = Factory.active_active_cluster(:multi_datacenter => true, :nodes => [Factory.node(:address => '127.0.0.1')])
      new_cluster = Factory.active_active_cluster(:multi_datacenter => false, :nodes => [Factory.node(:address => '127.0.0.1')])

      original_cluster.should_receive(:stop_relay_fwmark)

      new_cluster.incorporate_state(original_cluster)
    end

    it "Removes remote nodes if shifting from multi_datacenter" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.0.1', '172.27.1.3']})
      original_cluster = Factory.active_active_cluster(:multi_datacenter => true, :fwmark => 1, :nodes => [Factory.node(:address => '127.0.0.1')])
      original_cluster.instance_variable_set(:@remote_nodes, [Factory.node(:address => '172.27.1.3')])

      new_cluster = Factory.active_active_cluster(:multi_datacenter => false, :fwmark => 1, :nodes => [Factory.node(:address => '127.0.0.1')])
      new_cluster.instance_variable_set(:@remote_nodes, [Factory.node(:address => '172.27.1.3')])

      new_cluster.incorporate_state(original_cluster)

      new_cluster.remote_nodes.should be_empty
    end
  end

  describe "combined_weight" do
    it "sums the weights of all the nodes in the cluster" do
      cluster =Factory.cluster(:name => 'test', :nodes => [
        Factory.node(:weight => 11),
        Factory.node(:weight => 22),
        Factory.node(:weight => 33)
      ])
      cluster.combined_weight.should == 66
    end

    it "correctly interacts with nodes having nil weight as they might coming from a config that doesn't specify it" do
      cluster =Factory.cluster(:name => 'test', :nodes => [
        Factory.node(:weight => 11),
        Factory.node(:weight => nil),
        Factory.node(:weight => 33)
      ])
      cluster.combined_weight.should == 44
    end
  end
end
