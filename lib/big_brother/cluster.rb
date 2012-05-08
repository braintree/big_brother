module BigBrother
  class Cluster

    def initialize(name, attributes = {})
      @name = name
      @fwmark = attributes[:fwmark]
      @scheduler = attributes[:scheduler]
      @check_interval = attributes.fetch(:check_interval, 1)
      @monitored = false
      @nodes = attributes.fetch(:nodes, [])
      @last_check = Time.new(0)
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
      @monitored = false
    end

    def needs_check?
      @last_check + @check_interval < Time.now
    end

    def monitor_nodes
      @nodes.each(&:current_health)
      @last_check = Time.now
    end
  end
end
