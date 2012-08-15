class Factory
  def self.cluster(overrides = {})
    BigBrother::Cluster.new(
      overrides.fetch(:name, 'test'),
      {
        'fwmark' => overrides.fetch(:fwmark, 100),
        'scheduler' => overrides.fetch(:scheduler, 'wrr'),
        'check_interval' => overrides.fetch(:check_interval, 1),
        'nodes' => overrides.fetch(:nodes, [Factory.node]),
        'ramp_up_time' => overrides.fetch(:ramp_up_time, 0)
      }
    )
  end
end
