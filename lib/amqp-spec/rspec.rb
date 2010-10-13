require 'mq'
require File.dirname(__FILE__) + '/../ext/fiber18'

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
module AMQP
  module SpecHelper

    SpecTimeoutExceededError = Class.new(RuntimeError)

    def self.included(cls)
      ::Spec::Example::ExampleGroup.instance_eval "
      @@_em_default_spec_timeout = nil
      def self.default_spec_timeout(time_to_run)
        @@_em_default_spec_timeout = time_to_run
      end
      alias default_timeout default_spec_timeout
      "
    end

    def timeout(time_to_run)
      EM.cancel_timer(@_em_timer) if @_em_timer
      @_em_timer = EM.add_timer(time_to_run) { done; raise SpecTimeoutExceededError.new }
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

    def amqp opts={}, &blk
      EM.run do
        begin
          spec_timeout = opts.delete(:spec_timeout) || @@_em_default_spec_timeout
          timeout(spec_timeout) if spec_timeout
          AMQP.instance_eval do
            puts "Existing connection: #{@conn}"
            @conn = connect opts
#            @conn ||= connect opts
            @conn.callback(&blk) if blk
            @conn
          end
#          p "Timer:#{@_em_timer.inspect}"
        rescue Exception => em_spec_exception
          p em_spec_exception
          done
          raise em_spec_exception
        end
      end
    end

    def em(time_to_run = @@_em_default_spec_timeout, &block)
      EM.run do
        timeout(time_to_run) if time_to_run
        em_spec_exception = nil
        @_em_spec_fiber = Fiber.new do
          begin
            block.call
          rescue Exception => em_spec_exception
            done
          end
          Fiber.yield
        end

        @_em_spec_fiber.resume

        raise em_spec_exception if em_spec_exception
      end
    end

    def done
      EM.next_tick{
        finish_em_spec_fiber
      }
    end

    private

    def finish_em_spec_fiber
      EM.stop_event_loop if EM.reactor_running?
      @_em_spec_fiber.resume if @_em_spec_fiber.alive?
    end

  end

  module Spec

    include SpecHelper

    def instance_eval(&block)
      em do
        super(&block)
      end
    end

  end

end


