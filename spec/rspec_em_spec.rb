require_relative 'spec_helper.rb'

context 'Plain EM, no AMQP' do
  describe EventMachine, " when testing with AMQP::SpecHelper" do
    include AMQP::SpecHelper

    it "should not require a call to done when #em is not used" do
      1.should == 1
    end

    it "should have timers" do
      em do
        start = Time.now

        EM.add_timer(0.5) {
          (Time.now-start).should be_close(0.5, 0.1)
          done
        }
      end
    end
  end

  describe EventMachine, " when testing with AMQP::Spec" do
    include AMQP::EMSpec

    it 'should work' do
      done
    end

    it 'should have timers' do
      start = Time.now

      EM.add_timer(0.5) {
        (Time.now-start).should be_close(0.5, 0.1)
        done
      }
    end

    it 'should have periodic timers' do
      num = 0
      start = Time.now

      timer = EM.add_periodic_timer(0.2) {
        if (num += 1) == 2
          (Time.now-start).should be_close(0.4, 0.1)
          EM.__send__ :cancel_timer, timer
          done
        end
      }
    end

    it 'should have deferrables' do
      defr = EM::DefaultDeferrable.new
      defr.timeout(0.5)
      defr.errback {
        done
      }
    end

  end
end

describe "Rspec", " when running an example group after groups that uses EM specs " do
  it "should work normally" do
    :does_not_hang.should_not be_false
  end
end