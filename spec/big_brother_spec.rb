require 'spec_helper'

describe BigBrother do
  describe '.configure' do
    it "reads the configuration file" do
      BigBrother.configure(TEST_CONFIG)
      BigBrother.clusters.size.should == 3
    end

    it "synchronizes the configuration with the current state of IPVS" do
      playback = PlaybackExecutor.new
      playback.add_response(<<-OUTPUT, 0)
-A -f 1 -s wrr
-a -f 1 -r 10.0.1.223:80 -i -w 1
-a -f 1 -r 10.0.1.224:80 -i -w 1
-A -f 2 -s wrr
-a -f 2 -r 10.0.1.225:80 -i -w 1
      OUTPUT
      BigBrother.ipvs = BigBrother::IPVS.new(playback)
      BigBrother.configure(TEST_CONFIG)

      BigBrother.clusters['test1'].should be_monitored
      BigBrother.clusters['test2'].should be_monitored
    end
  end
end
