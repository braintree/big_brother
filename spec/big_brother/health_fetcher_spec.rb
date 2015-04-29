require 'spec_helper'

describe BigBrother::HealthFetcher do
  run_in_reactor

  describe "#current_health" do
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

  describe "#interpol_status" do
    it "returns nodes as a list" do
      StubServer.new(<<-HTTP)
HTTP/1.0 200 OK
Connection: close

[{"aggregated_health":0,"count":1,"lb_ip_address":"load1.stq","lb_url":"http://load1.stq:80/lvs.json","health":0}]
HTTP
      BigBrother::HealthFetcher.interpol_status(Factory.node(:address => "127.0.0.1", :port => 8081, :interpol => true, :path => '/fwmark'), 'test').should == [
        {"aggregated_health" => 0,"count" => 1,"lb_ip_address" => "load1.stq","lb_url" => "http://load1.stq:80/lvs.json","health" => 0}
      ]
    end

    it "returns an empty list when HTTP status code is not 200" do
      StubServer.new(<<-HTTP)
HTTP/1.0 503 OK
Connection: close

HTTP
      BigBrother::HealthFetcher.interpol_status(Factory.node(:address => "127.0.0.1", :port => 8081, :interpol => true, :path => '/fwmark'), 'test').should == []
    end

    it "returns an empty list for an unknown service" do
      StubServer.new(<<-HTTP)
HTTP/1.0 503 Service Unavailable
Connection: close
HTTP
      BigBrother::HealthFetcher.interpol_status(Factory.node(:address => "127.0.0.1", :port => 8081, :interpol => true, :path => '/fwmark'), 'test').should == []
    end

    it "returns 0 for an unknown DNS entry" do
      BigBrother::HealthFetcher.interpol_status(Factory.node(:address => "junk.local", :port => 8081, :interpol => true, :path => '/fwmark'), 'test').should == []
    end

    it "returns empty list for an unparseable response body" do
      StubServer.new(<<-HTTP)
HTTP/1.0 200 OK
Connection: close

This part is for people.
HTTP
      BigBrother::HealthFetcher.interpol_status(Factory.node(:address => "127.0.0.1", :port => 8081, :interpol => true, :path => '/fwmark'), 'test').should == []
    end
  end

end
