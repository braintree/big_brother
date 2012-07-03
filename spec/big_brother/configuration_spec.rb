require 'spec_helper'

describe BigBrother::Configuration do
  describe '.evaluate' do
    it 'returns a hash of clusters' do
      clusters = BigBrother::Configuration.evaluate(TEST_CONFIG)

      clusters['test1'].check_interval.should == 1
      clusters['test1'].scheduler.should == 'wrr'
      clusters['test1'].fwmark.should == 1
      clusters['test1'].persistent.should == 20

      clusters['test2'].check_interval.should == 1
      clusters['test2'].scheduler.should == 'wrr'
      clusters['test2'].fwmark.should == 2

      clusters['test3'].check_interval.should == 1
      clusters['test3'].scheduler.should == 'wrr'
      clusters['test3'].fwmark.should == 3
    end

    it 'populates a clusters nodes' do
      clusters = BigBrother::Configuration.evaluate(TEST_CONFIG)

      clusters['test1'].nodes.length.should == 2

      clusters['test1'].nodes[0].address == '127.0.0.1'
      clusters['test1'].nodes[0].port == '9001'
      clusters['test1'].nodes[0].path == '/test/valid'

      clusters['test1'].nodes[1].address == '127.0.0.1'
      clusters['test1'].nodes[1].port == '9002'
      clusters['test1'].nodes[1].path == '/test/valid'
    end
  end
end
