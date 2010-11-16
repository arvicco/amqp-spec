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
      def initialize opts = {}, example_group_instance, &block
        @opts, @example_group_instance, @block = opts, example_group_instance, block
      end

      # Sets timeout for currently running example
      #
      def timeout(spec_timeout)
        EM.cancel_timer(@spec_timer) if @spec_timer
        @spec_timer = EM.add_timer(spec_timeout) do
          @spec_exception = SpecTimeoutExceededError.new "Example timed out"
          done
        end
      end

      # Breaks the event loop and finishes the spec. This should be called after
      # you are reasonably sure that your expectations either succeeded or failed.
      #
      # This is under-implemented (generic) method that only implements optional delay.
      # It should be given a block that does actual work of finishing up the event loop
      # and cleaning any remaining artifacts.
      #
      # Please redefine it inside descendant class and call super.
      #
      def done delay=nil, &block
        if delay
          EM.add_timer delay, &block
        else
          block.call
        end
      end

      # Retrieves metadata passed in from enclosing example groups
      #
      def metadata
        @metadata ||= @example_group_instance.metadata.dup rescue {}
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
      def run_em_loop
        begin
          EM.run do
            run_hooks :before

            @spec_exception = nil
            timeout(@opts[:spec_timeout]) if @opts[:spec_timeout]
            begin
              yield
            rescue Exception => @spec_exception
#              p "Inside loop, caught #{@spec_exception}"
              done # We need to properly terminate the event loop
            end
          end
        rescue Exception => @spec_exception
#          p "Outside loop, caught #{@spec_exception}"
          run_hooks :after # Event loop was broken, but we still need to run em_after hooks
        ensure
          finish_example
        end
      end

      # Stops EM event loop. It is called from #done
      #
      def finish_em_loop
        run_hooks :after
        EM.stop_event_loop if EM.reactor_running?
      end

      # Called from run_event_loop when event loop is finished, before any exceptions
      # is raised or example returns.
      #
      # Descendant classes may redefine to clean up type-specific state.
      #
      def finish_example
        raise @spec_exception if @spec_exception
      end

    end # class EventedLoop

    # Represents spec running inside AMQP.run loop
    class EMExample < EventedExample

      # Run @block inside the EM.run event loop
      def run
        run_em_loop &@block
      end

      # Breaks the EM event loop and finishes the spec.
      # Done yields to any given block first, then stops EM event loop.
      #
      def done(delay=nil)
        super(delay) do
          yield if block_given?
          EM.next_tick do
            finish_em_loop
          end
        end
      end # done

    end # class EMExample < EventedExample

    # Represents spec running inside AMQP.run loop
    class AMQPExample < EventedExample

      # Run @block inside the AMQP.start loop
      def run
        run_em_loop do
          AMQP.start_connection @opts, &@block
        end
      end

      # Breaks the event loop and finishes the spec. It yields to any given block first,
      # then stops AMQP, EM event loop and cleans up AMQP state.
      #
      def done(delay=nil)
        super(delay) do
          yield if block_given?
          EM.next_tick do
            if AMQP.conn and not AMQP.closing
              AMQP.stop_connection do
                finish_em_loop
              end
            else
              finish_em_loop
            end
          end
        end
      end

      # Called from run_event_loop when event loop is finished, before any exceptions
      # is raised or example returns. We ensure AMQP state cleanup here
      def finish_example
        AMQP.cleanup_state
        super
      end

    end # class AMQPExample < EventedExample
  end # module SpecHelper
end # module AMQP
