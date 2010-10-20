require_relative 'spec_helper.rb'

context 'Plain EM, no AMQP' do
  describe EventMachine, " when testing with AMQP::SpecHelper" do
    include AMQP::SpecHelper

    it "should not require a call to done when #em is not used" do
      1.should == 1
    end

    it "should have timers" do
      start = Time.now
      em do
        EM.add_timer(0.5) {
          (Time.now-start).should be_close(0.5, 0.1)
          done
        }
      end
    end

    it "should be possible to set spec timeouts as a number of secounds" do
      start = Time.now
      expect {
        em(0.5) do
          EM.add_timer(1) { done }
        end
      }.to raise_error SpecTimeoutExceededError
      (Time.now-start).should be_close(0.5, 0.1)
    end

    it "should be possible to set spec timeout as an option (amqp interface compatibility)" do
      start = Time.now
      expect {
        em(0.5) do
          EM.add_timer(1) { done }
        end
      }.to raise_error SpecTimeoutExceededError
      (Time.now-start).should be_close(0.5, 0.1)
    end
  end

  describe EventMachine, " when testing with AMQP::Spec" do
    include AMQP::EMSpec

    it_should_behave_like 'Spec examples'
  end
end

describe "Rspec", " when running an example group after groups that uses EM specs " do
  it "should work normally" do
    :does_not_hang.should_not be_false
  end
end