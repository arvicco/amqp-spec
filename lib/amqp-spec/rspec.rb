require 'mq'
require 'fiber' unless Fiber.respond_to?(:current)

# You can include one of the following modules into your example groups:
# AMQP::SpecHelper
# AMQP::Spec
#
# AMQP::SpecHelper module defines 'ampq' method that can be safely used inside your specs(examples)
# to test expectations inside running AMQP.start loop. Each loop is running in a separate Fiber,
# and you can control for timeouts using either :spec_timeout option given to amqp method,
# or setting default timeout with class method default_timeout(timeout).
#
# If you include AMQP::Spec module into your example group, each example of this group will run
# inside AMQP.start loop without the need to explicitly call 'amqp'. In order to provide options
# to AMQP loop, default_options class method is defined. Remember, when using AMQP::Specs, you
# will have a single set of AMQP.start options for all your examples.
#
# In order to stop AMQP loop, you should call 'done' AFTER you are sure that your example is finished.
# For example, if you are using subscribe block that tests expectations on messages, 'done' should be
# probably called at the end of this block.
#
# TODO: Define 'async' method wrapping async requests and returning results... 'async_loop' too for subscribe?
# TODO: 'evented_before', 'evented_after' that will be run inside EM before the example
module AMQP
  module SpecHelper

    SpecTimeoutExceededError = Class.new(RuntimeError)

    def self.included(example_group)
      ::Spec::Example::ExampleGroup.instance_exec do
        unless defined? default_spec_timeout

          @@_em_default_options = {}
          @@_em_default_timeout = nil

          def self.default_spec_timeout(spec_timeout=nil)
            if spec_timeout
              @@_em_default_timeout = spec_timeout
            else
              @@_em_default_timeout
            end
          end
          alias default_timeout default_spec_timeout

          def self.default_options(opts=nil)
            if opts
              @@_em_default_options = opts
            else
              @@_em_default_options
            end
          end
        end
      end
    end

    # Yields to given block inside EM.run and AMQP.start loops. This method takes any option that is
    # also accepted by EventMachine::connect. Also, options for AMQP.start include:
    # * :user => String (default ‘guest’) - The username as defined by the AMQP server.
    # * :pass => String (default ‘guest’) - The password for the associated :user as defined by the AMQP server.
    # * :vhost => String (default ’/’)    - The virtual host as defined by the AMQP server.
    # * :timeout => Numeric (default nil) - *Connection* timeout, measured in seconds.
    # * :logging => true | false (default false) - Toggle the extremely verbose AMQP logging.
    #
    # In addition to EM and AMQP options, :spec_timeout option (in seconds) is used to force spec to timeout
    # if something goes wrong and EM/AMQP loop hangs for some reason. SpecTimeoutExceededError is raised.

    def amqp opts={}, &block
      opts = @@_em_default_options.merge opts
      EM.run do
#        begin ?
        @_em_spec_with_amqp = true
        @_em_spec_exception = nil
        spec_timeout = opts.delete(:spec_timeout) || @@_em_default_timeout
        timeout(spec_timeout) if spec_timeout
        @_em_spec_fiber = Fiber.new do
          begin
            amqp_start opts, &block
          rescue Exception => @_em_spec_exception
            p @_em_spec_exception
            done
          end
          Fiber.yield
        end

        @_em_spec_fiber.resume
#        raise @_em_spec_exception if @_em_spec_exception
      end
    end

    # Yields to block inside EM loop, :spec_timeout option (in seconds) is used to force spec to timeout
    # if something goes wrong and EM/AMQP loop hangs for some reason. SpecTimeoutExceededError is raised.
    # TODO: accept :spec_timeout =>1 as a Hash for compatibility with amqp interface
    def em(spec_timeout = @@_em_default_timeout, &block)
      EM.run do
        @_em_spec_with_amqp = false
        @_em_spec_exception = nil
        timeout(spec_timeout) if spec_timeout
        @_em_spec_fiber = Fiber.new do
          begin
            block.call
          rescue Exception => @_em_spec_exception
            done
          end
          Fiber.yield
        end

        @_em_spec_fiber.resume
      end
    end

    # Sets timeout for current spec
    def timeout(spec_timeout)
      EM.cancel_timer(@_em_timer) if @_em_timer
      @_em_timer = EM.add_timer(spec_timeout) do
        @_em_spec_exception = SpecTimeoutExceededError.new
        done
      end
    end

    # Stops AMQP and EM event loop
    def done
      EM.next_tick do
        if @_em_spec_with_amqp
          amqp_stop(@_em_spec_exception) do
            finish_em_spec_fiber
          end
        else
          finish_em_spec_fiber
          raise @_em_spec_exception if @_em_spec_exception
        end
      end
    end

    private

    def finish_em_spec_fiber
      EM.stop_event_loop if EM.reactor_running?
#      p Thread.current, Thread.current[:mq], __LINE__
      @_em_spec_fiber.resume if @_em_spec_fiber.alive?
    end

    # Private method that initializes AMQP client/connection without starting another EM loop
    def amqp_start opts={}, &block
      AMQP.instance_exec do
#  p Thread.current, Thread.current[:mq]
        puts "!!!!!!!!! Existing connection: #{@conn}" if @conn
        @conn = connect opts
#       @conn ||= connect opts
        @conn.callback(&block) if block
      end
    end

    # Private method that closes AMQP connection and raises optional
    # exception AFTER the AMQP connection is 100% closed
    def amqp_stop exception
      if AMQP.conn and not AMQP.closing
        AMQP.instance_exec do #(@_em_spec_exception) do |exception|
          @closing = true
          @conn.close {
            yield if block_given?
            @conn = nil
            @closing = false
            raise exception if exception
          }
        end
      end
    end
  end

  module Spec
    def self.included(cls)
      cls.send(:include, SpecHelper)
    end

    def instance_eval(&block)
      amqp do
        super(&block)
      end
    end
  end

  module EMSpec
    def self.included(cls)
      cls.send(:include, SpecHelper)
    end

    def instance_eval(&block)
      em do
        super(&block)
      end
    end
  end
end


