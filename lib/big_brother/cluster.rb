module BigBrother
  class Cluster
    module Type
      ActiveActive = "active_active"
      ActivePassive = "active_passive"
      Default = ActiveActive
    end

    attr_reader :backend_mode, :check_interval, :fwmark, :interpol_nodes, :local_nodes, :max_down_ticks, :monitored, :multi_datacenter, :nagios, :name, :nodes, :non_egress_locations, :offset, :ramp_up_time, :remote_nodes, :scheduler

    def initialize(name, attributes = {})
      @name = name
      @fwmark = attributes[:fwmark]
      @cluster_mode = @backend_mode = attributes.fetch(:backend_mode, Type::Default)
      @multi_datacenter = attributes.fetch(:multi_datacenter, @cluster_mode == Type::ActiveActive)
      @scheduler = attributes[:scheduler]
      @check_interval = attributes.fetch(:check_interval, 1)
      @monitored = false

      nodes = attributes.fetch(:nodes, []).map { |node_config| _coerce_node(node_config) }
      interpol_nodes, local_nodes = nodes.partition { |node| node.interpol? }
      @nodes = @local_nodes = local_nodes
      @interpol_nodes = interpol_nodes
      @remote_nodes = []

      @max_down_ticks = attributes.fetch(:max_down_ticks, 0)
      @offset = attributes.fetch(:offset, 10_000)
      @non_egress_locations = *attributes.fetch(:non_egress_locations, [])
      @last_check = Time.new(0)
      @up_file = BigBrother::StatusFile.new('up', @name)
      @down_file = BigBrother::StatusFile.new('down', @name)
      @ramp_up_time = attributes.fetch(:ramp_up_time, 60)
      @has_downpage = attributes[:has_downpage]
      if @has_downpage == false
        @downpage_enabled = false
      end
      @nagios = attributes[:nagios]
    end

    def active_passive?
      @cluster_mode == Type::ActivePassive
    end

    def active_active?
      @cluster_mode == Type::ActiveActive
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
      ## NOTE: We set the node weights to match the initial IPVS weight, to ensure node weights will be updated
      ## correctly with the measured health on the next round of monitoring. By design, we have decided it
      ## is preferable to temporarily misdirect to a backend that may be down than wait for initial health
      ## checks to complete.

      BigBrother.logger.info "Starting monitoring on #{@cluster_mode} cluster #{to_s}"
      BigBrother.ipvs.start_cluster(@fwmark, @scheduler)

      if @multi_datacenter
        BigBrother.ipvs.start_cluster(_relay_fwmark, @scheduler)
      end

      _active_nodes.each do |node|
        BigBrother.ipvs.start_node(@fwmark, node.address, BigBrother::Node::INITIAL_WEIGHT)

        if @multi_datacenter
          BigBrother.ipvs.start_node(_relay_fwmark, node.address, BigBrother::Node::INITIAL_WEIGHT)
        end

        node.initialize_weight!
      end

      @remote_nodes.each do |node|
        BigBrother.ipvs.start_node(@fwmark, node.address, BigBrother::Node::INITIAL_WEIGHT)

        node.initialize_weight!
      end

      @monitored = true
    end

    def _active_nodes
      if active_passive?
        [@current_active_node ||= @nodes.sort.first]
      else
        @local_nodes
      end
    end

    def active_node
      if !active_passive?
        throw "There is only an active node in active/passive clusters!"
      end

      _active_nodes.first
    end

    def stop_monitoring!
      BigBrother.logger.info "Stopping monitoring on cluster #{to_s}"
      BigBrother.ipvs.stop_cluster(@fwmark)

      if @multi_datacenter
        BigBrother.ipvs.stop_cluster(_relay_fwmark)
      end

      @monitored = false
      @nodes.each(&:invalidate_weight!)
    end

    def resume_monitoring!
      BigBrother.logger.info "Resuming monitoring on cluster #{to_s}"
      @monitored = true
    end

    def synchronize!
      ipvs_state = BigBrother.ipvs.running_configuration

      if @multi_datacenter
        @remote_nodes = _fetch_remote_nodes.values if @remote_nodes == []
      end

      if ipvs_state.has_key?(fwmark.to_s)
        resume_monitoring!

        running_nodes = ipvs_state[fwmark.to_s]

        if active_passive?
          running_active_node_address = running_nodes.first
          if running_active_node_address != active_node.address
            _stop_node_by_address(running_active_node_address)
            _start_node(active_node)
          end
        else
          _remove_nodes(running_nodes - cluster_nodes)
          _add_nodes(cluster_nodes - running_nodes, fwmark)
          _add_nodes(local_cluster_nodes - running_nodes, _relay_fwmark)
        end
      end
    end

    def cluster_nodes
      (nodes + remote_nodes).map(&:address)
    end

    def local_cluster_nodes
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

      fresh_remote_nodes = _fetch_remote_nodes

      if active_passive?
        proposed_active_node = (@nodes + fresh_remote_nodes.values).reject do |node|
          node.weight.zero?
        end.sort.first

        if proposed_active_node && proposed_active_node != active_node
          _stop_node(active_node)
          _start_node(proposed_active_node)

          @current_active_node = proposed_active_node
          @remote_nodes = fresh_remote_nodes.values
        end
      end

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

      _check_downpage if has_downpage?
      _notify_nagios if nagios
    end

    def _start_node(node)
      BigBrother.ipvs.start_node(fwmark, node.address, node.weight)
      BigBrother.ipvs.start_node(_relay_fwmark, node.address, node.weight)
    end

    def _stop_node(node)
      BigBrother.ipvs.stop_node(fwmark, node.address)
      BigBrother.ipvs.stop_node(_relay_fwmark, node.address)
    end

    def _stop_node_by_address(address)
      BigBrother.ipvs.stop_node(fwmark, address)
      BigBrother.ipvs.stop_node(_relay_fwmark, address)
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

    def incorporate_state(original_cluster)
      ipvs_state = BigBrother.ipvs.running_configuration
      if ipvs_state[fwmark.to_s] && ipvs_state[_relay_fwmark.to_s].nil?
        BigBrother.logger.info "Adding new remote relay cluster #{to_s}"
        BigBrother.ipvs.start_cluster(_relay_fwmark, @scheduler)
      end

      _active_nodes.each do |node|
        original_node = original_cluster.find_node(node.address, node.port)
        node.incorporate_state(original_node) unless original_node.nil?

        if original_node.nil? && active_active?
          _start_node(node)
        elsif ipvs_state[fwmark.to_s] && ipvs_state.fetch(_relay_fwmark.to_s, []).empty?
          BigBrother.ipvs.start_node(_relay_fwmark, node.address, node.weight)
        end
      end

      (original_cluster.nodes - nodes).each do |removed_node|
        original_cluster._stop_node(removed_node)
      end

      if original_cluster.multi_datacenter && !self.multi_datacenter
        original_cluster.stop_relay_fwmark
        @remote_nodes = []
      end

      @monitored = original_cluster.monitored

      self
    end

    def stop_relay_fwmark
      nodes.each do |node|
        BigBrother.ipvs.stop_node(_relay_fwmark, node.address)
      end

      BigBrother.ipvs.stop_cluster(_relay_fwmark)
    end

    def _add_nodes(addresses, fwmark = @fwmark)
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
      local_health = @nodes.collect{ |n| n.weight || 0 }.reduce(:+)
      remote_health = @remote_nodes.collect{ |n| n.weight || 0 }.reduce(:+)
      total_health = 0

      if !local_health.nil?
        total_health += local_health
      end
      if !remote_health.nil?
        total_health += remote_health
      end
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
      BigBrother.logger.info "Removing downpage from cluster #{self}"
      BigBrother.ipvs.stop_node(fwmark, '169.254.254.254')
    end

    def _remove_nodes(addresses)
      addresses.each do |address|
        BigBrother.logger.info "Removing #{address} to cluster #{self}"
        BigBrother.ipvs.stop_node(fwmark, address)

        if @multi_datacenter
          BigBrother.ipvs.stop_node(_relay_fwmark, address)
        end
      end
    end

    def _update_node(node, new_weight)
      BigBrother.ipvs.edit_node(fwmark, node.address, new_weight)

      if @multi_datacenter
        BigBrother.ipvs.edit_node(_relay_fwmark, node.address, new_weight)
      end
    end

    def _relay_fwmark
      fwmark + offset
    end


    def _fetch_remote_nodes
      return {} if interpol_nodes.empty?

      regular_remote_cluster = BigBrother::HealthFetcher.interpol_status(interpol_nodes, fwmark)
      relay_remote_cluster = BigBrother::HealthFetcher.interpol_status(interpol_nodes, _relay_fwmark)

      return {} if regular_remote_cluster.empty? || relay_remote_cluster.empty?

      regular_remote_cluster.each_with_object({}) do |node, hsh|
        next if self.non_egress_locations.include?(node['lb_source_location'])

        hsh[node['lb_ip_address']] = BigBrother::Node.new(:address => node['lb_ip_address'], :weight => node['health'])
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

    def _add_remote_nodes(nodes)
      nodes.each do |node|
        BigBrother.ipvs.start_node(fwmark, node.address, node.weight)
        @remote_nodes << node
      end
    end
  end
end
