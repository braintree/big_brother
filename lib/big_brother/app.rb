module BigBrother
  class App < Sinatra::Base
    register Sinatra::Synchrony

    get "/" do
      "HELLO"
    end

    before "/cluster/:name" do |name|
      @cluster = BigBrother.clusters[name]
      halt 404, "Cluster #{name} not found" if @cluster.nil?
    end

    get "/cluster/:name" do |name|
      [200, "Running: #{@cluster.monitored?}"]
    end

    put "/cluster/:name" do |name|
      @cluster.start_monitoring!
    end

    delete "/cluster/:name" do |name|
      @cluster.stop_monitoring!
    end
  end
end
