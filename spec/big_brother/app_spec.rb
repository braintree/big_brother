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

    describe "POST /cluster/:name" do
      it "marks the cluster as monitored" do
        BigBrother.clusters['test'] = Cluster.new('test')

        post "/cluster/test"

        last_response.status.should == 200
        last_response.body.should == ""
        BigBrother.clusters['test'].should be_monitored
      end

      it "returns 'not found' if the cluster does not exist" do
        post "/cluster/test"

        last_response.status.should == 404
        last_response.body.should == "Cluster test not found"
      end
    end

    describe "DELETE /cluster/:name" do
      it "marks the cluster as no longer monitored" do
        BigBrother.clusters['test'] = Cluster.new('test')
        BigBrother.clusters['test'].start_monitoring!

        delete "/cluster/test"

        last_response.status.should == 200
        last_response.body.should == ""
        BigBrother.clusters['test'].should_not be_monitored
      end

      it "returns 'not found' if the cluster does not exist" do
        delete "/cluster/test"

        last_response.status.should == 404
        last_response.body.should == "Cluster test not found"
      end
    end
  end
end
