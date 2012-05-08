ENV['RACK_ENV'] = 'test'

require 'rspec'
require 'rack/test'
require 'big_brother'

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
