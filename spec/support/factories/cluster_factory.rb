class Factory
  def self.cluster(overrides = {})
    BigBrother::Cluster.new(
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
    self.cluster(overrides.merge(:backend_mode => "active_passive"))
  end

  def self.active_active_cluster(overrides = {})
    self.cluster(overrides.merge(:backend_mode => "active_active"))
  end
end
