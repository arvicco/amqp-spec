require 'fiber' unless Fiber.respond_to?(:current)
require 'amqp-spec/amqp'

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
# TODO: Define 'async' method wrapping async requests and returning results... 'async_loop' too for subscribe block?
# TODO: 'evented_before', 'evented_after' that will be run inside EM before the example
module AMQP
#noinspection RubyArgCount
  module SpecHelper

    SpecTimeoutExceededError = Class.new(RuntimeError)

    def self.included(example_group)

      unless example_group.respond_to? :default_timeout
        example_group.instance_exec do

          # Hacking metadata in for RSpec 1
          unless respond_to?(:metadata)
            def self.metadata
              @metadata ||= superclass.send(:metadata) rescue {}
            end
          end

          metadata[:em_default_options] = {}
          metadata[:em_default_timeout] = nil

          def self.default_timeout(spec_timeout=nil)
            metadata[:em_default_timeout] = spec_timeout if spec_timeout
            metadata[:em_default_timeout]
          end

          def self.default_options(opts=nil)
            metadata[:em_default_options] = opts if opts
            metadata[:em_default_options]
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
    #
    #noinspection RubyArgCount
    def amqp opts={}, &block
      opts = self.class.default_options.merge opts
      begin
        EM.run do
          @_em_spec_with_amqp = true
          @_em_spec_exception = nil
          spec_timeout        = opts.delete(:spec_timeout) || self.class.default_timeout
          timeout(spec_timeout) if spec_timeout
          @_em_spec_fiber     = Fiber.new do
            begin
              AMQP.start_connection opts, &block
            rescue Exception => @_em_spec_exception
#              p "inner", @_em_spec_exception
              done
            end
            Fiber.yield
          end

          @_em_spec_fiber.resume
        end
      rescue Exception => outer_spec_exception
#        p "outer", outer_spec_exception unless outer_spec_exception.is_a? SpecTimeoutExceededError
        # Make sure AMQP state is cleaned even after Rspec failures
        AMQP.cleanup_state
        raise outer_spec_exception
      end
    end

    # Yields to block inside EM loop, :spec_timeout option (in seconds) is used to force spec to timeout
    # if something goes wrong and EM/AMQP loop hangs for some reason. SpecTimeoutExceededError is raised.
    def em(spec_timeout = self.class.default_timeout, &block)
      spec_timeout = spec_timeout[:spec_timeout] || self.class.default_timeout if spec_timeout.is_a?(Hash)
      EM.run do
        @_em_spec_with_amqp = false
        @_em_spec_exception = nil
        timeout(spec_timeout) if spec_timeout
        @_em_spec_fiber     = Fiber.new do
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

    # Breaks the event loop and finishes the spec. This should be called after
    # you are reasonably sure that your expectations either succeeded or failed.
    # Done yields to any given block first, then stops EM event loop.
    # For amqp specs, stops AMQP and cleans up AMQP state.
    #
    # You may pass delay (in seconds) to done. If you do so, please keep in mind
    # that your (default or explicit) spec timeout may fire before your delayed done
    # callback is due, leading to SpecTimeoutExceededError
    def done(delay=nil)
      done_proc = proc do
        yield if block_given?
        EM.next_tick do
          if @_em_spec_with_amqp
            if AMQP.conn and not AMQP.closing
              AMQP.stop_connection do
                finish_em_spec_fiber { AMQP.cleanup_state }
              end
            else
              finish_em_spec_fiber { AMQP.cleanup_state }
            end
          else
            finish_em_spec_fiber
          end
        end
      end
      if delay
        EM.add_timer delay, &done_proc
      else
        done_proc.call
      end
    end

    private

    # Stops EM loop, executes optional block, finishes off fiber and raises exception if any
    def finish_em_spec_fiber
      EM.stop_event_loop if EM.reactor_running?
      yield if block_given?
      @_em_spec_fiber.resume if @_em_spec_fiber.alive?
      raise @_em_spec_exception if @_em_spec_exception
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
