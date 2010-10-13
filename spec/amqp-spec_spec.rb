require File.dirname(__FILE__) + '/../lib/amqp-spec/rspec'

describe 'Rspec' do
  it 'should work as normal without AMQP-Spec' do
    1.should == 1
  end
end

describe AMQP, "when testing with AMQP::SpecHelper" do
  include AMQP::SpecHelper

  it "should not require a call to done when #em is not used" do
    1.should == 1
  end

  it "should have timers" do
    amqp do
      start = Time.now

      EM.add_timer(0.5){
        (Time.now-start).should be_close( 0.5, 0.1 )
        done
      }
    end
  end
end

describe AMQP, "when testing with AMQP::Spec" do
  include AMQP::Spec

  it 'should work' do
    done
  end

  it 'should have timers' do
    start = Time.now

    EM.add_timer(0.5){
      (Time.now-start).should be_close( 0.5, 0.1 )
      done
    }
  end

  it 'should have periodic timers' do
    num = 0
    start = Time.now

    timer = EM.add_periodic_timer(0.5){
      if (num += 1) == 2
        (Time.now-start).should be_close( 1.0, 0.1 )
        EM.__send__ :cancel_timer, timer
        done
      end
    }
  end

  it 'should have deferrables' do
    defr = EM::DefaultDeferrable.new
    defr.timeout(1)
    defr.errback{
      done
    }
  end

end

describe AMQP, "when testing with AMQP::Spec with spec timeouts" do

  include AMQP::Spec

  default_timeout 2

  it 'should timeout before reaching done' do
    EM.add_timer(3) {
      done
    }
  end

  it 'should timeout before reaching done' do
    timeout(4)
    EM.add_timer(3) {
      done
    }
  end

end

describe "Rspec", "when running an example group after another group that uses AMQP-Spec " do
  it "should work normally" do
    :does_not_hang.should_not be_false
  end
end