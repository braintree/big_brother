require 'spec_helper'

describe BigBrother::Node do
  describe "#current_health" do
    run_in_reactor

    it "returns its health" do
      StubServer.new(<<-HTTP, 0.25)
HTTP/1.0 200 OK
Connection: close

Health: 59
HTTP
      node = BigBrother::Node.new("127.0.0.1", 8081, "/test/status")
      node.current_health.should == 59
    end

    it "returns 0 for an unknown service" do
      StubServer.new(<<-HTTP, 0.25)
HTTP/1.0 503 Service Unavailable
Connection: close
HTTP
      node = BigBrother::Node.new("127.0.0.1", 8081, "/test/status")
      node.current_health.should == 0
    end

    it "returns 0 for an unknown DNS entry" do
      node = BigBrother::Node.new("junk.local", 8081, "/test/status")
      node.current_health.should == 0
    end

    it "returns the health if it is passed in a header" do
      StubServer.new(<<-HTTP, 0.25)
HTTP/1.0 200 OK
Connection: close
X-Health: 61

This part is for people.
HTTP
      node = BigBrother::Node.new("127.0.0.1", 8081, "/test/status")
      node.current_health.should == 61
    end
  end

  describe "#monitor" do
    it "updates the weight for the node" do
      node = Factory.node(:address => '127.0.0.1')
      node.should_receive(:current_health).and_return(56)
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])

      node.monitor(cluster)

      @recording_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 56")
    end

    it "sets the weight to 100 for each node if an up file exists" do
      node = Factory.node(:address => '127.0.0.1')
      node.stub(:current_health).and_return(56)
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])

      BigBrother::StatusFile.new('up', 'test').create('Up for testing')

      node.monitor(cluster)

      @recording_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 100")
    end

    it "sets the weight to 0 for each node if a down file exists" do
      node = Factory.node(:address => '127.0.0.1')
      node.stub(:current_health).and_return(56)
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])

      BigBrother::StatusFile.new('down', 'test').create('Down for testing')

      node.monitor(cluster)

      @recording_executor.commands.should include("ipvsadm --edit-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 0")
    end
  end
end
