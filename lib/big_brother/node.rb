require 'net/http'

module BigBrother
  class Node
    attr_reader :address, :port, :path

    def initialize(address, port, path)
      @address = address
      @port = port
      @path = path
    end

    def current_health
      response = _get("http://#{@address}:#{@port}#{@path}")
      _parse_health(response)
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
        current_health
      end
    end

    def _get(url)
      EventMachine::HttpRequest.new(url).get
    end

    def _parse_health(http_response)
      if http_response.response_header.has_key?('X_HEALTH')
        http_response.response_header['X_HEALTH'].to_i
      else
        http_response.response.slice(/Health: (\d+)/, 1).to_i
      end
    end
  end
end
