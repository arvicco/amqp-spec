require_relative 'spec_helper.rb'

# PROBLEMATIC !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
context '!!!!!!!!!!! LEAKING !!!!!!!!!!!!!!!!!!' do
  describe MQ, " when MQ.queue or MQ.fanout etc is trying to access Thread-local mq across examples" do
    include AMQP::SpecHelper

    default_timeout 1

    it 'sends data to queue' do
      amqp do
        q = MQ.new.queue("test_sink")
        q.subscribe do |hdr, data|
          p hdr, data
          EM.next_tick {
            q.unsubscribe; q.delete
            done
          }
        end
        EM.add_timer(0.2) do
          p Thread.current, Thread.current[:mq]
          MQ.queue('test_sink').publish 'data' # MQ.new. !!!!!!!!!!!
        end
      end
    end

    it 'sends data to queue' do
      amqp do
        q = MQ.new.queue("test_sink")
        q.subscribe do |hdr, data|
          p hdr, data
          EM.next_tick {
            q.unsubscribe; q.delete
            done
          }
        end
        EM.add_timer(0.2) do
          p Thread.current, Thread.current[:mq]
          MQ.queue('test_sink').publish 'data' # MQ.new. !!!!!!!!!!!
        end
      end
    end
  end

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

