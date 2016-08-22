module BigBrother
  class ClusterFactory

    ACTIVE_PASSIVE_CLUSTER = 'active_passive'
    ACTIVE_ACTIVE_CLUSTER = 'active_active'

    def self.create_cluster(name, attributes)
      Cluster.new(name, attributes)
    end
  end
end
