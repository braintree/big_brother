require 'spec_helper'

describe BigBrother::Logger do
  describe 'level' do
    it "does not log debug at info level" do
      logger = BigBrother::Logger.new
      logger.level = BigBrother::Logger::Level::INFO

      EM.should_receive(:debug).never

      logger.debug('hi')
    end
  end
end
