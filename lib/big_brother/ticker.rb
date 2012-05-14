module BigBrother
  class Ticker
    def self.schedule!
      EM::Synchrony.add_periodic_timer(0.1, &method(:tick))
    end

    def self.tick
      BigBrother.clusters.values.select(&:needs_check?).each do |cluster|
        cluster.monitor_nodes
      end
    end
  end
end
