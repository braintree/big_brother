require 'spec_helper'

describe BigBrother::HealthFetcher do
  describe "#current_health" do
    run_in_reactor

    it "returns its health" do
      StubServer.new(<<-HTTP)
HTTP/1.0 200 OK
Connection: close

Health: 59
HTTP
      BigBrother::HealthFetcher.current_health("127.0.0.1", 8081, "/test/status").should == 59
    end

    it "returns 0 when the HTTP status code is not 200" do
      StubServer.new(<<-HTTP)
HTTP/1.0 503 OK
Connection: close

Health: 19
HTTP
      BigBrother::HealthFetcher.current_health("127.0.0.1", 8081, "/test/status").should == 0
    end

    it "returns 0 for an unknown service" do
      StubServer.new(<<-HTTP)
HTTP/1.0 503 Service Unavailable
Connection: close
HTTP
      BigBrother::HealthFetcher.current_health("127.0.0.1", 8081, "/test/status").should == 0
    end

    it "returns 0 for an unknown DNS entry" do
      BigBrother::HealthFetcher.current_health("junk.local", 8081, "/test/status").should == 0
    end

    it "returns the health if it is passed in a header" do
      StubServer.new(<<-HTTP)
HTTP/1.0 200 OK
Connection: close
X-Health: 61

This part is for people.
HTTP
      BigBrother::HealthFetcher.current_health("127.0.0.1", 8081, "/test/status").should == 61
    end
  end

end
