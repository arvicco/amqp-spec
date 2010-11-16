require 'fiber' unless Fiber.respond_to?(:current)

module AMQP
  # AMQP::SpecHelper module defines #ampq and #em methods that can be safely used inside
  # your specs (examples) to test code running inside AMQP.start or EM.run loop
  # respectively. Each example is running in a separate event loop,you can control
  # for timeouts either with :spec_timeout option given to #amqp/#em method or setting
  # a default timeout using default_timeout(timeout) macro inside describe/context block.
  #
  #
  module SpecHelper

    # Represents any type of spec supposed to run inside event loop
    class EventedExample

      # Create new event loop
      def initialize type, opts = {}, spec_timeout, example_group_instance, &block
        @type, @opts, @spec_timeout, @example_group_instance, @block = type, opts, spec_timeout, example_group_instance, block
      end

      # Run @block inside the event loop
      def run
        if @type = :amqp
          @_em_spec_with_amqp = true
          begin
            run_em_loop @spec_timeout do
              AMQP.start_connection @opts, &@block
            end
          rescue Exception => outer_spec_exception
            AMQP.cleanup_state
            raise outer_spec_exception
          end
        elsif @type = :em
          @_em_spec_with_amqp = false
          run_em_loop @spec_timeout, &@block
        end
      end

      # Sets timeout for current running example
      #
      def timeout(spec_timeout)
        EM.cancel_timer(@_em_timer) if @_em_timer
        @_em_timer = EM.add_timer(spec_timeout) do
          @_em_spec_exception = SpecTimeoutExceededError.new "Example timed out"
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
                  finish_em_loop { AMQP.cleanup_state }
                end
              else
                finish_em_loop { AMQP.cleanup_state }
              end
            else
              finish_em_loop
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
        @metadata ||= @example_group_instance.metadata.dup rescue {}
      end

      # Wraps async method with a callback into a synchronous method call
      # that returns only after callback is finished (or exception raised)
      #
      # TODO: Only works in fibered environment, such as Thin
      # TODO: should we add exception processing here?
      # TODO: what do we do in case if errback fires instead of callback?
      # TODO: it may happen that callback is never called, and no exception raised either...
      #
      #noinspection RubyArgCount
      def sync *args, &callback
        callable, args = callable_from *args, &callback
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
        return case args.first
                 when Method, Proc
                   args.shift
                 when nil
                   raise ArgumentError, 'Expects async callable (possibly with args)'
                 when Symbol, String
                   method_name = args.shift
                   raise ArgumentError, "Wrong method name #{method_name}" unless respond_to? method_name
                   method(method_name)
                 else
                   object = args.shift
                   method_name = args.shift
                   raise ArgumentError, "Wrong method name #{method_name}" unless object.respond_to? method_name
                   object.method(method_name)
               end, args
      end

      # Stops EM loop, executes optional given block
      #
      def finish_em_loop
        run_hooks :after
        EM.stop_event_loop if EM.reactor_running?
        yield if block_given?
      end

      # Runs hooks of specified type (hopefully, inside the event loop)
      #
      def run_hooks type
        hooks = @example_group_instance.class.em_hooks[type]
        (:before == type ? hooks : hooks.reverse).each do |hook|
          if @example_group_instance.respond_to? :instance_eval_without_event_loop
            @example_group_instance.instance_eval_without_event_loop(&hook)
          else
            @example_group_instance.instance_eval(&hook) #_with_rescue(&hook)
          end
        end
      end

      # Runs given block inside separate EM event-loop fiber
      #
      def run_em_loop spec_timeout
        begin
          EM.run do
            run_hooks :before

            @_em_spec_exception = nil
            timeout(spec_timeout) if spec_timeout
            begin
              yield
            rescue Exception => @_em_spec_exception
#              p "Inside loop, caught #{@_em_spec_exception}"
              done # We need to properly terminate the event loop
            end
          end
        rescue Exception => @_em_spec_exception
#          p "Outside loop, caught #{@_em_spec_exception}"
          run_hooks :after # Event loop was broken, but we still need to run em_after hooks
        ensure
          raise @_em_spec_exception if @_em_spec_exception
        end
      end

    end # class EventedLoop

    # Represents spec running inside AMQP.run loop
    class EMExample < EventedExample
      # Create new event loop
      def initialize spec_timeout, example_group_instance, &block
        @spec_timeout, @example_group_instance, @block = spec_timeout, example_group_instance, block
      end

      # Run @block inside the EM.run event loop
      def run
        run_em_loop @spec_timeout, &@block
      end

      # Breaks the EM event loop and finishes the spec.
      # Done yields to any given block first, then stops EM event loop.
      #
      def done(delay=nil)
        done_proc = proc do
          yield if block_given?
          EM.next_tick do
            finish_em_loop
          end
        end
        if delay
          EM.add_timer delay, &done_proc
        else
          done_proc.call
        end
      end

    end

    # Represents spec running inside AMQP.run loop
    class AMQPExample < EventedExample
      # Create new event loop
      def initialize opts = {}, spec_timeout, example_group_instance, &block
        @opts, @spec_timeout, @example_group_instance, @block = opts, spec_timeout, example_group_instance, block
      end

      # Run @block inside the AMQP.start loop
      def run
        @_em_spec_with_amqp = true
        begin
          run_em_loop @spec_timeout do
            AMQP.start_connection @opts, &@block
          end
        rescue Exception => outer_spec_exception
          AMQP.cleanup_state
          raise outer_spec_exception
        end
      end

      # Breaks the event loop and finishes the spec. It yields to any given block first,
      # then stops AMQP, EM event loop and cleans up AMQP state.
      #
      # TODO: break up with proc sent to super
      #
      def done(delay=nil)
        done_proc = proc do
          yield if block_given?
          EM.next_tick do
            if AMQP.conn and not AMQP.closing
              AMQP.stop_connection do
                finish_em_loop { AMQP.cleanup_state }
              end
            else
              finish_em_loop { AMQP.cleanup_state }
            end
          end
        end
        if delay
          EM.add_timer delay, &done_proc
        else
          done_proc.call
        end
      end
    end
  end
end
