require 'spec_helper'

describe BigBrother::ActiveActiveCluster do
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

      @stub_executor.commands.should include('ipvsadm --add-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 100')
      @stub_executor.commands.should include('ipvsadm --add-server --fwmark-service 100 --real-server 127.0.0.2 --ipip --weight 100')
      @stub_executor.commands.should_not include('ipvsadm --add-server --fwmark-service 100 --real-server 127.0.0.3 --ipip --weight 100')
    end

    it 'starts all interpol nodes' do
      cluster = Factory.active_active_cluster(
        :fwmark => 100,
        :scheduler => 'wrr',
        :nodes => [
          Factory.node(:interpol => false, :address => '127.0.0.1'),
          Factory.node(:interpol => false, :address => '127.0.0.2'),
          Factory.node(:interpol => true,  :address => '127.0.0.3'),
        ],
      )

      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      cluster.start_monitoring!

      @stub_executor.commands.should include('ipvsadm --add-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 45')
    end
  end

  describe "#monitor_nodes" do
    it "update weight of local ipvs nodes" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([])
      node = Factory.node(:address => '127.0.0.1')
      interpol_node = Factory.node(:address => '172.27.3.1', :interpol => true)
      cluster = Factory.active_active_cluster(:fwmark => 100, :nodes => [node, interpol_node])
      cluster.start_monitoring!
      @stub_executor.commands.clear

      cluster.monitor_nodes
      BigBrother::HealthFetcher.stub(:current_health).and_return(41)
      cluster.monitor_nodes

      @stub_executor.commands.should == [
        "ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56",
        "ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 41"
      ]
    end

    it "update weight of remote nodes" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      node = Factory.node(:address => '127.0.0.1')
      interpol_node = Factory.node(:address => '172.27.3.1', :interpol => true)
      cluster = Factory.active_active_cluster(:fwmark => 100, :nodes => [node, interpol_node])
      cluster.start_monitoring!
      @stub_executor.commands.clear

      cluster.monitor_nodes
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 130,'count' => 2,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 65}])
      cluster.monitor_nodes

      @stub_executor.commands.should == [
        "ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56",
        "ipvsadm --edit-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 45",
        "ipvsadm --edit-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 65"
      ]
    end

    it "update weight of remote not returned to 0" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      node = Factory.node(:address => '127.0.0.1')
      interpol_node = Factory.node(:address => '172.27.3.1', :interpol => true)
      cluster = Factory.active_active_cluster(:fwmark => 100, :nodes => [node, interpol_node], :max_down_ticks => 2)
      cluster.start_monitoring!
      @stub_executor.commands.clear

      cluster.monitor_nodes
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([])
      cluster.monitor_nodes

      @stub_executor.commands.should == [
        "ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56",
        "ipvsadm --edit-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 45",
        "ipvsadm --edit-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 0"
      ]
    end

    it "adds newly discovered remote nodes to ipvs" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      BigBrother::HealthFetcher.stub(:interpol_status).and_return([])
      node = Factory.node(:address => '127.0.0.1')
      interpol_node = Factory.node(:address => '172.27.3.1', :interpol => true)
      cluster = Factory.active_active_cluster(:fwmark => 100, :nodes => [node, interpol_node])
      cluster.start_monitoring!
      cluster.remote_nodes.size.should == 0

      @stub_executor.commands.clear

      BigBrother::HealthFetcher.stub(:interpol_status).and_return([{'aggregated_health' => 90,'count' => 1,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 45}])
      cluster.monitor_nodes

      cluster.remote_nodes.size.should == 1

      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      BigBrother::HealthFetcher.stub(:interpol_status).and_return(
        [
          {'aggregated_health' => 130,'count' => 2,'lb_ip_address' => '172.27.3.1','lb_url' => 'http://172.27.3.1','health' => 65},
          {'aggregated_health' => 100,'count' => 1,'lb_ip_address' => '172.27.3.2','lb_url' => 'http://172.27.3.2','health' => 40},
        ]
      )
      cluster.monitor_nodes

      @stub_executor.commands.should == [
        "ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56",
        "ipvsadm --add-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 45",
        "ipvsadm --edit-server --fwmark-service 100 --real-server 172.27.3.1 --ipip --weight 65",
        "ipvsadm --add-server --fwmark-service 100 --real-server 172.27.3.2 --ipip --weight 40",
      ]
      cluster.remote_nodes.size.should == 2
    end

    it "removes a remote node from ipvs if it has been down for too many ticks" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
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
      cluster.remote_nodes.should be_empty
    end
  end

  describe "#synchronize!" do
    it "does not remove remote nodes" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.0.1', '172.27.1.3']})
      cluster = Factory.active_active_cluster(:fwmark => 1, :nodes => [Factory.node(:address => '127.0.0.1')])
      cluster.stub(:remote_nodes).and_return([Factory.node(:address => '172.27.1.3')])

      cluster.synchronize!

      @stub_executor.commands.should be_empty
    end

    it "does not append remote_nodes to nodes" do
      BigBrother.ipvs.stub(:running_configuration).and_return({'1' => ['127.0.0.1', '172.27.1.3']})
      cluster = Factory.active_active_cluster(:fwmark => 1, :nodes => [Factory.node(:address => '127.0.0.1')])
      cluster.stub(:remote_nodes).and_return([Factory.node(:address => '172.27.1.3')])

      cluster.synchronize!

      cluster.nodes.size.should == 1
    end
  end
end
