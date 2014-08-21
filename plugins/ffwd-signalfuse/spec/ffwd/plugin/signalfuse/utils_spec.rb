require 'ffwd/plugin/signalfuse/utils'

describe FFWD::Plugin::Signalfuse::Utils do
  describe "#safe_string" do
    it "should escape unsafe characters" do
      described_class.safe_string("foo bar").should eq("foo_bar")
      described_class.safe_string("foo:bar").should eq("foo_bar")
      described_class.safe_string("foobar").should eq("foobar")
    end
  end
end
