$LOAD_PATH.unshift File.expand_path('lib', File.dirname(__FILE__))
require 'big_brother'

use Rack::CommonLogger, BigBrother::Logger.new
run BigBrother::App
