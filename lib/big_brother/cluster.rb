module BigBrother
  class Cluster
    attr_reader :fwmark, :scheduler, :check_interval, :nodes, :name, :persistent, :ramp_up_time

    def initialize(name, attributes = {})
      @name = name
      @fwmark = attributes['fwmark']
      @scheduler = attributes['scheduler']
      @persistent = attributes.fetch('persistent', 300)
      @check_interval = attributes.fetch('check_interval', 1)
      @monitored = false
      @nodes = attributes.fetch('nodes', [])
      @last_check = Time.new(0)
      @up_file = BigBrother::StatusFile.new('up', @name)
      @down_file = BigBrother::StatusFile.new('down', @name)
      @ramp_up_time = attributes.fetch('ramp_up_time', 60)
    end

    def monitored?
      @monitored
    end

    def start_monitoring!
      BigBrother.logger.info "starting monitoring on cluster #{to_s}"
      BigBrother.ipvs.start_cluster(@fwmark, @scheduler, @persistent)
      @nodes.each do |node|
        BigBrother.ipvs.start_node(@fwmark, node.address, 100)
      end

      @monitored = true
    end

    def stop_monitoring!
      BigBrother.logger.info "stopping monitoring on cluster #{to_s}"
      BigBrother.ipvs.stop_cluster(@fwmark)

      @monitored = false
      @nodes.each(&:invalidate_weight!)
    end

    def resume_monitoring!
      BigBrother.logger.info "resuming monitoring on cluster #{to_s}"
      @monitored = true
    end

    def synchronize!
      ipvs_state = BigBrother.ipvs.running_configuration
      if ipvs_state.has_key?(fwmark.to_s)
        resume_monitoring!

        running_nodes = ipvs_state[fwmark.to_s]
        cluster_nodes = nodes.map(&:address)

        _remove_nodes(running_nodes - cluster_nodes)
        _add_nodes(cluster_nodes - running_nodes)
      end
    end

    def needs_check?
      return false unless monitored?
      @last_check + @check_interval < Time.now
    end

    def monitor_nodes
      @last_check = Time.now
      @nodes.each { |node| node.monitor(self) }
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

    def _add_nodes(addresses)
      addresses.each do |address|
        BigBrother.logger.info "adding #{address} to cluster #{self}"
        BigBrother.ipvs.start_node(fwmark, address, 100)
      end
    end

    def _remove_nodes(addresses)
      addresses.each do |address|
        BigBrother.logger.info "removing #{address} to cluster #{self}"
        BigBrother.ipvs.stop_node(fwmark, address)
      end
    end
  end
end
