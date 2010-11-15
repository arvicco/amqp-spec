require 'spec_helper'

describe '!!!!!!!!! LEAKING OR PROBLEMATIC EXAMPLES !!!!!!!!!' do
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
      end

      context 'for evented specs' do #, pending: true do
        after { @hooks_called.should == [:before, :em_before, :em_after] }

        context 'with em block' do

          it 'should execute em_before or em_after' do
            em { @hooks_called.should include :em_before; done }
          end

          it 'should execute em_after if business exception is raised' do
            expect {
              em { raise StandardError; done }
            }.to raise_error
          end

          it 'should execute em_after if RSpec expectation fails' do
            expect {
              em { :this.should == :fail }
            }.to raise_error RSPEC::Expectations::ExpectationNotMetError
          end

          context 'inside nested example group' do
            it 'should fire all nested :before hooks'
            it 'should fire all nested :after hooks'
          end

        end

        context 'with amqp block' do

          it 'should execute em_before or em_after' do
            amqp { @hooks_called.should include :em_before; done }
          end

          it 'should execute em_after if business exception is raised' do
            expect {
              amqp { raise StandardError; done }
            }.to raise_error
          end

          it 'should execute em_after if RSpec expectation fails' do
            expect {
              amqp { :this.should == :fail }
            }.to raise_error RSPEC::Expectations::ExpectationNotMetError
          end

          context 'inside nested example group' do
            it 'should fire all nested :before hooks'
            it 'should fire all nested :after hooks'
          end

        end
      end
    end
  end
end