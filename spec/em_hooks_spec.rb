require 'spec_helper'

def hook symbol=nil, reactor, connection
  @hooks_called << symbol.to_sym if symbol
  if :reactor_running == reactor
    EM.reactor_running?.should be_true
  else
    EM.reactor_running?.should be_false
  end
  if :amqp_connected == connection
    AMQP.conn.should be_connected
  else
    AMQP.conn and AMQP.conn.should_not be_connected
  end
end

shared_examples_for 'hooked em specs' do
  it 'should execute em_before' do
    em do
      @hooks_called.should include :em_before
      @hooks_called.should_not include :em_after
      done
    end
  end

  it 'should execute em_after if business exception is raised' do
    # Expectation is set in after{} hook
    em do
      expect {
        raise StandardError
      }.to raise_error
      done
    end
  end

  it 'should execute em_after if RSpec expectation fails' do
    # Expectation is set in after{} hook
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
      @hooks_called.should include :amqp_before
      @hooks_called.should_not include :amqp_after
      done
    end
  end

  it 'should execute em_after if business exception is raised' do
    # Expectation is set in after{} hook
    amqp do
      expect {
        raise StandardError
      }.to raise_error
      done
    end
  end

  it 'should execute em_after if RSpec expectation fails' do
    # Expectation is set in after{} hook
    amqp do
      expect { :this.should == :fail
      }.to raise_error RSPEC::Expectations::ExpectationNotMetError
      done
    end
  end
end

describe AMQP::SpecHelper, ".em_before/.em_after" do
  before { @hooks_called = [] }

  describe AMQP, " tested with AMQP::SpecHelper" do
    include AMQP::SpecHelper
    default_options AMQP_OPTS if defined? AMQP_OPTS

    before { hook :before, :reactor_not_running, :amqp_not_connected }
    em_before { hook :em_before, :reactor_running, :amqp_not_connected }
    em_after { hook :em_after, :reactor_running, :amqp_not_connected }

    context 'for non-evented specs' do
      after {
        @hooks_called.should == [:before]
        hook :reactor_not_running, :amqp_not_connected }

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
      after {
        @hooks_called.should include :before, :em_before, :em_after
        hook :reactor_not_running, :amqp_not_connected }

      context 'with em block' do

        it_should_behave_like 'hooked em specs'

        it 'should not run nested em hooks' do
          em do
            @hooks_called.should_not include :context_em_before, :context_before
            done
          end
        end

        it 'should not run hooks from unrelated group' do
          em do
            @hooks_called.should_not include :amqp_context_em_before,
                                             :amqp_context_before,
                                             :amqp_before,
                                             :context_amqp_before
            done
          end
        end

        context 'inside nested example group' do
          before { hook :context_before, :reactor_not_running, :amqp_not_connected }
          em_before { hook :context_em_before, :reactor_running, :amqp_not_connected }
          em_after { hook :context_em_after, :reactor_running, :amqp_not_connected }

          after { @hooks_called.should include :before,
                                               :context_before,
                                               :em_before,
                                               :context_em_before,
                                               :context_em_after,
                                               :em_after
          hook :reactor_not_running, :amqp_not_connected
          }

          it_should_behave_like 'hooked em specs'

          it 'should fire all nested :before hooks, but no :after hooks' do
            em do
              @hooks_called.should == [:before,
                                       :context_before,
                                       :em_before,
                                       :context_em_before]
              done
            end
          end

        end # context 'inside nested example group'
      end # context 'with em block'

      context 'with amqp block' do
        amqp_before { hook :amqp_before, :reactor_running, :amqp_connected }
        amqp_after { hook :amqp_after, :reactor_running, :amqp_connected }

        it_should_behave_like 'hooked amqp specs'

        it 'should not run nested em hooks' do
          amqp do
            @hooks_called.should_not include :amqp_context_before,
                                             :amqp_context_em_before,
                                             :context_amqp_before
            done
          end
        end

        it 'should not run hooks from unrelated group' do
          amqp do
            @hooks_called.should_not include :context_em_before, :context_before
            done
          end
        end

        context 'inside nested example group' do
          before { hook :amqp_context_before, :reactor_not_running, :amqp_not_connected }
          em_before { hook :amqp_context_em_before, :reactor_running, :amqp_not_connected }
          em_after { hook :amqp_context_em_after, :reactor_running, :amqp_not_connected }
          amqp_before { hook :context_amqp_before, :reactor_running, :amqp_connected }
          amqp_after { hook :context_amqp_after, :reactor_running, :amqp_connected }

          after { @hooks_called.should == [:before,
                                           :amqp_context_before,
                                           :em_before,
                                           :amqp_context_em_before,
                                           :amqp_before,
                                           :context_amqp_before,
                                           :context_amqp_after,
                                           :amqp_after,
                                           :amqp_context_em_after,
                                           :em_after]
          hook :reactor_not_running, :amqp_not_connected }

          it_should_behave_like 'hooked amqp specs'

          it 'should fire all :before hooks in correct order' do
            amqp do
              @hooks_called.should == [:before,
                                       :amqp_context_before,
                                       :em_before,
                                       :amqp_context_em_before,
                                       :amqp_before,
                                       :context_amqp_before]
              done
            end
          end

        end # context 'inside nested example group'
      end # context 'with amqp block'
    end # context 'for evented specs'
  end # describe AMQP, " tested with AMQP::SpecHelper"
end # describe AMQP, " with em_before/em_after"
