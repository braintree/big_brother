module BigBrother
  class Ticker

    def self.pause(&block)
      EM.cancel_timer(@timer)

      while @outstanding_ticks > 0
        EM::Synchrony.sleep(0.1)
      end

      block.call
      schedule!
    end

    def self.schedule!
      @outstanding_ticks = 0
      @timer = EM::Synchrony.add_periodic_timer(0.1, &method(:tick))
    end

    def self.tick
      @outstanding_ticks += 1
      BigBrother.clusters.values.select(&:needs_check?).each do |cluster|
        cluster.monitor_nodes
      end
      @outstanding_ticks -= 1
    end
  end
end
