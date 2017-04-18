require 'json'

module BigBrother
  class HealthFetcher
    def self.current_health(address, port, path)
      url = "http://#{address}:#{port}#{path}"

      BigBrother.logger.debug("Fetching health from #{url}")
      response = EventMachine::HttpRequest.new(url).get
      response.response_header.status == 200 ? _parse_health(response) : 0
    end

    def self.interpol_status(interpol_nodes, fwmark)
      nodes = *interpol_nodes
      urls = nodes.map do |interpol_node|
        "http://#{interpol_node.address}:#{interpol_node.port}/fwmark/#{fwmark}"
      end

      response = _first_interpol_response(urls)
      response.response_header.status == 200 ? JSON.parse(response.response) : []
    rescue JSON::ParserError
      []
    end

    def self._first_interpol_response(urls)
      result = nil
      EM::Synchrony::Iterator.new(urls, urls.size).each do |url, iter|
        BigBrother.logger.debug("Fetching health from #{url}")
        http = EventMachine::HttpRequest.new(url, :connect_timeout => 2, :inactivity_timeout => 2).aget
        this = self
        http.callback do
          result = http
          if http.response_header.status == 200
            BigBrother.logger.debug("Request to #{url} was successful")
            this.instance_variable_set(:@ended, true) #This halts the loop
          end
          iter.next
        end

        http.errback do
          result = http
          iter.next
        end
      end
      result
    end


    def self._parse_health(response)
      if response.response_header.has_key?('X_HEALTH')
        response.response_header['X_HEALTH'].to_i
      else
        response.response.slice(/Health: (\d+)/, 1).to_i
      end
    end
  end
end
