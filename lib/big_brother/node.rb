require 'net/http'

module BigBrother
  class Node
    def initialize(address, port, path)
      @address = address
      @port = port
      @path = path
    end

    def current_health
      response = _get("http://#{@address}:#{@port}#{@path}")
      _parse_health(response)
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
