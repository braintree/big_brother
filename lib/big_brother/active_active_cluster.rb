module BigBrother
  class ActiveActiveCluster < BigBrother::Cluster
    attr_reader :interpol_node, :remote_nodes, :max_down_ticks

    def initialize(name, attributes={})
      super(name, attributes)
      @max_down_ticks = attributes.fetch(:max_down_ticks, 0)
    end

    def start_monitoring!
      BigBrother.logger.info "starting monitoring on cluster #{to_s}"
      BigBrother.ipvs.start_cluster(@fwmark, @scheduler)
      interpol_nodes, local_nodes = @nodes.partition { |node| node.interpol? }
      @nodes = local_nodes

      local_nodes.each do |node|
        BigBrother.ipvs.start_node(@fwmark, node.address, 100)
      end

      @interpol_node = interpol_nodes.first
      @remote_nodes = _fetch_remote_nodes.values
      _monitor_remote_nodes

      @monitored = true
    end

    def monitor_nodes
      super

      fresh_remote_nodes = _fetch_remote_nodes
      remote_nodes.each do |node|
        if new_node = fresh_remote_nodes[node.address]
          BigBrother.ipvs.edit_node(fwmark, node.address, new_node.weight)
          node.weight = new_node.weight
        else
          _adjust_remove_node(node)
        end
      end

      _add_remote_nodes(fresh_remote_nodes.values - remote_nodes)
    end

    def cluster_nodes
      (nodes + remote_nodes).map(&:address)
    end

    def _adjust_remove_node(node)
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
      BigBrother::HealthFetcher.interpol_status(interpol_node).each_with_object({}) do |node, hsh|
        hsh[node['lb_ip_address']] = BigBrother::Node.new(:address => node['lb_ip_address'], :weight => node['health'])
      end
    end

    def _monitor_remote_nodes
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
  end
end
