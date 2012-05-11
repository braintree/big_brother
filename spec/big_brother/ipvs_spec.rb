require 'spec_helper'

describe BigBrother::IPVS do
  describe "#running_configuration" do
    it "returns a parsed version of the running config" do
      playback = PlaybackExecutor.new
      playback.add_response(<<-OUTPUT, 0)
-A -f 3 -s wrr
-a -f 3 -r 10.0.1.220:80 -i -w 1
-a -f 3 -r 10.0.1.221:80 -i -w 1
-a -f 3 -r 10.0.1.222:80 -i -w 1
-A -f 1 -s wrr
-a -f 1 -r 10.0.1.223:80 -i -w 1
-a -f 1 -r 10.0.1.224:80 -i -w 1
-A -f 2 -s wrr
-a -f 2 -r 10.0.1.225:80 -i -w 1
      OUTPUT
      config = BigBrother::IPVS.new(playback).running_configuration

      config.size.should == 3
      config['3'].should == ['10.0.1.220', '10.0.1.221', '10.0.1.222']
      config['1'].should == ['10.0.1.223', '10.0.1.224']
      config['2'].should == ['10.0.1.225']
    end
  end
end
