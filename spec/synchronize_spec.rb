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

    it 'complains if you omit a block' do
      expect {
        em do
          start = Time.now
          sync(:done, 0.2)
          @fired.should be_false
        end
      }.to raise_error ArgumentError
    end

    it 'complains if you just give it a callback' do
      expect {
        em do
          start = Time.now
          sync { done(0.2) { @fired = true } }
          (Time.now - start).should be_close 0.2, 0.05
          @fired.should be_true
        end
      }.to raise_error ArgumentError
    end

    it 'recognizes #synchronize alias' do
      em do
        start = Time.now
        sync(method(:done), 0.2) { @fired = true }
        @fired.should be_true
        (Time.now - start).should be_close 0.2, 0.05
      end
    end

  end
end
