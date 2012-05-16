require 'net/http'

module BigBrother
  class Node
    attr_reader :address, :port, :path

    def initialize(address, port, path)
      @address = address
      @port = port
      @path = path
    end

    def monitor(cluster)
      BigBrother.ipvs.edit_node(cluster.fwmark, address, _determine_weight(cluster))
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
