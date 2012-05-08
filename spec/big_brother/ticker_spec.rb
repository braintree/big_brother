require 'spec_helper'

describe BigBrother::Ticker do
  describe ".schedule!" do
    it "schedules the ticker to run ten times every second" do
      EventMachine.should_receive(:add_periodic_timer).with(0.1)

      BigBrother::Ticker.schedule!
    end
  end

  describe ".tick" do
    it "monitors clusters requiring monitoring" do
      BigBrother.clusters['one'] = Factory.cluster
      BigBrother.clusters['two'] = Factory.cluster
      BigBrother.clusters['two'].start_monitoring!

      BigBrother.clusters['two'].should_receive(:monitor_nodes)

      BigBrother::Ticker.tick
    end
  end
end
