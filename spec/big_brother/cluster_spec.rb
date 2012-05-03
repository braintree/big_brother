require 'spec_helper'

describe BigBrother::Cluster do
  describe "monitor!" do
    it "marks the cluster as monitored" do
      cluster = BigBrother::Cluster.new('test')
      cluster.should_not be_monitored
      cluster.monitor!
      cluster.should be_monitored
    end
  end
end
