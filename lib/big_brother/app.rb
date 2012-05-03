module BigBrother
  class App < Sinatra::Base
    register Sinatra::Synchrony

    get "/" do
      "HELLO"
    end
  end
end
