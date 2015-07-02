require 'net/http'

module BigBrother
  class Node
    attr_reader :address, :port, :path, :start_time, :priority, :max_weight
    attr_accessor :weight, :down_tick_count
    INITIAL_WEIGHT = 1

    def initialize(attributes={})
      @address = attributes[:address]
      @port = attributes[:port]
      @path = attributes[:path]
      @weight = attributes[:weight]
      @start_time = attributes.fetch(:start_time, Time.now.to_i)
      @priority = attributes.fetch(:priority, 0)
      @interpol = attributes.fetch(:interpol, false)
      @max_weight = attributes[:max_weight]
      @down_tick_count = 0
    end

    def age
      Time.now.to_i - @start_time
    end

    def incorporate_state(another_node)
      if another_node
        @weight = another_node.weight
        @start_time = another_node.start_time
      end
    end

    def invalidate_weight!
      @weight = nil
    end

    def interpol?
      @interpol
    end

    def ==(other)
      address == other.address && port == other.port
    end
    alias eql? ==

    def hash
      [@address, @port].hash
    end

    def <=>(other)
      return 1 if self.weight.to_i.zero?
      return -1 if other.weight.to_i.zero?
      comparison = self.priority <=> other.priority
      if comparison.zero?
       self.address <=> other.address
      else
        comparison
      end
    end

    def monitor(cluster)
      if cluster.up_file_exists?
        100
      elsif cluster.down_file_exists?
        0
      else
        _cap_weight(_weight_health(BigBrother::HealthFetcher.current_health(@address, @port, @path), cluster.ramp_up_time))
      end
    end

    def _cap_weight(health)
      if !@max_weight.nil? && @max_weight.is_a?(Integer) && @max_weight > 0 && @max_weight < health
        @max_weight
      else
        health
      end
    end

    def _weight_health(health, ramp_up_time)
      current_age = age
      if current_age < ramp_up_time
        (health * (current_age / ramp_up_time.to_f)).to_i
      else
        health
      end
    end
  end
end
