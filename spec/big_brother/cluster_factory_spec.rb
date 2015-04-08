require 'spec_helper'

describe BigBrother::ClusterFactory do
  describe '.create_cluster' do
    it 'creates a normal cluster' do
      cluster = BigBrother::ClusterFactory.create_cluster('foo', :fwmark => 100)

      cluster.should be_an_instance_of BigBrother::Cluster
    end

    it 'creates an active_passive cluster' do
      cluster = BigBrother::ClusterFactory.create_cluster('foo', :fwmark => 100, :backend_mode => 'active_passive')

      cluster.should be_an_instance_of BigBrother::ActivePassiveCluster
    end

    it 'creates an active_active cluster' do
      cluster = BigBrother::ClusterFactory.create_cluster('foo', :fwmark => 100, :backend_mode => 'active_active')

      cluster.should be_an_instance_of BigBrother::ActiveActiveCluster
    end
  end
end
