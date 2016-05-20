require 'forwardable'

module BigBrother
  class ClusterCollection
    extend Forwardable
    def_delegators :@clusters, :[], :[]=, :size, :clear

    def initialize
      @clusters = {}
    end

    def config(new_clusters)
      (@clusters.keys - new_clusters.keys).each do |removed_name|
        @clusters.delete(removed_name).stop_monitoring!
      end

      ipvs_state = BigBrother.ipvs.running_configuration

      new_clusters.each do |cluster_name, cluster|
        if @clusters.key?(cluster_name)
          current_cluster = @clusters[cluster_name]
          current_cluster.stop_relay_fwmark if !current_cluster.is_a?(BigBrother::Cluster) && cluster.is_a?(BigBrother::Cluster)

          @clusters[cluster_name] = cluster.incorporate_state(@clusters[cluster_name])
        else
          @clusters[cluster_name] = cluster

          if ipvs_state.key?(cluster.fwmark.to_s)
            BigBrother.logger.info("resuming previously running cluster from kernel state (#{cluster.fwmark})")
            cluster.start_monitoring!
          end
        end
      end
    end

    def running
      @clusters.values.select(&:monitored?)
    end

    def stopped
      @clusters.values.reject(&:monitored?)
    end

    def ready_for_check
      @clusters.values.select(&:needs_check?)
    end
  end
end
