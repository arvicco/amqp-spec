require 'spec_helper'

describe '!!!!!!!!! LEAKING OR PROBLEMATIC EXAMPLES !!!!!!!!!' do
  describe AMQP, " with em_before/em_after" do
    describe AMQP, " tested with AMQP::SpecHelper" do
      include AMQP::SpecHelper
      default_options AMQP_OPTS if defined? AMQP_OPTS

      before { @last = :before }
      after { @last.should == :before }

      em_before { @last = :em_before }
      em_after { @last = :em_after }

      context 'for non-evented specs' do
        it 'should NOT execute em_before or em_after' do
          @last.should == :before
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

      context 'for evented specs', pending: true do
        after { @last.should == :em_after }

        it 'should execute em_before or em_after if em block is used' do
          em { @last.should == :em_before; done }
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

        it 'should execute em_before or em_after if em block is used' do
          amqp { @last.should == :em_before; done }
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
      end
    end
  end
end