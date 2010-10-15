require_relative 'spec_helper.rb'

describe 'Rspec' do
  it 'should work as normal without AMQP-Spec' do
    1.should == 1
  end
end

context 'Evented AMQP specs' do
  describe AMQP, " when testing with AMQP::SpecHelper" do
    include AMQP::SpecHelper

    default_options AMQP_OPTS if defined? AMQP_OPTS
    default_timeout 1 # Can be used to set default :spec_timeout for all your amqp-based specs

    puts "Default timeout: #{default_timeout.inspect}, Default options:"
    p default_options

    it_should_behave_like 'SpecHelper examples'
    it_should_behave_like 'timeout examples'

    context 'inside embedded context / example group' do
      it_should_behave_like 'SpecHelper examples'
      it_should_behave_like 'timeout examples'
    end
  end

  describe AMQP, " when testing with AMQP::Spec" do
    include AMQP::Spec
    it_should_behave_like 'Spec examples'

    context 'inside embedded context / example group' do
      it_should_behave_like 'Spec examples'
    end
  end

  describe AMQP, " tested with AMQP::SpecHelper when Rspec failures occur" do
    include AMQP::SpecHelper

    it "bubbles failing expectations up to Rspec" do
      proc {
        amqp do
          :this.should == :fail
        end
      }.should raise_error Spec::Expectations::ExpectationNotMetError
      AMQP.conn.should == nil
    end

    it "should NOT ignore failing expectations after 'done'" do
      proc {
        amqp do
          done
          :this.should == :fail
        end
      }.should raise_error Spec::Expectations::ExpectationNotMetError
      AMQP.conn.should == nil
    end

    it "should properly close AMQP connection after Rspec failures" do
      AMQP.conn.should == nil
    end
  end

end

describe "Rspec", " when running an example group after another group that uses AMQP-Spec " do
  it "should work normally" do
    :does_not_hang.should_not be_false
  end
end