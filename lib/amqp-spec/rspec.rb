require 'fiber' unless Fiber.respond_to?(:current)
require 'amqp-spec/amqp'

# You can include one of the following modules into your example groups:
# AMQP::SpecHelper,
# AMQP::Spec,
# AMQP::EMSpec.
#
# AMQP::SpecHelper module defines #ampq method that can be safely used inside your specs(examples)
# to test expectations inside running AMQP.start loop. Each loop is running in a separate Fiber,
# and you can control for timeouts using either :spec_timeout option given to #amqp method,
# or setting default timeout with class method default_timeout(timeout). In addition to #amqp
# method, you can use #em method - it creates plain EM.run loop without starting AMQP.
#
# If you include AMQP::Spec module into your example group, each example of this group will run
# inside AMQP.start loop without the need to explicitly call 'amqp'. In order to provide options
# to AMQP loop, default_options class method is defined. Remember, when using AMQP::Specs, you
# will have a single set of AMQP.start options for all your examples.
#
# Including AMQP::EMSpec module into your example group, each example of this group will run
# inside EM.run loop without the need to explicitly call 'em'.
#
# In order to stop AMQP/EM loop, you should call 'done' AFTER you are sure that your example is finished.
# For example, if you are using subscribe block that tests expectations on messages, 'done' should be
# probably called at the end of this block.
#
#noinspection ALL
module AMQP
  # AMQP::SpecHelper module defines #ampq method that can be safely used inside your specs(examples)
  # to test expectations inside running AMQP.start loop. Each loop is running in a separate Fiber,
  # and you can control for timeouts using either :spec_timeout option given to #amqp method,
  # or setting default timeout with class method default_timeout(timeout). In addition to #amqp
  # method, you can use #em method - it creates plain EM.run loop without starting AMQP.
  #
  # TODO: Define 'async' method wrapping async requests and returning results... 'async_loop' too for subscribe block?
  # TODO: 'em_before', 'em_after' that will be run inside EM before/after each example
  # TODO: 'amqp_before', 'amqp_after' that will be run inside AMQP.start loop before/after the example
  #
  # noinspection RubyArgCount
  module SpecHelper

    SpecTimeoutExceededError = Class.new(RuntimeError)

    # Class methods (macros) for example group that includes SpecHelper
    #
    module GroupMethods
      unless respond_to?(:metadata)
        # Hacking in metadata into RSpec1 to imitate Rspec2's metadata.
        # You can add to metadata Hash to pass options into examples and
        # nested groups.
        #
        def metadata
          @metadata ||= superclass.metadata.dup rescue {}
        end
      end

      # Sets/retrieves default timeout for running evented specs for this
      # example group and its nested groups.
      #
      def default_timeout(spec_timeout=nil)
        metadata[:em_default_timeout] = spec_timeout if spec_timeout
        metadata[:em_default_timeout]
      end

      # Sets/retrieves default AMQP.start options for this example group
      # and its nested groups.
      #
      def default_options(opts=nil)
        metadata[:em_default_options] = opts if opts
        metadata[:em_default_options]
      end

      # before hook that will run inside EM event loop
      def em_before *args, &block
        scope, options = scope_and_options_from(*args)
        em_hooks[:before][scope] << block
      end

      # after hook that will run inside EM event loop
      def em_after *args, &block
        scope, options = scope_and_options_from(*args)
        em_hooks[:after][scope] << block
      end

      # Collection of evented hooks
      def em_hooks
        metadata[:em_hooks] ||= {
            :around => {:each => []},
            :before => {:each => [], :all => [], :suite => []},
            :after => {:each => [], :all => [], :suite => []}
        }
      end

      def scope_and_options_from(scope=:each, options={})
        if Hash === scope
          options = scope
          scope = :each
        end
        return scope, options
      end
    end

    def self.included(example_group)
      unless example_group.respond_to? :default_timeout
        example_group.extend(GroupMethods)
        example_group.metadata[:em_default_options] = {}
        example_group.metadata[:em_default_timeout] = nil
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
    def amqp opts={}, &block
      opts = self.class.default_options.merge opts
      spec_timeout  = opts.delete(:spec_timeout) || self.class.default_timeout
      @event_loop = EventLoop.new(:amqp, opts, spec_timeout, &block)
      @event_loop.run
    end

    # Yields to block inside EM loop, :spec_timeout option (in seconds) is used to force spec to timeout
    # if something goes wrong and EM/AMQP loop hangs for some reason. SpecTimeoutExceededError is raised.
    #
    def em(spec_timeout = self.class.default_timeout, &block)
      spec_timeout = spec_timeout[:spec_timeout] || self.class.default_timeout if spec_timeout.is_a?(Hash)
      @event_loop = EventLoop.new(:em, spec_timeout, &block)
      @event_loop.run
    end

    def done *args, &block
      @event_loop.done *args, &block
    end

    def timeout *args
      @event_loop.timeout *args
    end

    def sync *args, &block
      @event_loop.sync *args, &block
    end

    # Represents any type of spec supposed to run inside event loop
    class EventLoop

      def initialize type, opts = {}, spec_timeout, &block
        @type, @spec_timeout, @opts, @block = type, spec_timeout, opts, block
      end

      def run
        if @type = :amqp
          @_em_spec_with_amqp = true
          begin
            run_em_spec_fiber @spec_timeout, @opts, &@block
          rescue Exception => outer_spec_exception
            # Make sure AMQP state is cleaned even after Rspec failures
#        puts "In amqp, caught '#{outer_spec_exception}', @_em_spec_exception: '#{@_em_spec_exception}'"
            AMQP.cleanup_state
            raise outer_spec_exception
          end
        else
          @_em_spec_with_amqp = false
          run_em_spec_fiber @spec_timeout, &@block
        end
      end

      # Sets timeout for current running example
      #
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
      #
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

      # Retrieves metadata passed in from enclosing example groups
      #
      def metadata
        @metadata ||= self.class.metadata.dup rescue {}
      end

      # Wraps async method with a callback into a synchronous method call
      # that returns only after callback is finished (or exception raised)
      #
      # TODO: should we add exception processing here?
      # TODO: what do we do in case if errback fires instead of callback?
      # TODO: it may happen that callback is never called, and no exception raised either...
      #
      def sync *args, &callback
        args, callable = callable_from *args, &callback
        fiber = Fiber.current
        callable.call(*args) do |*returns|
          fiber.resume callback.call(*returns)
        end

        Fiber.yield
      end

      alias synchronize sync

      private

      # Used to extract async callable from given arguments
      def callable_from *args, &callback
        raise ArgumentError, 'Sync method expects callback block' unless callback
        callable = case args.first
                     when Method, Proc
                       args.shift
                     when nil
                       raise ArgumentError, 'Sync method expects async callable (possibly with args)'
                     when Symbol, String
                       method_name = args.shift
                       raise ArgumentError, "Wrong method name #{method_name}" unless respond_to? method_name
                       method(method_name)
                     else
                       object = args.shift
                       method_name = args.shift
                       raise ArgumentError, "Wrong method name #{method_name}" unless object.respond_to? method_name
                       object.method(method_name)
                   end
        [args, callable]
      end

      # Stops EM loop, executes optional block, finishes off fiber and raises exception if any
      #
      def finish_em_spec_fiber
#        self.class.em_hooks[:after][:each].reverse.each { |hook| instance_eval_with_rescue(&hook) }
        EM.stop_event_loop if EM.reactor_running?
        yield if block_given?
        @_em_spec_fiber.resume if @_em_spec_fiber.alive?
        raise @_em_spec_exception if @_em_spec_exception
      end

      # Runs given block inside separate EM event-loop fiber
      #
      # TODO: difference between #em and #amqp is in following: in line 221,
      # TODO: block is EXECUTED for #em, but only added as callback for #amqp.
      # TODO: therefore, fiber ends for amqp before block's execution even started
      #
      # TODO: probably, this can be corrected by introducing another fiber,
      # TODO: this time wrapping AMQP.start async action... #syncronize, anyone?
      #
      def run_em_spec_fiber spec_timeout, opts = {}, &block
        EM.run do
          # Running em_before hooks
#          self.class.em_hooks[:before][:each].each { |hook| instance_eval(&hook) }

          @_em_spec_exception = nil
          timeout(spec_timeout) if spec_timeout
          @_em_spec_fiber = Fiber.new do
            begin
              if @_em_spec_with_amqp
                sync AMQP.method(:start_connection), opts, &block
              else
                block.call
              end
            rescue Exception => @_em_spec_exception
#            puts "In inner run_em_spec_fiber, caught '#{@_em_spec_exception}'"
              done
            end
            Fiber.yield
          end
          @_em_spec_fiber.resume
        end
      end

    end # class EventedLoop

    # Represents spec running inside AMQP.run loop
    class EMLoop < EventLoop

    end

# Represents spec running inside AMQP.run loop
    class AMQPLoop < EventLoop

    end
  end # module SpecHelper

# If you include AMQP::Spec module into your example group, each example of this group will run
# inside AMQP.start loop without the need to explicitly call 'amqp'. In order to provide options
# to AMQP loop, default_options class method is defined. Remember, when using AMQP::Specs, you
# will have a single set of AMQP.start options for all your examples.
#
  module Spec
    def self.included(example_group)
      example_group.send(:include, SpecHelper)
    end

    def instance_eval(&block)
      amqp do
        super(&block)
      end
    end
  end

# Including AMQP::EMSpec module into your example group, each example of this group will run
# inside EM.run loop without the need to explicitly call 'em'.
#
  module EMSpec
    def self.included(example_group)
      example_group.send(:include, SpecHelper)
    end

    def instance_eval(&block)
      em do
        super(&block)
      end
    end
  end
end