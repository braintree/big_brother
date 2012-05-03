module BigBrother
  class Cluster

    def initialize(name)
      @name = name
      @monitored = false
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
  end
end
