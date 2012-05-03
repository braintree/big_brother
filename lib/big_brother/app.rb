module BigBrother
  class App < Sinatra::Base
    register Sinatra::Synchrony

    get "/" do
      "HELLO"
    end

    post "/cluster/:name" do |name|
      if BigBrother.clusters.has_key?(name)
        BigBrother.clusters[name].monitor!
      else
        [404, "Cluster #{name} not found"]
      end
    end
  end
end
