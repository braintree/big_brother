require 'net/http'

module BigBrother
  class Node
    attr_reader :address, :port, :path, :start_time

    def initialize(attributes={})
      @address = attributes[:address]
      @port = attributes[:port]
      @path = attributes[:path]
      @weight = attributes[:weight]
      @start_time = attributes.fetch(:start_time, Time.now.to_i)
    end

    def age
      Time.now.to_i - @start_time
    end

    def invalidate_weight!
      @weight = nil
    end

    def monitor(cluster)
      new_weight = _determine_weight(cluster)
      return unless cluster.monitored?
      if new_weight != @weight
        BigBrother.ipvs.edit_node(cluster.fwmark, address, new_weight)
        @weight = new_weight
      end
    end

    def ==(other)
      address == other.address && port == other.port
    end

    def _determine_weight(cluster)
      if cluster.up_file_exists?
        100
      elsif cluster.down_file_exists?
        0
      else
        _weight_health(BigBrother::HealthFetcher.current_health(@address, @port, @path), cluster.ramp_up_time)
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
