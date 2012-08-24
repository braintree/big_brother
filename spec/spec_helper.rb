ENV['RACK_ENV'] = 'test'

require 'rspec'
require 'rack/test'
require 'big_brother'
require "socket"

Dir.glob("#{File.expand_path('support', File.dirname(__FILE__))}/**/*.rb").each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec
  config.include Rack::Test::Methods

  config.around(:each) do |spec|
    ipvs = BigBrother.ipvs
    @stub_executor = StubExecutor.new
    BigBrother.ipvs = BigBrother::IPVS.new(@stub_executor)
    BigBrother.nagios = BigBrother::Nagios.new(@stub_executor)
    spec.run
    BigBrother.ipvs = ipvs
  end

  config.before(:each) do
    BigBrother.clusters.clear
    FileUtils.rm_rf(BigBrother.config_dir)
    BigBrother.logger = NullLogger.new
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

BigBrother.config_dir = "/tmp/big_brother"

TEST_CONFIG = File.expand_path('support/example_config.yml', File.dirname(__FILE__))
