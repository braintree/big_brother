module BigBrother
  class App < Sinatra::Base
    register Sinatra::Synchrony

    set :raise_errors, false

    get "/" do
      [200, <<-CONTENT]
Big Brother: #{BigBrother::VERSION}

Running:
#{BigBrother.clusters.running.map { |cluster| "+ #{cluster} - CombinedWeight: #{cluster.combined_weight}\n" }.join}
Stopped:
#{BigBrother.clusters.stopped.map { |cluster| "- #{cluster}\n" }.join}
      CONTENT
    end

    before %r{/cluster/([^/]+).*$} do |name|
      @cluster = BigBrother.clusters[name]
      halt 404, "Cluster #{name} not found" if @cluster.nil?
    end

    get "/cluster/:name/status" do |name|
      _cluster_status
    end

    get "/cluster/:name" do |name|
      @cluster.synchronize! unless @cluster.monitored?
      _cluster_status
    end

    def _cluster_status
      [200, "Running: #{@cluster.monitored?}\nCombinedWeight: #{@cluster.combined_weight}\n"]
    end

    put "/cluster/:name" do |name|
      @cluster.synchronize!
      halt 304 if @cluster.monitored?
      @cluster.start_monitoring!
      [200, "OK"]
    end

    delete "/cluster/:name" do |name|
      halt 304 unless @cluster.monitored?
      @cluster.stop_monitoring!
      [200, "OK"]
    end

    error do
      e = request.env['sinatra.error']

      BigBrother.logger.info "Error: #{e}"
      BigBrother.logger.info e.backtrace.join("\n")

      'Application error'
    end
  end
end
