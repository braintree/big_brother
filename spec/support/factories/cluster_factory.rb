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
end
