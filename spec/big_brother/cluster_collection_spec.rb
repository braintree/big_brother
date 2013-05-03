require 'spec_helper'

describe BigBrother::ClusterCollection do
  describe "config" do
    it "adds the provided clusters into its collection" do
      clusters_from_config = {
        'test1' => Factory.cluster(:name => 'test1', :fwmark => 101),
        'test2' => Factory.cluster(:name => 'test2', :fwmark => 102),
        'test3' => Factory.cluster(:name => 'test3', :fwmark => 103)
      }
      collection = BigBrother::ClusterCollection.new

      collection.config(clusters_from_config)

      collection['test1'].should == clusters_from_config['test1']
      collection['test2'].should == clusters_from_config['test2']
      collection['test3'].should == clusters_from_config['test3']
    end

    it "incorporates the state of clusters that exist" do
      collection = BigBrother::ClusterCollection.new

      collection['existing_cluster'] = Factory.cluster(:name => 'existing_cluster')

      cluster_from_config = Factory.cluster(:name => 'existing_cluster')
      cluster_from_config.should_receive(:incorporate_state).with(collection['existing_cluster'])

      collection.config({'existing_cluster' => cluster_from_config})
    end

    it "stops and removes clusters not included in the next configuration" do
      test2 = Factory.cluster(:name => 'test2', :fwmark => 102)
      collection = BigBrother::ClusterCollection.new
      collection.config({
        'test1' => Factory.cluster(:name => 'test1', :fwmark => 101),
        'test2' => test2,
        'test3' => Factory.cluster(:name => 'test3', :fwmark => 103)
      })

      test2.should_receive(:stop_monitoring!)
      collection.config({
        'test1' => Factory.cluster(:name => 'test1', :fwmark => 101),
        'test3' => Factory.cluster(:name => 'test3', :fwmark => 103)
      })
      collection['test2'].should be_nil
    end
  end

  describe "running" do
    it "returns the clusters in the collection that are currently running" do
      clusters_from_config = {
        'test1' => Factory.cluster(:name => 'test1', :fwmark => 101),
        'test2' => Factory.cluster(:name => 'test2', :fwmark => 102),
        'test3' => Factory.cluster(:name => 'test3', :fwmark => 103)
      }
      collection = BigBrother::ClusterCollection.new

      collection.config(clusters_from_config)
      clusters_from_config['test1'].start_monitoring!
      clusters_from_config['test2'].start_monitoring!

      collection.running.should == [clusters_from_config['test1'], clusters_from_config['test2']]
    end
  end

  describe "stopped" do
    it "returns the clusters in the collection that are not running" do
      clusters_from_config = {
        'test1' => Factory.cluster(:name => 'test1', :fwmark => 101),
        'test2' => Factory.cluster(:name => 'test2', :fwmark => 102),
        'test3' => Factory.cluster(:name => 'test3', :fwmark => 103)
      }
      collection = BigBrother::ClusterCollection.new

      collection.config(clusters_from_config)
      clusters_from_config['test1'].start_monitoring!
      clusters_from_config['test2'].start_monitoring!

      collection.stopped.should == [clusters_from_config['test3']]
    end
  end

  describe "ready_for_check" do
    it "returns the clusters in the collection that need checking" do
      clusters_from_config = {
        'test1' => Factory.cluster(:name => 'test1', :fwmark => 101),
        'test2' => Factory.cluster(:name => 'test2', :fwmark => 102),
        'test3' => Factory.cluster(:name => 'test3', :fwmark => 103)
      }
      collection = BigBrother::ClusterCollection.new

      collection.config(clusters_from_config)
      clusters_from_config['test1'].stub(:needs_check?).and_return(true)
      clusters_from_config['test2'].stub(:needs_check?).and_return(true)
      clusters_from_config['test3'].stub(:needs_check?).and_return(false)

      collection.ready_for_check.should == [clusters_from_config['test1'], clusters_from_config['test2']]
    end
  end
end
