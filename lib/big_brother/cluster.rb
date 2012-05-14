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
      BigBrother.ipvs.start_cluster(@fwmark, @scheduler)
      @nodes.each do |node|
        BigBrother.ipvs.start_node(@fwmark, node.address, 100)
      end

      @monitored = true
    end

    def stop_monitoring!
      BigBrother.ipvs.stop_cluster(@fwmark)
      @monitored = false
    end

    def resume_monitoring!
      @monitored = true
    end

    def needs_check?
      return false unless monitored?
      @last_check + @check_interval < Time.now
    end

    def monitor_nodes
      @nodes.each do |node|
        BigBrother.ipvs.edit_node(@fwmark, node.address, _determine_weight(node))
      end

      @last_check = Time.now
    end

    def _determine_weight(node)
      if @up_file.exists?
        100
      elsif @down_file.exists?
        0
      else
        node.current_health
      end
    end
  end
end
