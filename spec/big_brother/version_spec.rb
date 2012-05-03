require 'spec_helper'

describe BigBrother::VERSION do
  it "is not nil" do
    BigBrother::VERSION.should_not be_nil
  end
end
