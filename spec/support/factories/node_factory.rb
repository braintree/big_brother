class Factory
  def self.node(overrides = {})
    BigBrother::Node.new(
      {
        :address => 'localhost',
        :port    => 8081,
        :path    => '/test/status',
        :weight  => 100
      }.merge(overrides)
    )
  end
end
