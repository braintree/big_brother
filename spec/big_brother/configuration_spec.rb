require 'spec_helper'

describe BigBrother::Configuration do
  describe '.evaluate' do
    it 'returns a hash of clusters' do
      clusters = BigBrother::Configuration.evaluate(TEST_CONFIG)

      clusters['test1'].check_interval.should == 1
      clusters['test1'].scheduler.should == 'wrr'
      clusters['test1'].fwmark.should == 1

      clusters['test2'].check_interval.should == 1
      clusters['test2'].scheduler.should == 'wrr'
      clusters['test2'].fwmark.should == 2

      clusters['test3'].check_interval.should == 1
      clusters['test3'].scheduler.should == 'wrr'
      clusters['test3'].fwmark.should == 3
    end

    it 'populates a clusters nodes' do
      clusters = BigBrother::Configuration.evaluate(TEST_CONFIG)

      clusters['test1'].nodes.length.should == 2

      clusters['test1'].nodes[0].address == '127.0.0.1'
      clusters['test1'].nodes[0].port == '9001'
      clusters['test1'].nodes[0].path == '/test/valid'

      clusters['test1'].nodes[1].address == '127.0.0.1'
      clusters['test1'].nodes[1].port == '9002'
      clusters['test1'].nodes[1].path == '/test/valid'
    end
  end

  describe '.synchronize_with_ipvs' do
    it "monitors clusters that were already monitored" do
      clusters = {}
      clusters['one'] = Factory.cluster(:fwmark => 1)
      clusters['two'] = Factory.cluster(:fwmark => 2)
      clusters['three'] = Factory.cluster(:fwmark => 3)

      ipvs_state = {}
      ipvs_state['1'] = ['127.0.0.1']
      ipvs_state['3'] = ['127.0.0.1']

      BigBrother::Configuration.synchronize_with_ipvs(clusters, ipvs_state)

      clusters['one'].should be_monitored
      clusters['two'].should_not be_monitored
      clusters['three'].should be_monitored
    end

    it "does not attempt to re-add the services it was monitoring" do
      clusters = { 'one' => Factory.cluster(:fwmark => 1, :nodes => [Factory.node(:address => '127.0.0.1')]) }
      ipvs_state = { '1' => ['127.0.0.1'] }

      BigBrother::Configuration.synchronize_with_ipvs(clusters, ipvs_state)

      @recording_executor.commands.should be_empty
    end

    it "removes nodes that are no longer part of the cluster" do
      clusters = { 'one' => Factory.cluster(:fwmark => 1, :nodes => [Factory.node(:address => '127.0.0.1')]) }
      ipvs_state = { '1' => ['127.0.1.1', '127.0.0.1'] }

      BigBrother::Configuration.synchronize_with_ipvs(clusters, ipvs_state)

      @recording_executor.commands.last.should == "ipvsadm --delete-server --fwmark-service 1 --real-server 127.0.1.1"
    end

    it "adds new nodes to the cluster" do
      clusters = { 'one' => Factory.cluster(:fwmark => 1, :nodes => [Factory.node(:address => '127.0.0.1'), Factory.node(:address => "127.0.1.1")]) }
      ipvs_state = { '1' => ['127.0.0.1'] }

      BigBrother::Configuration.synchronize_with_ipvs(clusters, ipvs_state)

      @recording_executor.commands.should include("ipvsadm --add-server --fwmark-service 1 --real-server 127.0.1.1 --ipip --weight 100")
    end

    it "will remove clusters that are no longer configured" do
      clusters = { 'two' => Factory.cluster(:fwmark => 2) }
      ipvs_state = { '1' => ['127.0.0.1'] }

      BigBrother::Configuration.synchronize_with_ipvs(clusters, ipvs_state)

      @recording_executor.commands.should include("ipvsadm --delete-service --fwmark-service 1")
    end
  end
end
