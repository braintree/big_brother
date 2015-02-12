module BigBrother
  class ActivePassiveCluster < Cluster
    attr_reader :fwmark, :scheduler, :check_interval, :nodes, :name, :ramp_up_time, :nagios, :backend_mode

    def start_monitoring!
      BigBrother.logger.info "starting monitoring on cluster #{to_s}"
      BigBrother.ipvs.start_cluster(@fwmark, @scheduler)
      BigBrother.ipvs.start_node(@fwmark, active_node.address, 100)

      @monitored = true
    end

    def active_node
      @nodes.sort.first
    end

    def synchronize!
      ipvs_state = BigBrother.ipvs.running_configuration
      if ipvs_state.has_key?(fwmark.to_s)
        resume_monitoring!

        running_active_node_address = ipvs_state[fwmark.to_s].first
        if running_active_node_address != active_node.address
          BigBrother.ipvs.stop_node(fwmark, running_active_node_address)
          BigBrother.ipvs.start_node(fwmark, active_node.address, active_node.weight)
        end
      end
    end

    def monitor_nodes
      @last_check = Time.now
      current_active_node = active_node
      proposed_active_node = @nodes.reject do |node|
        node.weight = node.monitor(self)
        node.weight.zero?
      end.sort.first

      _modify_active_node(current_active_node, proposed_active_node) if current_active_node != proposed_active_node
      _check_downpage if has_downpage?
      _notify_nagios if nagios
    end

    def _modify_active_node(current_active_node, proposed_active_node)
      BigBrother.ipvs.stop_node(fwmark, current_active_node.address)
      BigBrother.ipvs.start_node(fwmark, proposed_active_node.address, proposed_active_node.weight)
    end
  end
end
