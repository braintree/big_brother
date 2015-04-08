module BigBrother
  class ActivePassiveCluster < Cluster

    def start_monitoring!
      BigBrother.logger.info "starting monitoring on cluster #{to_s}"
      BigBrother.ipvs.start_cluster(@fwmark, @scheduler)
      BigBrother.ipvs.start_node(@fwmark, active_node.address, 100)

      @monitored = true
    end

    def active_node
      @current_active_node ||= @nodes.sort.first
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
      @current_active_node = active_node
      proposed_active_node = @nodes.reject do |node|
        weight = node.monitor(self).to_i
        _modify_current_active_node_weight(node, weight)
        node.weight = weight
        node.weight.zero?
      end.sort.first

      if proposed_active_node != @current_active_node && !proposed_active_node.nil?
        _modify_active_node(@current_active_node, proposed_active_node)
        @current_active_node = proposed_active_node
      end

      _check_downpage if has_downpage?
      _notify_nagios if nagios
    end

    def _modify_current_active_node_weight(node, weight)
      return unless node == @current_active_node
      if @current_active_node.weight != weight
        BigBrother.ipvs.edit_node(fwmark, @current_active_node.address, weight)
        @current_active_node.weight = weight
      end
    end

    def _modify_active_node(current_active_node, proposed_active_node)
      BigBrother.ipvs.stop_node(fwmark, current_active_node.address)
      BigBrother.ipvs.start_node(fwmark, proposed_active_node.address, proposed_active_node.weight)
    end
  end
end
