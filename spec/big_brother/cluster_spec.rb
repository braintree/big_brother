require 'spec_helper'

describe BigBrother::Cluster do
  describe "start_monitoring!" do
    it "marks the cluster as monitored" do
      cluster = BigBrother::Cluster.new('test')
      cluster.should_not be_monitored
      cluster.start_monitoring!
      cluster.should be_monitored
    end
  end

  describe "stop_monitoring!" do
    it "marks the cluster as unmonitored" do
      cluster = BigBrother::Cluster.new('test')
      cluster.start_monitoring!
      cluster.should be_monitored
      cluster.stop_monitoring!
      cluster.should_not be_monitored
    end
  end

  describe "monitor_nodes" do
    it "marks the cluster as no longer requiring monitoring" do
      cluster = BigBrother::Cluster.new('test')
      cluster.needs_check?.should be_true
      cluster.monitor_nodes
      cluster.needs_check?.should be_false
    end
  end
end
