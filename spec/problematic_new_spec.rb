require 'spec_helper'


describe '!!!!!!!!! LEAKING OR PROBLEMATIC EXAMPLES !!!!!!!!!' do
  describe AMQP, " with em_before/em_after", pending: true do

    describe "non-evented specs with AMQP::SpecHelper" do
      before { @hooks_called = [] }
      include AMQP::SpecHelper
      default_options AMQP_OPTS if defined? AMQP_OPTS

      before { @hooks_called << :before }
      em_before { @hooks_called << :em_before }
      em_after { @hooks_called << :em_after }

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
    end # non-evented specs with AMQP::SpecHelper

    describe "evented specs with AMQP::Spec" do
      include AMQP::EMSpec
#      default_options AMQP_OPTS if defined? AMQP_OPTS

      before { @hooks_called = []; done } #; puts "In before: #{self}"}  #

      before { @hooks_called << :before; done }
      em_before { @hooks_called << :em_before }
      em_after { @hooks_called << :em_after }

      after { @hooks_called.should include :before, :em_before, :em_after; done }

#      context 'with em block' do
      it 'should fucking work' do
        p "was here"
        expect {
          p @hooks_called
        @hooks_called.should include :em_before }.to_not raise_error
        p "and here"
        #@hooks_called.should_not include :em_after
        p "and here"
        done
        p "and even here"
      end

        it_should_behave_like 'hooked specs'
#
#        context 'inside nested example group' do
#          before { @hooks_called << :context_before; done }
#          em_before { @hooks_called << :context_em_before }
#          em_after { @hooks_called << :context_em_after }
#
#          after { @hooks_called.should include :before,
#                                               :context_before,
#                                               :em_before,
#                                               :context_em_before,
#                                               :context_em_after,
#                                               :em_after; done }
#
#          it_should_behave_like 'hooked specs'
#
#          it 'should fire both nested :before hooks' do
#            @hooks_called.should include :em_before, :context_em_before
#            @hooks_called.should_not include :em_after, :context_em_after
#            done
#          end
#        end
#
#      end
#
#      context 'with amqp block' do
#
#        it 'should execute em_before or em_after' do
#          amqp { @hooks_called.should include :em_before; done }
#        end
#
#        it 'should execute em_after if business exception is raised' do
#          expect {
#            amqp { raise StandardError; done }
#          }.to raise_error
#        end
#
#        it 'should execute em_after if RSpec expectation fails' do
#          expect {
#            amqp { :this.should == :fail }
#          }.to raise_error RSPEC::Expectations::ExpectationNotMetError
#        end
#
#        context 'inside nested example group' do
#          it 'should fire all nested :before hooks'
#          it 'should fire all nested :after hooks'
#        end
#
#      end
    end # "evented specs with AMQP::SpecHelper"
  end
end
