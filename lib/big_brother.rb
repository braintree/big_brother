require 'sinatra/base'
require 'sinatra/synchrony'
require 'em-synchrony/em-http'

require 'big_brother/app'
require 'big_brother/cluster'
require 'big_brother/configuration'
require 'big_brother/ipvs'
require 'big_brother/node'
require 'big_brother/shell_executor'
require 'big_brother/status_file'
require 'big_brother/ticker'
require 'big_brother/version'

module BigBrother
  class << self
    attr_accessor :ipvs, :clusters, :config_dir
  end

  self.ipvs = IPVS.new
  self.clusters = {}

  def self.configure(filename)
    @clusters = BigBrother::Configuration.evaluate(filename)
  end

  def self.start_ticker!
    Ticker.schedule!
  end
end
