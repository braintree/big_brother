module BigBrother
  class ClusterFactory

    ACTIVE_PASSIVE_CLUSTER = 'active_passive'
    ACTIVE_ACTIVE_CLUSTER = 'active_active'

    CLUSTERS = {
      ACTIVE_PASSIVE_CLUSTER => ActivePassiveCluster,
      ACTIVE_ACTIVE_CLUSTER  => ActiveActiveCluster,
    }

    def self.create_cluster(name, attributes)
      CLUSTERS.fetch(attributes[:backend_mode], BigBrother::Cluster).new(name, attributes)
    end
  end
end
