require 'spec_helper'

describe BigBrother::ActiveActiveCluster do
  before { BigBrother::HealthFetcher.stub(:current_health).and_return(10) }

  describe '#start_monitoring!' do
    it 'starts all non interpol nodes' do
      cluster = Factory.active_active_cluster(
        :fwmark => 100,
        :scheduler => 'wrr',
        :nodes => [
          Factory.node(:interpol => false, :address => '127.0.0.1'),
          Factory.node(:interpol => false, :address => '127.0.0.2'),
          Factory.node(:interpol => true,  :address => '127.0.0.3'),
        ],
      )
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([])
      cluster.start_monitoring!

      @stub_executor.commands.should include('ipvsadm --add-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 10')
      @stub_executor.commands.should include('ipvsadm --add-server --fwmark-service 100 --real-server 127.0.0.2 --ipip --weight 10')
      @stub_executor.commands.should_not include('ipvsadm --add-server --fwmark-service 100 --real-server 127.0.0.3 --ipip --weight 10')
    end

    it 'starts all relay fwmark service' do
      cluster = Factory.active_active_cluster(
        :fwmark => 100,
        :scheduler => 'wrr',
        :offset => 10000,
        :nodes => [
          Factory.node(:interpol => true,  :address => '127.0.0.3'),
        ],
      )
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([])
      cluster.start_monitoring!

      @stub_executor.commands.should include('ipvsadm --add-service --fwmark-service 10100 --scheduler wrr')
    end

    it 'starts all local_nodes on relay fwmark' do
      cluster = Factory.active_active_cluster(
        :fwmark => 100,
        :scheduler => 'wrr',
        :offset => 10000,
        :nodes => [
          Factory.node(:interpol => false, :address => '127.0.0.1'),
          Factory.node(:interpol => false, :address => '127.0.0.2'),
          Factory.node(:interpol => true,  :address => '127.0.0.3'),
        ],
      )
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([])
      cluster.start_monitoring!

      @stub_executor.commands.should include('ipvsadm --add-server --fwmark-service 10100 --real-server 127.0.0.1 --ipip --weight 10')
      @stub_executor.commands.should include('ipvsadm --add-server --fwmark-service 10100 --real-server 127.0.0.2 --ipip --weight 10')
      @stub_executor.commands.should_not include('ipvsadm --add-server --fwmark-service 10100 --real-server 127.0.0.3 --ipip --weight 10')
    end

    it 'does not start interpol nodes when the remote relay cluster is non-existent' do
      node = Factory.node(:interpol => true,  :address => '127.0.0.3')
      cluster = Factory.active_active_cluster(
        :fwmark => 100,
        :scheduler => 'wrr',
        :nodes => [
          Factory.node(:interpol => false, :address => '127.0.0.1'),
          Factory.node(:interpol => false, :address => '127.0.0.2'),
          node,
        ],
      )

      BigBrother::HealthFetcher.stub(:interpol_status).with(node, 100).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      BigBrother::HealthFetcher.stub(:interpol_status).with(node, 10100).and_return([])
      cluster.start_monitoring!

      @stub_executor.commands.should_not include('ipvsadm --add-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 45')
    end

    it 'does not start interpol nodes when the remote regular cluster is non-existent' do
      node = Factory.node(:interpol => true,  :address => '127.0.0.3')
      cluster = Factory.active_active_cluster(
        :fwmark => 100,
        :scheduler => 'wrr',
        :nodes => [
          Factory.node(:interpol => false, :address => '127.0.0.1'),
          Factory.node(:interpol => false, :address => '127.0.0.2'),
          node,
        ],
      )

      BigBrother::HealthFetcher.stub(:interpol_status).with(node, 10100).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      BigBrother::HealthFetcher.stub(:interpol_status).with(node, 100).and_return([])
      cluster.start_monitoring!

      @stub_executor.commands.should_not include('ipvsadm --add-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 45')
    end

    it 'starts all interpol nodes if both the regular and relay remote clusters exist' do
      node = Factory.node(:interpol => true,  :address => '127.0.0.3')
      cluster = Factory.active_active_cluster(
        :fwmark => 100,
        :scheduler => 'wrr',
        :nodes => [
          Factory.node(:interpol => false, :address => '127.0.0.1'),
          Factory.node(:interpol => false, :address => '127.0.0.2'),
          node,
        ],
      )

      BigBrother::HealthFetcher.stub(:interpol_status).with(node, 100).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      BigBrother::HealthFetcher.stub(:interpol_status).with(node, 10100).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      cluster.start_monitoring!

      @stub_executor.commands.should include('ipvsadm --add-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 45')
    end
  end

  describe "#monitor_nodes" do
    it "update weight of local ipvs nodes" do
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([])
      node = Factory.node(:address => '127.0.0.1')
      interpol_node = Factory.node(:address => '172.27.3.1', :interpol => true)
      cluster = Factory.active_active_cluster(:fwmark => 100, :nodes => [node, interpol_node])
      cluster.start_monitoring!
      @stub_executor.commands.clear

      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      cluster.monitor_nodes
      BigBrother::HealthFetcher.stub(:current_health).and_return(41)
      cluster.monitor_nodes

      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56")
      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 41")
    end

    it "update weight of relay ipvs nodes" do
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([])
      node = Factory.node(:address => '127.0.0.1')
      interpol_node = Factory.node(:address => '172.27.3.1', :interpol => true)
      cluster = Factory.active_active_cluster(:fwmark => 100, :offset => 10000, :nodes => [node, interpol_node])
      cluster.start_monitoring!
      @stub_executor.commands.clear

      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      cluster.monitor_nodes
      BigBrother::HealthFetcher.stub(:current_health).and_return(41)
      cluster.monitor_nodes

      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 10100 --real-server 127.0.0.1 --ipip --weight 56")
       @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 10100 --real-server 127.0.0.1 --ipip --weight 41")
    end

    it "does not update remote nodes for relay fwmark" do
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 91,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      node = Factory.node(:address => '127.0.0.1')
      interpol_node = Factory.node(:address => '172.27.3.1', :interpol => true)
      cluster = Factory.active_active_cluster(:fwmark => 100, :nodes => [node, interpol_node], :offset => 10_000)
      @stub_executor.commands.clear

      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      cluster.resume_monitoring!
      cluster.monitor_nodes
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 130,'count' => 2,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 65}])
      cluster.monitor_nodes

      @stub_executor.commands.should_not include("ipvsadm --edit-server --fwmark-service 10100 --real-server 172.27.3.1 --ipip --weight 56")
    end

    it "update weight of remote nodes" do
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      node = Factory.node(:address => '127.0.0.1')
      interpol_node = Factory.node(:address => '172.27.3.1', :interpol => true)
      cluster = Factory.active_active_cluster(:fwmark => 100, :nodes => [node, interpol_node])
      cluster.start_monitoring!
      @stub_executor.commands.clear

      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      cluster.monitor_nodes

      cluster.remote_nodes.first.weight.should == 45

      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 130,'count' => 2,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 65}])
      cluster.monitor_nodes

      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56")
      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 65")
    end

    it "does not update weight of remote nodes if the weight has not changed" do
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 55}])
      node = Factory.node(:address => '127.0.0.1')
      interpol_node = Factory.node(:address => '172.27.3.1', :interpol => true)
      cluster = Factory.active_active_cluster(:fwmark => 100, :nodes => [node, interpol_node])
      cluster.start_monitoring!
      @stub_executor.commands.clear

      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      cluster.monitor_nodes
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 130,'count' => 2,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      cluster.monitor_nodes
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 130,'count' => 2,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      cluster.monitor_nodes

      @stub_executor.commands.should == ["ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56", "ipvsadm --edit-server --fwmark-service 10100 --real-server 127.0.0.1 --ipip --weight 56", "ipvsadm --edit-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 45"]
    end

    it "update weight of remote not returned to 0" do
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      node = Factory.node(:address => '127.0.0.1')
      interpol_node = Factory.node(:address => '172.27.3.1', :interpol => true)
      cluster = Factory.active_active_cluster(:fwmark => 100, :nodes => [node, interpol_node], :max_down_ticks => 2)
      cluster.start_monitoring!
      @stub_executor.commands.clear

      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      cluster.monitor_nodes
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([])
      cluster.monitor_nodes

      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56")
      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 0")
    end

    it "adds newly discovered remote nodes to ipvs" do
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([])
      node = Factory.node(:address => '127.0.0.1')
      interpol_node = Factory.node(:address => '172.27.3.1', :interpol => true)
      cluster = Factory.active_active_cluster(:fwmark => 100, :nodes => [node, interpol_node])
      cluster.start_monitoring!
      cluster.instance_variable_get(:@remote_nodes).size.should == 0

      @stub_executor.commands.clear

      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      cluster.monitor_nodes

      cluster.remote_nodes.size.should == 1

      BigBrother::HealthFetcher.stub(:interpol_status).and_return(
        [
          {'aggregated_health' => 130,'count' => 2,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 65},
          {'aggregated_health' => 100,'count' => 1,'lb_ip_address' => '172.27.3.2','lb_url' => 'http://172.27.3.2','health' => 40},
        ]
      )
      cluster.monitor_nodes

      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56")
      @stub_executor.commands.should include("ipvsadm --add-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 45")
      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 65")
      @stub_executor.commands.should include("ipvsadm --add-server --fwmark-service 100 --real-server 172.27.3.2 --ipip --weight 40")
      cluster.instance_variable_get(:@remote_nodes).size.should == 2
    end

    it "removes a remote node from ipvs if it has been down for too many ticks" do
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      node = Factory.node(:address => '127.0.0.1')
      interpol_node = Factory.node(:address => '172.27.3.1', :interpol => true)
      cluster = Factory.active_active_cluster(:fwmark => 100, :nodes => [node, interpol_node], :max_down_ticks => 100)
      cluster.start_monitoring!
      @stub_executor.commands.clear

      (cluster.max_down_ticks + 1).times do
        BigBrother::HealthFetcher.stub(:interpol_status).and_return([])
        cluster.monitor_nodes
      end

      @stub_executor.commands.should include("ipvsadm --delete-server --fwmark-service 100 --real-server 172.27.3.1")
      cluster.instance_variable_get(:@remote_nodes).should be_empty
    end
  end

  describe "#synchronize!" do
    it "does not remove remote nodes" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.0.1', '172.27.1.3']})
      cluster = Factory.active_active_cluster(:fwmark => 1, :nodes => [Factory.node(:address => '127.0.0.1')])
      cluster.instance_variable_set(:@remote_nodes, [Factory.node(:address => '172.27.1.3')])

      cluster.synchronize!

      @stub_executor.commands.should be_empty
    end

    it "does not append remote_nodes to nodes" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.0.1', '172.27.1.3']})
      cluster = Factory.active_active_cluster(:fwmark => 1, :nodes => [Factory.node(:address => '127.0.0.1')])
      cluster.instance_variable_set(:@remote_nodes, [Factory.node(:address => '172.27.1.3')])

      cluster.synchronize!

      cluster.nodes.size.should == 1
    end
  end

  describe "synchronize!" do
    it "continues to monitor clusters that were already monitored" do
      BigBrother.ipvs.stub(:running_configuration).and_return('1' => ['127.0.0.1'])
      cluster = Factory.active_active_cluster(:fwmark => 1)

      cluster.synchronize!

      cluster.should be_monitored
    end

    it "does not monitor clusters that were already monitored" do
      BigBrother.ipvs.stub(:running_configuration).and_return({})
      cluster = Factory.active_active_cluster(:fwmark => 1)

      cluster.synchronize!

      cluster.should_not be_monitored
    end

    it "does not attempt to re-add the services it was monitoring" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.0.1']})
      cluster = Factory.active_active_cluster(:fwmark => 1, :nodes => [Factory.node(:address => '127.0.0.1')])

      cluster.synchronize!

      @stub_executor.commands.should be_empty
    end

    it "removes relay nodes that are no longer part of the cluster" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.0.1', '127.0.1.1']})
      cluster = Factory.active_active_cluster(:fwmark => 1, :offset => 10000, :nodes => [Factory.node(:address => '127.0.0.1')])

      cluster.synchronize!

      @stub_executor.commands.should include("ipvsadm --delete-server --fwmark-service 1 --real-server 127.0.1.1")
      @stub_executor.commands.should include("ipvsadm --delete-server --fwmark-service 10001 --real-server 127.0.1.1")
    end

    it "adds new relay nodes to the cluster" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.0.1']})
      cluster = Factory.active_active_cluster(:fwmark => 1, :offset => 10000, :nodes => [Factory.node(:address => '127.0.0.1'), Factory.node(:address => "127.0.1.1")])

      cluster.synchronize!

      @stub_executor.commands.should include("ipvsadm --add-server --fwmark-service 1 --real-server 127.0.1.1 --ipip --weight 0")
      @stub_executor.commands.should include("ipvsadm --add-server --fwmark-service 10001 --real-server 127.0.1.1 --ipip --weight 0")
    end

    it "does not add remote nodes to relay ipvs fwmark" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.0.1']})
      cluster = Factory.active_active_cluster(:fwmark => 1, :offset => 10000, :nodes => [Factory.node(:address => '127.0.0.1'), Factory.node(:address => "127.0.1.1"), Factory.node(:address => "127.1.1.1", :interpol => true)])
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])

      cluster.start_monitoring!
      cluster.synchronize!

      @stub_executor.commands.should_not include("ipvsadm --add-server --fwmark-service 10001 --real-server 172.27.3.1 --ipip --weight 0")
    end
  end

  describe "#stop_monitoring!" do
    it "deletes the relay fwmark" do
      cluster = Factory.active_active_cluster(:fwmark => 1, :offset => 10000, :nodes => [])
      cluster.stop_monitoring!

      @stub_executor.commands.should include("ipvsadm --delete-service --fwmark-service 10001")
    end
  end

  describe "#incorporate_state" do
    it "starts a relay_fwmark when it is not started" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.0.1']})
      active_active_cluster = Factory.active_active_cluster(:fwmark => 1, :offset => 10000, :nodes => [Factory.node(:address => '127.0.0.1'), Factory.node(:address => "127.0.1.1"), Factory.node(:address => "127.1.1.1", :interpol => true)])
      cluster = Factory.cluster(:fwmark => 1, :offset => 10000, :nodes => [Factory.node(:address => '127.0.0.1', :weight => 80), Factory.node(:address => "127.0.1.1", :weight => 100)])

      active_active_cluster.incorporate_state(cluster)

      @stub_executor.commands.should == ["ipvsadm --add-service --fwmark-service 10001 --scheduler wrr", "ipvsadm --add-server --fwmark-service 10001 --real-server 127.0.0.1 --ipip --weight 80", "ipvsadm --add-server --fwmark-service 10001 --real-server 127.0.1.1 --ipip --weight 100"]
    end

    it "does not starts a relay_fwmark when the cluster is not running" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'2' => ['127.0.0.1']})
      active_active_cluster = Factory.active_active_cluster(:fwmark => 1, :offset => 10000, :nodes => [Factory.node(:address => '127.0.0.1'), Factory.node(:address => "127.0.1.1"), Factory.node(:address => "127.1.1.1", :interpol => true)])
      cluster = Factory.cluster(:fwmark => 1, :offset => 10000, :nodes => [Factory.node(:address => '127.0.0.1', :weight => 80), Factory.node(:address => "127.0.1.1", :weight => 100)])

      active_active_cluster.incorporate_state(cluster)

      @stub_executor.commands.should be_empty
    end
  end

  describe "#stop_relay_fwmark" do
    it "stops relay fwmark and all nodes in the relay fwmark" do
      active_active_cluster = Factory.active_active_cluster(:fwmark => 1, :offset => 10000, :nodes => [Factory.node(:address => '127.0.0.1'), Factory.node(:address => "127.0.1.1"), Factory.node(:address => "127.1.1.1", :interpol => true)])

      active_active_cluster.stop_relay_fwmark

      @stub_executor.commands.should == ["ipvsadm --delete-server --fwmark-service 10001 --real-server 127.0.0.1", "ipvsadm --delete-server --fwmark-service 10001 --real-server 127.0.1.1", "ipvsadm --delete-service --fwmark-service 10001"]
    end
  end
end
