module BigBrother
  class HealthFetcher
    def self.current_health(address, port, path)
      http_response = EventMachine::HttpRequest.new("http://#{address}:#{port}#{path}").get

      if http_response.response_header.has_key?('X_HEALTH')
        http_response.response_header['X_HEALTH'].to_i
      else
        http_response.response.slice(/Health: (\d+)/, 1).to_i
      end
    end
  end
end
