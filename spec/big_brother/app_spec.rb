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

    describe "PUT /cluster/:name" do
      it "marks the cluster as monitored" do
        BigBrother.clusters['test'] = Cluster.new('test')

        put "/cluster/test"

        last_response.status.should == 200
        last_response.body.should == ""
        BigBrother.clusters['test'].should be_monitored
      end

      it "returns 'not found' if the cluster does not exist" do
        put "/cluster/test"

        last_response.status.should == 404
        last_response.body.should == "Cluster test not found"
      end

      it "populates IPVS" do
        node = Node.new('localhost', 8081, '/status')
        BigBrother.clusters['test'] = Cluster.new('test', :fwmark => 100, :scheduler => 'wrr', :nodes => [node])

        put "/cluster/test"

        last_response.status.should == 200
        last_response.body.should == ""
        BigBrother.clusters['test'].should be_monitored
        @recording_executor.commands.last.should == "ipvsadm --add-service --fwmark-service 100 --scheduler wrr"
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
