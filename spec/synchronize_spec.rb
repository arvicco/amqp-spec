require 'spec_helper'

describe AMQP::SpecHelper do
  include AMQP::SpecHelper

  describe "#sync[hronize]" do
    before { @fired = false }

    it 'wraps given async method call with synchronous API' do
      em do
        start = Time.now
        sync(method(:done), 0.2) { @fired = true }
        @fired.should be_true
        (Time.now - start).should be_close 0.2, 0.05
      end
    end

    it 'accepts method name as a Symbol' do
      em do
        start = Time.now
        sync(:done, 0.2) { @fired = true }
        @fired.should be_true
        (Time.now - start).should be_close 0.2, 0.05
      end
    end

    it 'accepts method name as a String' do
      em do
        start = Time.now
        sync('done', 0.2) { @fired = true }
        @fired.should be_true
        (Time.now - start).should be_close 0.2, 0.05
      end
    end

    it 'even accepts a Proc, just make sure that this proc treats given callback correctly' do
      em do
        start = Time.now
        my_proc = proc { |time, &block| done(time, &block) }
        sync(my_proc, 0.2) { @fired = true }
        @fired.should be_true
        (Time.now - start).should be_close 0.2, 0.05
      end
    end

    it 'is not confused by other object`s methods' do
      em do
        start = Time.now
        sync(EM.method(:add_timer), 0.2) { @fired = true }
        @fired.should be_true
        (Time.now - start).should be_close 0.2, 0.05
        done
      end
    end

    it 'recognizes #synchronize alias' do
      em do
        start = Time.now
        sync(method(:done), 0.2) { @fired = true }
        @fired.should be_true
        (Time.now - start).should be_close 0.2, 0.05
      end
    end

    context 'argument errors' do
      it 'complains if you omit a callback' do
        em do
          expect { sync(:done, 0.2) }.to raise_error ArgumentError
          done
        end
      end

      it 'complains if you just give it a callback, without callable' do
        em do
          expect { sync { @fired = true } }.to raise_error ArgumentError
          @fired.should be_false
          done
        end
      end

      it 'complains if you give it a wrong method name' do
        em do
          expect { sync(:zdone) { @fired = true } }.to raise_error ArgumentError
          @fired.should be_false
          done
        end
      end

      it 'complains if you give it a wrong callable' do
        em do
          expect { sync(Object.new, :done) { @fired = true } }.to raise_error ArgumentError
          @fired.should be_false
          done
        end
      end
    end # context argument errors

    context 'exceptions' do

      it 'bubbles up exceptions raised inside the callback' do
        em do
          start = Time.now
          expect {
            sync(:done, 0.2) { raise StandardError, "Blah" }
          }.to raise_error /Blah/

          (Time.now - start).should be_close 0.2, 0.05
        end
      end

      it 'bubbles up exceptions raised before callback is executed' do
        em do
          expect {
            sync(AMQP.method(:start_connection), host: 'Wrong') { @fired = true }
          }.to raise_error EventMachine::ConnectionError
          @fired.should be_false
          done
        end
      end
    end # context 'exceptions'

    context 'timeouts'
  end # describe "#synchronize"
end
