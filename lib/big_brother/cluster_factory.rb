module BigBrother
  class ClusterFactory

    ACTIVE_PASSIVE_CLUSTER = 'active_passive'

    CLUSTERS = {
      ACTIVE_PASSIVE_CLUSTER => ActivePassiveCluster,
    }

    def self.create_cluster(name, attributes)
      CLUSTERS.fetch(attributes[:backend_mode], BigBrother::Cluster).new(name, attributes)
    end
  end
end
