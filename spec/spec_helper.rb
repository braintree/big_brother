ENV['RACK_ENV'] = 'test'

require 'rspec'
require 'rack/test'
require 'big_brother'
require "socket"

Sinatra::Synchrony.patch_tests!

Dir.glob("#{File.expand_path('support', File.dirname(__FILE__))}/**/*.rb").each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec
  config.include Rack::Test::Methods

  config.around(:each) do |spec|
    ipvs = BigBrother.ipvs
    @recording_executor = RecordingExecutor.new
    BigBrother.ipvs = BigBrother::IPVS.new(@recording_executor)
    spec.run
    BigBrother.ipvs = ipvs
  end

  config.before(:each) do
    BigBrother.clusters.replace({})
  end
end

def run_in_reactor
  around(:each) do |spec|
    EM.synchrony do
      spec.run
      EM.stop
    end
  end
end

def with_litmus_server(ip, port, health)
  around(:each) do |spec|
    server = StubServer.new(<<-HTTP, 0.25, port, ip)
HTTP/1.0 200 OK
Connection: close

Health: #{health}
HTTP
    spec.run
    server.stop
  end
end

def public_ip_address
  local_ip = UDPSocket.open {|s| s.connect("64.233.187.99", 1); s.addr.last}
end

TEST_CONFIG = File.expand_path('support/example_config.yml', File.dirname(__FILE__))
