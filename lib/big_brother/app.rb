module BigBrother
  class App < Sinatra::Base
    register Sinatra::Synchrony

    set :raise_errors, false

    get "/" do
      BigBrother.clusters.map do |name, cluster|
        "#{cluster}: #{cluster.monitored? ? "running" : "not running"}"
      end.join("\n") + "\n"
    end

    before "/cluster/:name" do |name|
      @cluster = BigBrother.clusters[name]
      halt 404, "Cluster #{name} not found" if @cluster.nil?
    end

    get "/cluster/:name" do |name|
      [200, "Running: #{@cluster.monitored?}"]
    end

    put "/cluster/:name" do |name|
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
