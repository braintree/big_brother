class Factory
  def self.cluster(overrides = {})
    BigBrother::ClusterFactory.create_cluster(
      overrides.fetch(:name, 'test'),
      {
        :fwmark         => 100,
        :scheduler      => 'wrr',
        :check_interval => 1,
        :nodes          => [Factory.node],
        :ramp_up_time   => 0
      }.merge(overrides)
    )
  end

  def self.active_passive_cluster(overrides = {})
    self.cluster(overrides.merge(:backend_mode => BigBrother::ClusterFactory::ACTIVE_PASSIVE_CLUSTER))
  end

  def self.active_active_cluster(overrides = {})
    self.cluster(overrides.merge(:backend_mode => BigBrother::ClusterFactory::ACTIVE_ACTIVE_CLUSTER))
  end
end
