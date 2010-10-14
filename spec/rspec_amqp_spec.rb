require_relative 'spec_helper.rb'

describe 'Rspec' do
  it 'should work as normal without AMQP-Spec' do
    1.should == 1
  end
end

context 'Evented AMQP specs' do
  describe AMQP, " when testing with AMQP::SpecHelper" do
    include AMQP::SpecHelper
    after(:each) do
      EM.reactor_running?.should == false
      AMQP.conn.should be_nil
    end

    default_options AMQP_OPTS if defined? AMQP_OPTS
    default_timeout 1 # Can be used to set default :spec_timeout for all your amqp-based specs

    p default_timeout, default_options

    it "should not require a call to done when #em/#amqp is not used" do
      1.should == 1
    end

    it "should properly work" do
      amqp do
        done
      end
    end

    it "should have timers" do
      amqp do
        start = Time.now

        EM.add_timer(0.5) {
          (Time.now-start).should be_close(0.5, 0.1)
          done
        }
      end
    end

    it "should run AMQP.start loop with options given to #amqp" do
      amqp(:vhost => '/', :user => 'guest') do
        AMQP.conn.should be_connected
        done
      end
    end

    it "should properly close AMQP connection if block completes normally" do
      amqp do
        AMQP.conn.should be_connected
        done
      end
      AMQP.conn.should be_nil
    end

    it 'should have deferrables' do
      amqp do
        defr = EM::DefaultDeferrable.new
        defr.timeout(0.5)
        defr.errback {
          done
        }
      end
    end

    context 'on exceptions/failures' do
#      default_timeout 1 # Can be used to set default :spec_timeout for all your amqp-based specs


    end
  end

  describe AMQP, " when testing with AMQP::Spec" do
    include AMQP::Spec
    after(:each) do
      EM.reactor_running?.should == true
      done
    end

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

      timer = EM.add_periodic_timer(0.25) {
        if (num += 1) == 2
          (Time.now-start).should be_close(0.5, 0.1)
          EM.cancel_timer timer
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

  shared_examples_for 'timeout examples' do
    include AMQP::SpecHelper
    before(:each) { @start = Time.now }

    it 'should timeout before reaching done because of default spec timeout' do
      proc {
        amqp do
          EM.add_timer(2) { done }
        end
      }.should raise_error SpecTimeoutExceededError
      (Time.now-@start).should be_close(1.0, 0.1)
    end

    it 'should timeout before reaching done because of explicit in-loop timeout' do
      proc {
        amqp do
          timeout(0.2)
          EM.add_timer(0.5) { done }
        end
      }.should raise_error SpecTimeoutExceededError
      (Time.now-@start).should be_close(0.2, 0.1)
    end

    specify "spec timeout given in amqp options has higher priority than default" do
      proc {
        amqp(:spec_timeout => 0.2) {}
      }.should raise_error SpecTimeoutExceededError
      (Time.now-@start).should be_close(0.2, 0.1)
    end

    specify "but timeout call inside amqp loop has even higher priority" do
      proc {
        amqp(:spec_timeout => 0.5) { timeout(0.2) }
      }.should raise_error SpecTimeoutExceededError
      (Time.now-@start).should be_close(0.2, 0.1)
    end

    specify "AMQP connection should not leak between examples" do
      AMQP.conn.should be_nil
    end
  end

  describe AMQP, " when testing with AMQP::SpecHelper with spec timeouts" do
    it_should_behave_like 'timeout examples'

    context 'inside embedded context / example group' do
      it_should_behave_like 'timeout examples'
#      it "should properly timeout " do
#        amqp do
#          timeout(0.2)
#        end
#      end
#      it "should properly timeout inside embedded context/describe blocks" do
#        amqp do
#        end
#      end
    end
  end

# PROBLEMATIC !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  describe AMQP, " when testing with AMQP::SpecHelper with spec timeouts" do
    include AMQP::SpecHelper

    it "should fail to provide context to next spec" do
      begin
        amqp do
          :this.should == :fail
        end
      rescue => e
        p e
      end
    end

    it "should properly close AMQP connection after Rspec failures" do
      AMQP.conn.should == nil
    end
  end

#  describe MQ, " when MQ.queue or MQ.fanout etc is trying to access Thread-local mq across examples" do
#    include AMQP::SpecHelper
#
#    default_timeout 1
#
#    it 'sends data to queue' do
#      amqp do
#        q = MQ.new.queue("test_sink")
#        q.subscribe do |hdr, data|
#          p hdr, data
#          EM.next_tick {
#            q.unsubscribe; q.delete
#            AMQP.stop { EM.stop_event_loop }
#          }
#        end
#        EM.add_timer(0.2) do
#          p Thread.current, Thread.current[:mq]
#          MQ.queue('test_sink').publish 'data' # MQ.new. !!!!!!!!!!!
#        end
#      end
#    end
#
#    it 'sends data to queue' do
#      amqp do
#        q = MQ.new.queue("test_sink")
#        q.subscribe do |hdr, data|
#          p hdr, data
#          EM.next_tick {
#            q.unsubscribe; q.delete
#            AMQP.stop { EM.stop_event_loop }
#          }
#        end
#        EM.add_timer(0.2) do
#          p Thread.current, Thread.current[:mq]
#          MQ.queue('test_sink').publish 'data' # MQ.new. !!!!!!!!!!!
#        end
#      end
#    end
#
#  end
end

context '!!!!!!!!!!! LEAKING !!!!!!!!!!!!!!!!!!' do
  describe EventMachine, " when running failing examples" do
    include AMQP::SpecHelper

    it "should not bubble failures beyond rspec" do
      amqp do
        EM.add_timer(0.1) do
          :should_not_bubble.should == :failures
          done
        end
      end
      AMQP.conn.should == nil
    end

    it "should not block on failure" do
      1.should == 2
    end
  end

  describe EventMachine, " when testing with AMQP::Spec with a maximum execution time per test" do

    include AMQP::Spec

    it 'should timeout before reaching done' do
      EM.add_timer(2) {
        done
      }
    end
  end
end


describe "Rspec", " when running an example group after another group that uses AMQP-Spec " do
  it "should work normally" do
    :does_not_hang.should_not be_false
  end
end