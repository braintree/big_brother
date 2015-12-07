module BigBrother
  class Cluster
    attr_reader :fwmark, :scheduler, :check_interval, :nodes, :name, :ramp_up_time, :nagios, :backend_mode

    def initialize(name, attributes = {})
      @name = name
      @fwmark = attributes[:fwmark]
      @scheduler = attributes[:scheduler]
      @check_interval = attributes.fetch(:check_interval, 1)
      @monitored = false
      @nodes = attributes.fetch(:nodes, []).map { |node_config| _coerce_node(node_config) }
      @last_check = Time.new(0)
      @up_file = BigBrother::StatusFile.new('up', @name)
      @down_file = BigBrother::StatusFile.new('down', @name)
      @ramp_up_time = attributes.fetch(:ramp_up_time, 60)
      @has_downpage = attributes[:has_downpage]
      @nagios = attributes[:nagios]
      @backend_mode = attributes[:backend_mode]
    end

    def _coerce_node(node_config)
      node_config.is_a?(Node) ? node_config : Node.new(node_config)
    end

    def combined_weight
      nodes.inject(0) { |sum, node| sum + node.weight.to_i }
    end

    def downpage_enabled?
      @downpage_enabled
    end

    def find_node(address, port)
      nodes.find{|node| node.address == address && node.port == port}
    end

    def has_downpage?
      @has_downpage
    end

    def monitored?
      @monitored
    end

    def start_monitoring!
      BigBrother.logger.info "Starting monitoring on cluster #{to_s}"
      BigBrother.ipvs.start_cluster(@fwmark, @scheduler)
      @nodes.each do |node|
        BigBrother.ipvs.start_node(@fwmark, node.address, BigBrother::Node::INITIAL_WEIGHT)
      end

      @monitored = true
    end

    def stop_monitoring!
      BigBrother.logger.info "Stopping monitoring on cluster #{to_s}"
      BigBrother.ipvs.stop_cluster(@fwmark)

      @monitored = false
      @nodes.each(&:invalidate_weight!)
    end

    def resume_monitoring!
      BigBrother.logger.info "Resuming monitoring on cluster #{to_s}"
      @monitored = true
    end

    def synchronize!
      ipvs_state = BigBrother.ipvs.running_configuration
      if ipvs_state.has_key?(fwmark.to_s)
        resume_monitoring!

        running_nodes = ipvs_state[fwmark.to_s]
        _remove_nodes(running_nodes - cluster_nodes)
        _add_nodes(cluster_nodes - running_nodes)
      end
    end

    def cluster_nodes
      nodes.map(&:address)
    end

    def needs_check?
      return false unless monitored?
      @last_check + @check_interval < Time.now
    end

    def monitor_nodes
      @last_check = Time.now
      return unless monitored?
      @nodes.each do |node|
        new_weight = node.monitor(self)
        if new_weight != node.weight
          _update_node(node, new_weight)
          node.weight = new_weight
        end
      end

      _check_downpage if has_downpage?
      _notify_nagios if nagios
    end

    def to_s
      "#{@name} (#{@fwmark})"
    end

    def ==(other)
      fwmark == other.fwmark
    end

    def up_file_exists?
      @up_file.exists?
    end

    def down_file_exists?
      @down_file.exists?
    end

    def incorporate_state(another_cluster)
      nodes.each do |node|
        node.incorporate_state(another_cluster.find_node(node.address, node.port))
      end

      self
    end

    def _add_nodes(addresses)
      addresses.each do |address|
        BigBrother.logger.info "Adding #{address} to cluster #{self}"
        BigBrother.ipvs.start_node(fwmark, address, 0)
      end
    end

    def _add_maintenance_node
      BigBrother.logger.info "Adding downpage to cluster #{self}"
      BigBrother.ipvs.start_node(fwmark, '169.254.254.254', 1)
    end

    def _check_downpage
      total_health = @nodes.collect{ |n| n.weight || 0 }.reduce(:+)
      if total_health <= 0
        _add_maintenance_node unless downpage_enabled?
        @downpage_enabled = true
      else
        _remove_maintenance_node if downpage_enabled?
        @downpage_enabled = false
      end
    end

    def _notify_nagios
      nodes_down = @nodes.count{|n| n.weight == 0}
      return if @last_node_count == nodes_down
      if ((nodes_down / @nodes.count.to_f) >= 0.5)
        BigBrother.nagios.send_critical(nagios[:host], nagios[:check], "50% of nodes are down", nagios[:server])
      elsif nodes_down > 0
        BigBrother.nagios.send_warning(nagios[:host], nagios[:check], "a node is down", nagios[:server])
      else
        BigBrother.nagios.send_ok(nagios[:host], nagios[:check], "all nodes up", nagios[:server])
      end
      @last_node_count = nodes_down
    end

    def _remove_maintenance_node
      BigBrother.ipvs.stop_node(fwmark, '127.0.0.1')
    end

    def _remove_nodes(addresses)
      addresses.each do |address|
        BigBrother.logger.info "Removing #{address} to cluster #{self}"
        BigBrother.ipvs.stop_node(fwmark, address)
      end
    end

    def _update_node(node, new_weight)
      BigBrother.ipvs.edit_node(fwmark, node.address, new_weight)
    end
  end
end
