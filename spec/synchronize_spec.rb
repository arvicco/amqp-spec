require 'spec_helper'

describe AMQP::SpecHelper do
  include AMQP::SpecHelper

  describe "#sync[hronize]" do

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

    it 'accepts optional object that method can be called upon' do
      em do
        start = Time.now
        sync(EM, :add_timer, 0.2) { @fired = true }
        @fired.should be_true
        (Time.now - start).should be_close 0.2, 0.05
        done
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

  end
end