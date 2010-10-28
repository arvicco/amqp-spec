require 'spec_helper'

describe 'Following examples should all be failing:' do
  describe EventMachine, " when running failing examples" do
    include AMQP::EMSpec

    it "should not bubble failures beyond rspec" do
      EM.add_timer(0.1) do
        :should_not_bubble.should == :failures
        done
      end
    end

    it "should not block on failure" do
      1.should == 2
    end
  end

  describe EventMachine, " when testing with AMQP::EMSpec with a maximum execution time per test" do
    include AMQP::EMSpec

    # For RSpec 1, default_timeout and default_options are global
    # For RSpec 2, default_timeout and default_options are example-group local, inheritable by nested groups
    default_timeout 1

    it 'should timeout before reaching done' do
      EM.add_timer(2) { done }
    end

    it 'should timeout before reaching done' do
      timeout(0.3)
      EM.add_timer(0.6) { done }
    end
  end

  describe AMQP, " when testing with AMQP::Spec with a maximum execution time per test" do

    include AMQP::Spec

    # For RSpec 1, default_timeout and default_options are global
    # For RSpec 2, default_timeout and default_options are example-group local, inheritable by nested groups
    default_timeout 1

    it 'should timeout before reaching done' do
      EM.add_timer(2) { done }
    end

    it 'should timeout before reaching done' do
      timeout(0.2)
      EM.add_timer(0.5) { done }
    end

    it 'should fail due to timeout, not hang up' do
      timeout(0.2)
    end

    it 'should fail due to default timeout, not hang up' do
    end
  end
end