ENV['RACK_ENV'] = 'test'

require 'rspec'
require 'rack/test'
require 'big_brother'

Sinatra::Synchrony.patch_tests!

Dir.glob("#{File.expand_path('support', File.dirname(__FILE__))}/**/*.rb").each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec
  config.include Rack::Test::Methods

  config.before(:each) do
    BigBrother.clusters.replace({})
  end
end
