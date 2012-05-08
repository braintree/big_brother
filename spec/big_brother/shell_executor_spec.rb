require 'spec_helper'

describe BigBrother::ShellExecutor do
  describe "#invoke" do
    run_in_reactor

    it "runs a command" do
      executor = BigBrother::ShellExecutor.new
      output, exit_status = executor.invoke('echo hi')
      output.should == "hi\n"
      exit_status.should == 0
    end

    it "failed command" do
      executor = BigBrother::ShellExecutor.new
      output, exit_status = executor.invoke('test -e /this/isnt/here')
      output.should == ""
      exit_status.should == 1
    end
  end
end
