require_relative 'amqp'
require_relative 'evented_example'

# You can include one of the following modules into your example groups:
# AMQP::SpecHelper,
# AMQP::Spec,
# AMQP::EMSpec.
#
# AMQP::SpecHelper module defines #ampq and #em methods that can be safely used inside
# your specs (examples) to test code running inside AMQP.start or EM.run loop
# respectively. Each example is running in a separate event loop,you can control
# for timeouts either with :spec_timeout option given to #amqp/#em method or setting
# a default timeout using default_timeout(timeout) macro inside describe/context block.
#
# If you include AMQP::Spec module into your example group, each example of this group
# will run inside AMQP.start loop without the need to explicitly call 'amqp'. In order to
# provide options to AMQP loop, default_options({opts}) macro is defined.
#
# Including AMQP::EMSpec module into your example group, each example of this group will run
# inside EM.run loop without the need to explicitly call 'em'.
#
# In order to stop AMQP/EM loop, you should call 'done' AFTER you are sure that your
# example is finished and your expectations executed. For example if you are using
# subscribe block that tests expectations on messages, 'done' should be probably called
# at the end of this block.
#
module AMQP

  # AMQP::SpecHelper module defines #ampq and #em methods that can be safely used inside
  # your specs (examples) to test code running inside AMQP.start or EM.run loop
  # respectively. Each example is running in a separate event loop,you can control
  # for timeouts either with :spec_timeout option given to #amqp/#em method or setting
  # a default timeout using default_timeout(timeout) macro inside describe/context block.
  #
  # noinspection RubyArgCount
  module SpecHelper

    SpecTimeoutExceededError = Class.new(RuntimeError)

    # Class methods (macros) for any example groups that includes SpecHelper.
    # You can use these methods as macros inside describe/context block.
    #
    module GroupMethods
      unless respond_to? :metadata
        # Hacking in metadata into RSpec1 to imitate Rspec2's metadata. Now you can add
        # anything to metadata Hash to pass options into examples and nested groups.
        #
        def metadata
          @metadata ||= superclass.metadata.dup rescue {}
        end
      end

      # Sets/retrieves default timeout for running evented specs for this
      # example group and its nested groups.
      #
      def default_timeout spec_timeout=nil
        default_options[:spec_timeout] = spec_timeout || default_options[:spec_timeout]
      end

      # Sets/retrieves default AMQP.start options for this example group
      # and its nested groups.
      #
      def default_options opts=nil
        metadata[:em_defaults] ||= {}
        metadata[:em_defaults][self] ||= (superclass.default_options.dup rescue {})
        metadata[:em_defaults][self] = opts || metadata[:em_defaults][self]
      end

      # Add before hook that will run inside EM event loop
      def em_before scope = :each, &block
        raise ArgumentError, "em_before only supports :each scope" unless :each == scope
        em_hooks[:em_before] << block
      end

      # Add after hook that will run inside EM event loop
      def em_after scope = :each, &block
        raise ArgumentError, "em_after only supports :each scope" unless :each == scope
        em_hooks[:em_after].unshift block
      end

      # Add before hook that will run inside EM event loop
      def amqp_before scope = :each, &block
        raise ArgumentError, "amqp_before only supports :each scope" unless :each == scope
        em_hooks[:amqp_before] << block
      end

      # Add after hook that will run inside EM event loop
      def amqp_after scope = :each, &block
        raise ArgumentError, "amqp_after only supports :each scope" unless :each == scope
        em_hooks[:amqp_after].unshift block
      end

      # Collection of evented hooks for THIS example group
      def em_hooks
        metadata[:em_hooks] ||= {}
        metadata[:em_hooks][self] ||=
            {em_before: (superclass.em_hooks[:em_before].clone rescue []),
             em_after: (superclass.em_hooks[:em_after].clone rescue []),
             amqp_before: (superclass.em_hooks[:amqp_before].clone rescue []),
             amqp_after: (superclass.em_hooks[:amqp_after].clone rescue [])}
      end
    end

    def self.included example_group
      unless example_group.respond_to? :default_timeout
        example_group.extend GroupMethods
      end
    end

    # Retrieves metadata passed in from enclosing example groups
    #
    def metadata
      @em_metadata ||= self.class.metadata.dup rescue {}
    end

    # Retrieves default options passed in from enclosing example groups
    #
    def default_options
      @em_default_options ||= self.class.default_options.dup rescue {}
    end

    # Yields to a given block inside EM.run and AMQP.start loops. This method takes
    # any option that is accepted by EventMachine::connect. Options for AMQP.start include:
    # * :user => String (default ‘guest’) - Username as defined by the AMQP server.
    # * :pass => String (default ‘guest’) - Password as defined by the AMQP server.
    # * :vhost => String (default ’/’)    - Virtual host as defined by the AMQP server.
    # * :timeout => Numeric (default nil) - *Connection* timeout, measured in seconds.
    # * :logging => Bool (default false) - Toggle the extremely verbose AMQP logging.
    #
    # In addition to EM and AMQP options, :spec_timeout option (in seconds) is used
    # to force spec to timeout if something goes wrong and EM/AMQP loop hangs for some
    # reason. SpecTimeoutExceededError is raised if it happens.
    #
    def amqp opts={}, &block
      opts = default_options.merge opts
      @evented_example = AMQPExample.new(opts, self, &block)
      @evented_example.run
    end

    # Yields to block inside EM loop, :spec_timeout option (in seconds) is used to
    # force spec to timeout if something goes wrong and EM/AMQP loop hangs for some
    # reason. SpecTimeoutExceededError is raised if it happens.
    #
    # For compatibility with EM-Spec API, em method accepts either options Hash
    # or numeric timeout in seconds.
    #
    def em opts = {}, &block
      opts = default_options.merge(opts.is_a?(Hash) ? opts : {spec_timeout: opts})
      @evented_example = EMExample.new(opts, self, &block)
      @evented_example.run
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
    def done *args, &block
      @evented_example.done *args, &block
    end

    # Manually sets timeout for currently running example
    #
    def timeout *args
      @evented_example.timeout *args
    end

  end # module SpecHelper

  # If you include AMQP::Spec module into your example group, each example of this group
  # will run inside AMQP.start loop without the need to explicitly call 'amqp'. In order
  # to provide options to AMQP loop, default_options class method is defined. Remember,
  # when using AMQP::Specs, you'll have a single set of AMQP.start options for all your
  # examples.
  #
  module Spec
    def self.included(example_group)
      example_group.send(:include, SpecHelper)
    end

    alias instance_eval_without_event_loop instance_eval

    def instance_eval(&block)
      amqp do
        super(&block)
      end
    end
  end

  # Including AMQP::EMSpec module into your example group, each example of this group
  # will run inside EM.run loop without the need to explicitly call 'em'.
  #
  module EMSpec
    def self.included(example_group)
      example_group.send(:include, SpecHelper)
    end

    alias instance_eval_without_event_loop instance_eval

    def instance_eval(&block)
      em do
        super(&block)
      end
    end
  end
end