require 'net/http'

module BigBrother
  class Node
    attr_reader :address, :port, :path

    def initialize(address, port, path)
      @address = address
      @port = port
      @path = path
      @weight = nil
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
        BigBrother::HealthFetcher.current_health(@address, @port, @path)
      end
    end
  end
end
