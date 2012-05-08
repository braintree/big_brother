class Factory
  def self.node(overrides = {})
    BigBrother::Node.new(
      overrides.fetch(:address, 'localhost'),
      overrides.fetch(:port, 8081),
      overrides.fetch(:path, '/test/status')
    )
  end
end
