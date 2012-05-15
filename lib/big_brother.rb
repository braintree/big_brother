require 'async-rack'
require 'sinatra/base'
require 'em-synchrony/em-http'
require 'em/syslog'
require 'thin'
require 'yaml'

require 'sinatra/synchrony'

require 'big_brother/app'
require 'big_brother/cluster'
require 'big_brother/configuration'
require 'big_brother/ipvs'
require 'big_brother/logger'
require 'big_brother/node'
require 'big_brother/shell_executor'
require 'big_brother/status_file'
require 'big_brother/ticker'
require 'big_brother/version'

require 'thin/callbacks'
require 'thin/backends/tcp_server_with_callbacks'
require 'thin/callback_rack_handler'

module BigBrother
  class << self
    attr_accessor :ipvs, :clusters, :config_dir
  end

  self.ipvs = IPVS.new
  self.clusters = {}

  def self.configure(filename)
    @config_file = filename
    @clusters = BigBrother::Configuration.evaluate(filename)
    BigBrother::Configuration.synchronize_with_ipvs(@clusters, BigBrother.ipvs.running_configuration)
  end

  def self.start_ticker!
    Ticker.schedule!
  end

  def self.reconfigure
    Ticker.pause do
      configure(@config_file)
    end
  end
end
