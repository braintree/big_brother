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
      if new_weight != @weight
        BigBrother.ipvs.edit_node(cluster.fwmark, address, _determine_weight(cluster))
        @weight = new_weight
      end
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
