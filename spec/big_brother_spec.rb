require 'spec_helper'

describe BigBrother do
  describe '.configure' do
    it "reads the configuration file" do
      BigBrother.configure(TEST_CONFIG)
      BigBrother.clusters.size.should == 3
    end
  end

  describe '.reconfigure' do
    run_in_reactor
    around(:each) do |spec|
      response_time = 1 #seconds
      server = StubServer.new(<<HTTP, response_time, 9001, '127.0.0.1')
HTTP/1.0 200 OK
Connection: close

Health: 50
HTTP
      spec.run
      server.stop
    end
    it "reconfigures the clusters" do
      config_file = Tempfile.new('config.yml')
      File.open(config_file, 'w') do |f|
        f.puts(<<-EOF)
---
test1:
  checkInterval: 1
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
test1:
  checkInterval: 1
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
    end

    it "stops the ticker and reconfigures after it has finished all its ticks" do
      config_file = Tempfile.new('config.yml')
      File.open(config_file, 'w') do |f|
        f.puts(<<-EOF)
---
test1:
  checkInterval: 1
  scheduler: wrr
  fwmark: 1
  nodes:
  - address: 127.0.0.1
    port: 9001
    path: /test/valid
EOF
      end
      BigBrother.configure(config_file)
      BigBrother.clusters['test1'].start_monitoring!
      @stub_executor.commands.clear

      BigBrother.start_ticker!

      EM::Synchrony.sleep(0.2)

      File.open(config_file, 'w') do |f|
        f.puts(<<-EOF)
---
test1:
  checkInterval: 1
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

      @stub_executor.commands.first.should include("--weight 50")
    end
  end
end
