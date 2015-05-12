require 'spec_helper'

module BigBrother
  describe App do
    def app
      App
    end

    describe "/" do
      it "returns the list of configured clusters and their status" do
        BigBrother::HealthFetcher.stub(:current_health).and_return(99)
        BigBrother.clusters['one'] = Factory.cluster(:name => 'one', :fwmark => 1)
        BigBrother.clusters['two'] = Factory.cluster(:name => 'two', :fwmark => 2)
        BigBrother.clusters['three'] = Factory.cluster(
          :name => 'three', :fwmark => 3,
          :nodes => [Factory.node(:weight => 99)]
        )
        BigBrother.clusters['three'].start_monitoring!
        BigBrother.clusters['four'] = Factory.cluster(:name => 'four', :fwmark => 4)

        get "/"
        last_response.status.should == 200
        last_response.body.should include("Big Brother: #{BigBrother::VERSION}")
        last_response.body.should include("- one (1)")
        last_response.body.should include("- two (2)")
        last_response.body.should include("+ three (3) - CombinedWeight: 99")
        last_response.body.should include("- four (4)")
      end
    end

    describe "GET /cluster/:name" do
      it "returns 'Running: false' when the cluster isn't running" do
        BigBrother.clusters['test'] = Factory.cluster(:name => 'test')

        get "/cluster/test"

        last_response.status.should == 200
        last_response.body.should =~ /^Running: false$/
      end

      it "returns 'Running: true' and the combined weight when the cluster is running" do
        BigBrother.clusters['test'] = Factory.cluster(
          :name => 'test',
          :nodes => [
            Factory.node,
            Factory.node,
            Factory.node,
          ]
        )

        put "/cluster/test"
        get "/cluster/test"

        last_response.status.should == 200
        last_response.body.should == <<-RESPONSE_BODY
Running: true
CombinedWeight: 300
        RESPONSE_BODY
      end

      it "attempts to synchronize the node if it is not running" do
        @stub_executor.add_response("ipvsadm --save --numeric", <<-OUTPUT, 0)
-A -f 1 -s wrr
-a -f 1 -r 10.0.1.223:80 -i -w 1
-a -f 1 -r 10.0.1.224:80 -i -w 1
-A -f 2 -s wrr
-a -f 2 -r 10.0.1.225:80 -i -w 1
        OUTPUT
        BigBrother.configure(TEST_CONFIG)
        BigBrother.clusters['test'] = Factory.cluster(:name => 'test', :fwmark => 1)

        get "/cluster/test"

        last_response.status.should == 200
        last_response.body.should =~ /^Running: true$/
      end

      it "returns a 404 http status when the cluster is not found" do
        get "/cluster/not_found"

        last_response.status.should == 404
      end
    end

    describe "GET /cluster/:name/status" do
      it "returns 'Running: false' when the cluster isn't running" do
        BigBrother.clusters['test'] = Factory.cluster(:name => 'test')

        get "/cluster/test/status"

        last_response.status.should == 200
        last_response.body.should =~ /^Running: false$/
      end

      it "returns 'Running: true' and the combined weight when the cluster is running" do
        BigBrother.clusters['test'] = Factory.cluster(
          :name => 'test',
          :nodes => [
            Factory.node,
            Factory.node,
            Factory.node,
          ]
        )

        put "/cluster/test"
        get "/cluster/test/status"

        last_response.status.should == 200
        last_response.body.should == <<-RESPONSE_BODY
Running: true
CombinedWeight: 300
        RESPONSE_BODY
      end

      it "does not synchronize the cluster, so litmus_paper can call this route often" do
        cluster = Factory.cluster(:name => 'test')
        BigBrother.clusters['test'] = cluster

        cluster.should_receive(:synchronize!).never

        get "/cluster/test/status"

        last_response.status.should == 200
        last_response.body.should =~ /^Running: false$/
      end

      it "returns a 404 http status when the cluster is not found" do
        get "/cluster/not_found/status"

        last_response.status.should == 404
      end
    end

    describe "PUT /cluster/:name" do
      it "marks the cluster as monitored" do
        BigBrother.clusters['test'] = Factory.cluster(:name => 'test')

        put "/cluster/test"

        last_response.status.should == 200
        last_response.body.should == "OK"
        BigBrother.clusters['test'].should be_monitored
      end

      it "only starts monitoring the cluster once" do
        BigBrother.clusters['test'] = Factory.cluster(:name => 'test')

        put "/cluster/test"
        last_response.status.should == 200

        put "/cluster/test"
        last_response.status.should == 304
      end

      it "returns 'not found' if the cluster does not exist" do
        put "/cluster/test"

        last_response.status.should == 404
        last_response.body.should == "Cluster test not found"
      end

      it "populates IPVS" do
        first = Factory.node(:address => '127.0.0.1')
        second = Factory.node(:address => '127.0.0.2')
        BigBrother.clusters['test'] = Factory.cluster(:name => 'test', :fwmark => 100, :scheduler => 'wrr', :nodes => [first, second])

        put "/cluster/test"

        last_response.status.should == 200
        last_response.body.should == "OK"
        BigBrother.clusters['test'].should be_monitored
        @stub_executor.commands.should include("ipvsadm --add-service --fwmark-service 100 --scheduler wrr")
        @stub_executor.commands.should include("ipvsadm --add-server --fwmark-service 100 --real-server 127.0.0.1 --ipip --weight 1")
        @stub_executor.commands.should include("ipvsadm --add-server --fwmark-service 100 --real-server 127.0.0.2 --ipip --weight 1")
      end

      it "attempts to synchronize the nodes in the cluster" do
        @stub_executor.add_response("ipvsadm --save --numeric", <<-OUTPUT, 0)
-A -f 100 -s wrr
-a -f 100 -r 127.0.1.223:80 -i -w 1
-a -f 100 -r 127.0.1.224:80 -i -w 1
-A -f 2 -s wrr
-a -f 2 -r 10.0.1.225:80 -i -w 1
      OUTPUT
        BigBrother.configure(TEST_CONFIG)
        first = Factory.node(:address => '127.0.1.223')
        second = Factory.node(:address => '127.0.1.225')
        BigBrother.clusters['test'] = Factory.cluster(:name => 'test', :fwmark => 100, :scheduler => 'wrr', :nodes => [first, second])

        put "/cluster/test"

        last_response.status.should == 304
        last_response.body.should == ""
        BigBrother.clusters['test'].should be_monitored
        @stub_executor.commands.should include("ipvsadm --add-server --fwmark-service 100 --real-server 127.0.1.225 --ipip --weight 0")
        @stub_executor.commands.should include("ipvsadm --delete-server --fwmark-service 100 --real-server 127.0.1.224")
      end
    end

    describe "DELETE /cluster/:name" do
      it "marks the cluster as no longer monitored" do
        BigBrother::HealthFetcher.stub(:current_health)
        BigBrother.clusters['test'] = Factory.cluster(:name => 'test')
        BigBrother.clusters['test'].start_monitoring!

        delete "/cluster/test"

        last_response.status.should == 200
        last_response.body.should == "OK"
        BigBrother.clusters['test'].should_not be_monitored
      end

      it "only stops monitoring the cluster once" do
        BigBrother.clusters['test'] = Factory.cluster(:name => 'test')

        delete "/cluster/test"

        last_response.status.should == 304
        last_response.body.should == ""
        BigBrother.clusters['test'].should_not be_monitored
      end

      it "returns 'not found' if the cluster does not exist" do
        delete "/cluster/test"

        last_response.status.should == 404
        last_response.body.should == "Cluster test not found"
      end
    end

    describe "error handling" do
      it "logs exceptions" do
        BigBrother.clusters['test'] = "this is not a cluster"

        BigBrother.logger.should_receive(:info).with(/^Error:/)
        BigBrother.logger.should_receive(:info).with(/big_brother/)

        put "/cluster/test"

        last_response.status.should == 500
      end
    end
  end
end
