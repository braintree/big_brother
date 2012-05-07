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
end
