module BigBrother
  class App < Sinatra::Base
    register Sinatra::Synchrony

    get "/" do
      "HELLO"
    end

    put "/cluster/:name" do |name|
      if BigBrother.clusters.has_key?(name)
        BigBrother.clusters[name].start_monitoring!
      else
        [404, "Cluster #{name} not found"]
      end
    end

    delete "/cluster/:name" do |name|
      if BigBrother.clusters.has_key?(name)
        BigBrother.clusters[name].stop_monitoring!
      else
        [404, "Cluster #{name} not found"]
      end
    end
  end
end
