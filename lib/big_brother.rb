require 'async-rack'
require 'sinatra/base'
require 'em-synchrony/em-http'
require 'em/syslog'
require 'thin'
require 'yaml'

require 'sinatra/synchrony'

require 'big_brother/app'
require 'big_brother/cluster'
require 'big_brother/active_passive_cluster'
require 'big_brother/cluster_factory'
require 'big_brother/cluster_collection'
require 'big_brother/configuration'
require 'big_brother/health_fetcher'
require 'big_brother/ipvs'
require 'big_brother/logger'
require 'big_brother/nagios'
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
    attr_accessor :ipvs, :nagios, :clusters, :config_dir, :logger
  end

  self.ipvs = IPVS.new
  self.nagios = Nagios.new
  self.clusters = BigBrother::ClusterCollection.new
  self.logger = BigBrother::Logger.new

  def self.configure(filename)
    @config_file = filename
    @clusters.config(BigBrother::Configuration.from_file(filename))
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
