module BigBrother
  class ActiveActiveCluster < BigBrother::Cluster
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

    def start_monitoring!
      BigBrother.logger.info "Starting monitoring on active/active cluster #{to_s}"
      BigBrother.ipvs.start_cluster(@fwmark, @scheduler)
      BigBrother.ipvs.start_cluster(_relay_fwmark, @scheduler)
      local_nodes.each do |node|
        BigBrother.ipvs.start_node(@fwmark, node.address, BigBrother::Node::INITIAL_WEIGHT)
        BigBrother.ipvs.start_node(_relay_fwmark, node.address, BigBrother::Node::INITIAL_WEIGHT)
      end

      _monitor_remote_nodes
      @monitored = true
    end

    def stop_monitoring!
      super
      BigBrother.ipvs.stop_cluster(_relay_fwmark)
    end

    def monitor_nodes
      super

      fresh_remote_nodes = _fetch_remote_nodes
      remote_nodes.each do |node|
        if new_node = fresh_remote_nodes[node.address]
          next if new_node.weight == node.weight
          BigBrother.ipvs.edit_node(fwmark, node.address, new_node.weight)
          node.weight = new_node.weight
        else
          _adjust_or_remove_remote_node(node)
        end
      end

      _add_remote_nodes(fresh_remote_nodes.values - remote_nodes)
    end

    def synchronize!
      ipvs_state = BigBrother.ipvs.running_configuration
      if ipvs_state.has_key?(fwmark.to_s)
        resume_monitoring!

        running_nodes = ipvs_state[fwmark.to_s]
        _remove_nodes(running_nodes - cluster_nodes)
        _add_nodes(cluster_nodes - running_nodes, fwmark)
        _add_nodes(local_cluster_nodes - running_nodes, _relay_fwmark)
      end
    end

    def cluster_nodes
      (nodes + remote_nodes).map(&:address)
    end

    def local_cluster_nodes
      nodes.map(&:address)
    end

    def incorporate_state(cluster)
      ipvs_state = BigBrother.ipvs.running_configuration
      if ipvs_state[fwmark.to_s] && ipvs_state[_relay_fwmark.to_s].nil?
        BigBrother.logger.info "Adding new active/active LB node #{to_s}"
        BigBrother.ipvs.start_cluster(_relay_fwmark, @scheduler)
      end

      if ipvs_state[fwmark.to_s] && ipvs_state.fetch(_relay_fwmark.to_s, []).empty?
        nodes.each do |node|
          actual_node = cluster.find_node(node.address, node.port)
          BigBrother.ipvs.start_node(_relay_fwmark, actual_node.address, actual_node.weight)
        end
      end

      BigBrother.logger.info "Merging in new active/active cluster #{to_s}"
      super(cluster)
    end

    def stop_relay_fwmark
      nodes.each do |node|
        BigBrother.ipvs.stop_node(_relay_fwmark, node.address)
      end

      BigBrother.ipvs.stop_cluster(_relay_fwmark)
    end

    def _relay_fwmark
      fwmark + offset
    end

    def _add_nodes(addresses, fwmark)
      addresses.each do |address|
        BigBrother.logger.info "Adding #{address} to active/active cluster #{self}"
        BigBrother.ipvs.start_node(fwmark, address, 0)
      end
    end

    def _adjust_or_remove_remote_node(node)
      if node.down_tick_count >= max_down_ticks
        BigBrother.ipvs.stop_node(fwmark, node.address)
        remote_nodes.delete(node)
      else
        BigBrother.ipvs.edit_node(fwmark, node.address, 0)
        node.weight = 0
        node.down_tick_count += 1
      end
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

    def _monitor_remote_nodes
      @remote_nodes = _fetch_remote_nodes.values
      remote_nodes.each do |node|
        BigBrother.ipvs.start_node(fwmark, node.address, node.weight)
      end
    end

    def _add_remote_nodes(nodes)
      nodes.each do |node|
        BigBrother.ipvs.start_node(fwmark, node.address, node.weight)
        @remote_nodes << node
      end
    end

    def _remove_nodes(addresses)
      addresses.each do |address|
        BigBrother.logger.info "Removing #{address} from active/active cluster #{self}"
        BigBrother.ipvs.stop_node(fwmark, address)
        BigBrother.ipvs.stop_node(_relay_fwmark, address)
      end
    end

    def _update_node(node, new_weight)
      BigBrother.ipvs.edit_node(fwmark, node.address, new_weight)
      BigBrother.ipvs.edit_node(_relay_fwmark, node.address, new_weight)
    end
  end
end
