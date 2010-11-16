require 'spec_helper'

shared_examples_for 'hooked em specs' do
  it 'should execute em_before' do
    em do
      @hooks_called.should include :em_before
      @hooks_called.should_not include :em_after
      done
    end
  end

  it 'should execute em_after if business exception is raised' do
    em do
      expect {
        raise StandardError
      }.to raise_error
      done
    end
  end

  it 'should execute em_after if RSpec expectation fails' do
    em do
      expect { :this.should == :fail
      }.to raise_error RSPEC::Expectations::ExpectationNotMetError
      done
    end
  end
end

shared_examples_for 'hooked amqp specs' do
  it 'should execute em_before' do
    amqp do
      @hooks_called.should include :em_before
      @hooks_called.should_not include :em_after
      done
    end
  end

  it 'should execute em_after if business exception is raised' do
    amqp do
      expect {
        raise StandardError
      }.to raise_error
      done
    end
  end

  it 'should execute em_after if RSpec expectation fails' do
    amqp do
      expect { :this.should == :fail
      }.to raise_error RSPEC::Expectations::ExpectationNotMetError
      done
    end
  end
end

describe AMQP, " with em_before/em_after" do
  before { @hooks_called = [] } #; puts "In before: #{self}"}  #

  describe AMQP, " tested with AMQP::SpecHelper" do
    include AMQP::SpecHelper
    default_options AMQP_OPTS if defined? AMQP_OPTS

    before { @hooks_called << :before } #; puts "In before 2: #{self}" }

    em_before { @hooks_called << :em_before } # puts "In em_before: #{self}";
    em_after { @hooks_called << :em_after } # puts "In em_after: #{self}";

    context 'for non-evented specs' do
      after { @hooks_called.should == [:before] }

      it 'should NOT execute em_before or em_after' do
        @hooks_called.should_not include :em_before
        @hooks_called.should_not include :em_after
      end

      it 'should NOT execute em_after if business exception is raised' do
        expect { raise StandardError
        }.to raise_error
      end

      it 'should execute em_after if RSpec expectation fails' do
        expect { :this.should == :fail
        }.to raise_error RSPEC::Expectations::ExpectationNotMetError
      end
    end # context 'for non-evented specs'

    context 'for evented specs' do #, pending: true do
      after { @hooks_called.should include :before, :em_before, :em_after }

      context 'with em block' do

        it_should_behave_like 'hooked em specs'

        context 'inside nested example group' do
          before { @hooks_called << :context_before }
          em_before { @hooks_called << :context_em_before }
          em_after { @hooks_called << :context_em_after }

          after { @hooks_called.should include :before,
                                               :context_before,
                                               :em_before,
                                               :context_em_before,
                                               :context_em_after,
                                               :em_after }

          it 'should fire both nested :before hooks' do
            em do
              @hooks_called.should include :before,
                                           :context_before,
                                           :em_before,
                                           :context_em_before
              @hooks_called.should_not include :em_after, :context_em_after
              done
            end
          end

          it_should_behave_like 'hooked em specs'

        end # context 'inside nested example group'
      end # context 'with em block'

      context 'with amqp block' do

        it_should_behave_like 'hooked amqp specs'

        context 'inside nested example group' do
          before { @hooks_called << :context_before }
          em_before { @hooks_called << :context_em_before }
          em_after { @hooks_called << :context_em_after }

          after { @hooks_called.should include :before,
                                               :context_before,
                                               :em_before,
                                               :context_em_before,
                                               :context_em_after,
                                               :em_after }

          it 'should fire both nested :before hooks' do
            amqp do
              @hooks_called.should include :before,
                                           :context_before,
                                           :em_before,
                                           :context_em_before
              @hooks_called.should_not include :em_after, :context_em_after
              done
            end
          end

          it_should_behave_like 'hooked amqp specs'

        end # context 'inside nested example group'
      end # context 'with amqp block'
    end # context 'for evented specs'
  end # describe AMQP, " tested with AMQP::SpecHelper"
end # describe AMQP, " with em_before/em_after"
