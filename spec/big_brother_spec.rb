require 'spec_helper'

describe BigBrother do
  describe '.monitor_nodes' do
    it "updates the weight for all the nodes in a cluster" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(76)
      node1 = Factory.node(:address => '127.0.0.1', :weight => 90)
      node2 = Factory.node(:address => '127.0.0.2', :weight => 30)
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node1, node2])
      cluster.start_monitoring!
      @stub_executor.commands.clear

      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      cluster.monitor_nodes

      cluster.nodes.map(&:weight).uniq.should == [56]
      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56")
      @stub_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.2 --ipip --weight 56")
    end

  end

  describe '.configure' do
    it "reads the configuration file" do
      BigBrother.configure(TEST_CONFIG)
      BigBrother.clusters.size.should == 4
    end
  end

  describe '.reconfigure' do
    run_in_reactor
    around(:each) do |spec|
      response_time = 1 #seconds
      server1 = StubServer.new(<<HTTP, response_time, 9001, '127.0.0.1')
HTTP/1.0 200 OK
Connection: close

Health: 50
HTTP
      server2 = StubServer.new(<<HTTP, response_time, 9002, '127.0.0.1')
HTTP/1.0 200 OK
Connection: close

Health: 99
HTTP

      spec.run
      server1.stop
      server2.stop
    end

    it "reconfigures the clusters" do
      config_file = Tempfile.new('config.yml')
      File.open(config_file, 'w') do |f|
        f.puts(<<-EOF)
---
clusters:
  - cluster_name: test1
    check_interval: 1
    scheduler: wrr
    fwmark: 1
    nodes:
      - address: 127.0.0.1
        port: 9001
        path: /test/valid
EOF
      end
      BigBrother.configure(config_file)
      BigBrother.start_ticker!
      BigBrother.clusters['test1'].nodes.first.path.should == "/test/valid"

      File.open(config_file, 'w') do |f|
        f.puts(<<-EOF)
---
clusters:
  - cluster_name: test1
    check_interval: 1
    scheduler: wrr
    backend_mode: 'active_active'
    fwmark: 1
    nodes:
      - address: 127.0.0.1
        port: 9001
        path: /test/another/path
      - address: 127.0.0.9
        port: 9000
        path: /fwmark
        interpol: true
EOF
      end
      BigBrother.reconfigure
      BigBrother.clusters['test1'].class.should == BigBrother::ActiveActiveCluster
      BigBrother.clusters['test1'].nodes.first.path.should == "/test/another/path"
    end

    it "maintains the start_time and weight of existing nodes after reconfiguring" do
      Time.stub(:now).and_return(Time.at(1345043600))
      config_file = Tempfile.new('config.yml')
      File.open(config_file, 'w') do |f|
        f.puts(<<-EOF)
---
clusters:
  - cluster_name: test1
    check_interval: 1
    scheduler: wrr
    fwmark: 1
    nodes:
      - address: 127.0.0.1
        port: 9001
        path: /test/valid
EOF
      end
      BigBrother.configure(config_file)
      BigBrother.start_ticker!

      Time.stub(:now).and_return(Time.at(1345043700))
      start_time = BigBrother.clusters['test1'].nodes[0].start_time
      weight = BigBrother.clusters['test1'].nodes[0].weight

      File.open(config_file, 'w') do |f|
        f.puts(<<-EOF)
---
clusters:
  - cluster_name: test1
    check_interval: 1
    scheduler: wrr
    fwmark: 1
    nodes:
      - address: 127.0.0.1
        port: 9001
        path: /test/valid
      - address: 127.0.0.2
        port: 9001
        path: /test/valid
EOF
      end
      BigBrother.reconfigure
      BigBrother.clusters['test1'].nodes[0].start_time.should == start_time
      BigBrother.clusters['test1'].nodes[0].weight.should == weight
      BigBrother.clusters['test1'].nodes[1].start_time.should == 1345043700
      BigBrother.clusters['test1'].nodes[1].weight.should be_nil
    end

    it "stops the ticker and reconfigures after it has finished all its ticks" do
      config_file = Tempfile.new('config.yml')
      File.open(config_file, 'w') do |f|
        f.puts(<<-EOF)
---
clusters:
  - cluster_name: test1
    check_interval: 1
    scheduler: wrr
    fwmark: 1
    ramp_up_time: 0
    nodes:
      - address: 127.0.0.1
        port: 9001
        path: /test/valid
EOF
      end
      BigBrother.configure(config_file)
      BigBrother.clusters['test1'].start_monitoring!

      BigBrother.start_ticker!

      EM::Synchrony.sleep(0.2)

      File.open(config_file, 'w') do |f|
        f.puts(<<-EOF)
---
clusters:
  - cluster_name: test1
    check_interval: 1
    scheduler: wrr
    fwmark: 1
    nodes:
      - address: 127.0.0.1
        port: 9001
        path: /test/another/path
EOF
      end
      BigBrother.reconfigure
      BigBrother.clusters['test1'].nodes.first.path.should == "/test/another/path"
      BigBrother.clusters['test1'].nodes.first.weight.should == 50
    end
  end
end
