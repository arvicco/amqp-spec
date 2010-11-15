require 'spec_helper'

def publish_and_consume_once(queue_name="test_sink", data="data")
  amqp do
    q = MQ.queue(queue_name)
    q.subscribe do |hdr, msg|
      hdr.should be_an MQ::Header
      msg.should == data
      done { q.unsubscribe; q.delete }
    end
    EM.add_timer(0.2) do
      MQ.queue(queue_name).publish data
    end
  end
end

describe RSPEC do
  it 'should work as normal without AMQP-Spec' do
    1.should == 1
  end
end

describe 'Evented AMQP specs' do
  describe AMQP, " when testing with AMQP::SpecHelper" do
    include AMQP::SpecHelper

    default_options AMQP_OPTS if defined? AMQP_OPTS
    default_timeout 1

    puts "Default timeout: #{default_timeout}"
    puts "Default options :#{default_options}"

    it_should_behave_like 'SpecHelper examples'

    context 'inside embedded context / example group' do

      it_should_behave_like 'SpecHelper examples'
    end
  end

  describe AMQP, " when testing with AMQP::Spec" do
    include AMQP::Spec

    default_options AMQP_OPTS if defined? AMQP_OPTS
    default_timeout 1

    it_should_behave_like 'Spec examples'

    context 'inside embedded context / example group' do
      it 'should inherit default_options/metadata from enclosing example group' do
        # This is a guard against regression on dev box without notice
        AMQP.conn.instance_variable_get(:@settings)[:host].should == AMQP_OPTS[:host]
        self.class.default_options[:host].should == AMQP_OPTS[:host]
        self.class.default_timeout.should == 1
        done
      end

      it_should_behave_like 'Spec examples'
    end
  end

  describe AMQP, " tested with AMQP::SpecHelper when Rspec failures occur" do
    include AMQP::SpecHelper

    default_options AMQP_OPTS if defined? AMQP_OPTS

    it "bubbles failing expectations up to Rspec" do
      expect {
        amqp do
          :this.should == :fail
        end
      }.to raise_error RSPEC::Expectations::ExpectationNotMetError
      AMQP.conn.should == nil
    end

    it "should NOT ignore failing expectations after 'done'" do
      expect {
        amqp do
          done
          :this.should == :fail
        end
      }.to raise_error RSPEC::Expectations::ExpectationNotMetError
      AMQP.conn.should == nil
    end

    it "should properly close AMQP connection after Rspec failures" do
      AMQP.conn.should == nil
    end
  end

  describe 'MQ', " when MQ.queue/fanout/topic tries to access Thread.current[:mq] across examples" do
    include AMQP::SpecHelper

    default_options AMQP_OPTS if defined? AMQP_OPTS

    it 'sends data to the queue' do
      publish_and_consume_once
    end

    it 'does not hang sending data to the same queue, again' do
      publish_and_consume_once
    end

    it 'cleans Thread.current[:mq] after pubsub examples' do
      Thread.current[:mq].should be_nil
    end
  end
end

describe RSPEC, " when running an example group after another group that uses AMQP-Spec " do
  it "should work normally" do
    :does_not_hang.should_not be_false
  end
end