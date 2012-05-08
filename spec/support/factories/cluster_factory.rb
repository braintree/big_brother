class Factory
  def self.cluster(overrides = {})
    BigBrother::Cluster.new(
      overrides.fetch(:name, 'test'),
      {
        :fwmark => overrides.fetch(:fwmark, 100),
        :scheduler => overrides.fetch(:scheduler, 'wrr'),
        :check_interval => overrides.fetch(:check_interval, 1),
        :nodes => overrides.fetch(:nodes, [])
      }
    )
  end
end
