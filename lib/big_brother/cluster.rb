module BigBrother
  class Cluster
    attr_reader :fwmark, :scheduler, :check_interval, :nodes

    def initialize(name, attributes = {})
      @name = name
      @fwmark = attributes['fwmark']
      @scheduler = attributes['scheduler']
      @check_interval = attributes.fetch('check_interval', 1)
      @monitored = false
      @nodes = attributes.fetch('nodes', [])
      @last_check = Time.new(0)
      @up_file = BigBrother::StatusFile.new('up', @name)
      @down_file = BigBrother::StatusFile.new('down', @name)
    end

    def monitored?
      @monitored
    end

    def start_monitoring!
      BigBrother.logger.info "starting monitoring on cluster #{to_s}"
      BigBrother.ipvs.start_cluster(@fwmark, @scheduler)
      @nodes.each do |node|
        BigBrother.ipvs.start_node(@fwmark, node.address, 100)
      end

      @monitored = true
    end

    def stop_monitoring!
      BigBrother.logger.info "stopping monitoring on cluster #{to_s}"
      BigBrother.ipvs.stop_cluster(@fwmark)

      @monitored = false
    end

    def resume_monitoring!
      BigBrother.logger.info "resuming monitoring on cluster #{to_s}"
      @monitored = true
    end

    def needs_check?
      return false unless monitored?
      @last_check + @check_interval < Time.now
    end

    def monitor_nodes
      @nodes.each { |node| node.monitor(self) }
      @last_check = Time.now
    end

    def to_s
      "#{@name} (#{@fwmark})"
    end

    def up_file_exists?
      @up_file.exists?
    end

    def down_file_exists?
      @down_file.exists?
    end
  end
end
