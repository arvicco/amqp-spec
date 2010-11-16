shared_examples_for 'SpecHelper examples' do
  after do
    EM.reactor_running?.should == false
    AMQP.conn.should be_nil
  end

  it "should not require a call to done when #em/#amqp is not used" do
    1.should == 1
  end

  it "should properly work" do
    amqp { done }
  end

  it "should have timers" do
    start = Time.now
    amqp do
      EM.add_timer(0.5) {
        (Time.now-start).should be_close(0.5, 0.1)
        done
      }
    end
  end

  it 'should have deferrables' do
    amqp do
      defr = EM::DefaultDeferrable.new
      defr.timeout(0.5)
      defr.errback {
        done
      }
    end
  end

  it "should run AMQP.start loop with options given to #amqp" do
    amqp(:vhost => '/', :user => 'guest') do
      AMQP.conn.should be_connected
      done
    end
  end

  it "should properly close AMQP connection if block completes normally" do
    amqp do
      AMQP.conn.should be_connected
      done
    end
    AMQP.conn.should be_nil
  end

  # TODO: remove dependency on (possibly long) DNS lookup
  it "should gracefully exit if no AMQP connection was made" do
    expect {
      amqp(:host => 'Impossible') do
        AMQP.conn.should be_nil
        done
      end
    }.to raise_error EventMachine::ConnectionError
    AMQP.conn.should be_nil
  end

  it_should_behave_like 'done examples'

  it_should_behave_like 'timeout examples'
end

shared_examples_for 'done examples' do

  it 'should yield to block given to done (when amqp is used)' do
    amqp do
      done { @block_called = true; EM.reactor_running?.should == true }
    end
    @block_called.should == true
  end

  it 'should yield to block given to done (when em is used)' do
    em do
      done { @block_called = true; EM.reactor_running?.should == true }
    end
    @block_called.should == true
  end

  it 'should have delayed done (when amqp is used)' do
    start = Time.now
    amqp do
      done(0.2) { @block_called = true; EM.reactor_running?.should == true }
    end
    @block_called.should == true
    (Time.now-start).should be_close(0.2, 0.1)
  end

  it 'should have delayed done (when em is used)' do
    start = Time.now
    em do
      done(0.2) { @block_called = true; EM.reactor_running?.should == true }
    end
    @block_called.should == true
    (Time.now-start).should be_close(0.2, 0.1)
  end
end

shared_examples_for 'timeout examples' do
  before { @start = Time.now }

  it 'should timeout before reaching done because of default spec timeout' do
    expect { amqp { EM.add_timer(2) { done } } }.
        to raise_error SpecTimeoutExceededError
    (Time.now-@start).should be_close(1.0, 0.1)
  end

  it 'should timeout before reaching done because of explicit in-loop timeout' do
    expect {
      amqp do
        timeout(0.2)
        EM.add_timer(0.5) { done }
      end
    }.to raise_error SpecTimeoutExceededError
    (Time.now-@start).should be_close(0.2, 0.1)
  end

  specify "spec timeout given in amqp options has higher priority than default" do
    expect { amqp(:spec_timeout => 0.2) {} }.
        to raise_error SpecTimeoutExceededError
    (Time.now-@start).should be_close(0.2, 0.1)
  end

  specify "but timeout call inside amqp loop has even higher priority" do
    expect { amqp(:spec_timeout => 0.5) { timeout(0.2) } }.
        to raise_error SpecTimeoutExceededError
    (Time.now-@start).should be_close(0.2, 0.1)
  end

  specify "AMQP connection should not leak between examples" do
    AMQP.conn.should be_nil
  end

  context 'embedded context can set up separate defaults' do
    default_timeout 0.2 # Can be used to set default :spec_timeout for all evented specs

    specify 'default timeout should be 0.2' do
      expect { em { EM.add_timer(2) { done } } }.to raise_error SpecTimeoutExceededError
      (Time.now-@start).should be_close(0.2, 0.1)
    end

    context 'deeply embedded context can set up separate defaults' do
      default_timeout 0.5

      specify 'default timeout should be 0.5' do
        expect { amqp { EM.add_timer(2) { done } } }.to raise_error SpecTimeoutExceededError
        (Time.now-@start).should be_close(0.5, 0.1)
      end
    end
  end
end

shared_examples_for 'Spec examples' do
  after do
    EM.reactor_running?.should == true
#      AMQP.conn.should be_nil # You're inside running amqp block, stupid!
    done
  end

  it 'should work' do
    done
  end

  it 'should have timers' do
    start = Time.now

    EM.add_timer(0.2) {
      (Time.now-start).should be_close(0.2, 0.1)
      done
    }
  end

  it 'should have periodic timers' do
    num = 0
    start = Time.now

    timer = EM.add_periodic_timer(0.2) {
      if (num += 1) == 2
        (Time.now-start).should be_close(0.5, 0.1)
        EM.cancel_timer timer
        done
      end
    }
  end

  it 'should have deferrables' do
    defr = EM::DefaultDeferrable.new
    defr.timeout(0.2)
    defr.errback {
      done
    }
  end
end