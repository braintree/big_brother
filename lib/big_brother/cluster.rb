module BigBrother
  class Cluster

    def initialize(name, attributes = {})
      @name = name
      @check_interval = attributes.fetch(:check_interval, 1)
      @monitored = false
      @last_check = Time.new(0)
    end

    def monitored?
      @monitored
    end

    def monitor!
      @monitored = true
    end

    def unmonitor!
      @monitored = false
    end

    def needs_check?
      @last_check + @check_interval < Time.now
    end

    def monitor_nodes
      @last_check = Time.now
    end
  end
end
