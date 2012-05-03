require 'spec_helper'

module BigBrother
  describe App do
    def app
      App
    end

    describe "/" do
      it "works" do
        get "/"
        last_response.status.should == 200
        last_response.body.should == "HELLO"
      end
    end
  end
end
