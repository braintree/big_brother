module BigBrother
  class ActivePassiveCluster < Cluster
    attr_reader :interpol_node, :max_down_ticks, :offset, :remote_nodes, :local_nodes, :non_egress_locations

    def initialize(name, attributes={})
      super(name, attributes)
      interpol_nodes, local_nodes = @nodes.partition { |node| node.interpol? }
      @nodes = @local_nodes = local_nodes
      @interpol_node = interpol_nodes.first
      @remote_nodes = []
      @max_down_ticks = attributes.fetch(:max_down_ticks, 0)
      @offset = attributes.fetch(:offset, 10_000)
      @non_egress_locations = *attributes.fetch(:non_egress_locations, [])
    end

    def active_node
      @current_active_node ||= @nodes.sort.first
    end

    def start_monitoring!
      BigBrother.logger.info "Starting monitoring on cluster #{to_s}"
      BigBrother.ipvs.start_cluster(@fwmark, @scheduler)
      BigBrother.ipvs.start_cluster(_relay_fwmark, @scheduler)

      BigBrother.ipvs.start_node(@fwmark, active_node.address, BigBrother::Node::INITIAL_WEIGHT)
      BigBrother.ipvs.start_node(_relay_fwmark, active_node.address, BigBrother::Node::INITIAL_WEIGHT)

      @monitored = true
    end

    def stop_monitoring!
      super
      BigBrother.ipvs.stop_cluster(_relay_fwmark)
    end

    def synchronize!
      ipvs_state = BigBrother.ipvs.running_configuration
      @remote_nodes = _fetch_remote_nodes.values if @remote_nodes == []
      if ipvs_state.has_key?(fwmark.to_s)
        resume_monitoring!

        running_active_node_address = ipvs_state[fwmark.to_s].first
        if running_active_node_address != active_node.address
          BigBrother.ipvs.stop_node(fwmark, running_active_node_address)
          if @local_nodes.map(&:address).include?(running_active_node_address)
            BigBrother.ipvs.stop_node(_relay_fwmark, running_active_node_address)
          end
          BigBrother.ipvs.start_node(fwmark, active_node.address, active_node.weight)
          if @local_nodes.include?(active_node)
            BigBrother.ipvs.start_node(_relay_fwmark, active_node.address, active_node.weight)
          end
        end
      end
    end

    def monitor_nodes
      @last_check = Time.now
      @current_active_node = active_node
      proposed_remote_nodes = _fetch_remote_nodes.values.reject { |node| node.weight.zero? }
      proposed_local_nodes = @nodes.reject do |node|
        weight = node.monitor(self).to_i
        _modify_current_active_node_weight(node, weight)
        node.weight = weight
        node.weight.zero?
      end
      proposed_active_node = (proposed_remote_nodes + proposed_local_nodes).sort.first
      if !proposed_active_node.nil?
        if proposed_active_node == @current_active_node
          _modify_current_active_node_weight(@current_active_node, proposed_active_node.weight)
        elsif proposed_active_node != @current_active_node
          _modify_active_node(@current_active_node, proposed_active_node)
        end
        @current_active_node = proposed_active_node
        @remote_nodes = proposed_remote_nodes
      elsif @remote_nodes.include?(@current_active_node)
        _adjust_or_remove_remote_node(@current_active_node)
      end

      _check_downpage if has_downpage?
      _notify_nagios if nagios
    end

    def incorporate_state(cluster)
      ipvs_state = BigBrother.ipvs.running_configuration
      if ipvs_state[fwmark.to_s] && ipvs_state[_relay_fwmark.to_s].nil?
        BigBrother.logger.info "Adding new remote relay cluster #{to_s}"
        BigBrother.ipvs.start_cluster(_relay_fwmark, @scheduler)
      end

      if ipvs_state[fwmark.to_s] && ipvs_state.fetch(_relay_fwmark.to_s, []).empty? && @local_nodes.include(active_node)
        actual_node = cluster.find_node(active_node.address, active_node.port)
        BigBrother.logger.info "Populating relay cluster with initial active node #{to_s}"
        BigBrother.ipvs.start_node(_relay_fwmark, actual_node.address, actual_node.weight)
      end

      @remote_nodes = cluster.remote_nodes

      super(cluster)
    end

    def stop_relay_fwmark
      nodes.each do |node|
        BigBrother.ipvs.stop_node(_relay_fwmark, node.address)
      end

      BigBrother.ipvs.stop_cluster(_relay_fwmark)
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

    def _relay_fwmark
      fwmark + offset
    end

    def _fetch_remote_nodes
      return {} if interpol_node.nil?

      regular_remote_cluster = BigBrother::HealthFetcher.interpol_status(interpol_node, fwmark)
      relay_remote_cluster = BigBrother::HealthFetcher.interpol_status(interpol_node, _relay_fwmark)

      return {} if regular_remote_cluster.empty? || relay_remote_cluster.empty?

      regular_remote_cluster.each_with_object({}) do |node, hsh|
        next if self.non_egress_locations.include?(node['lb_source_location'])

        hsh[node['lb_ip_address']] = BigBrother::Node.new(:address => node['lb_ip_address'], :weight => node['health'])
      end
    end

    def _adjust_or_remove_remote_node(node)
      if node.down_tick_count >= max_down_ticks
        BigBrother.ipvs.stop_node(fwmark, node.address)
        @remote_nodes.delete(node)
      else
        BigBrother.ipvs.edit_node(fwmark, node.address, 0)
        node.weight = 0
        node.down_tick_count += 1
      end
    end
  end
end
