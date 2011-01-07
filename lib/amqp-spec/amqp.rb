# Monkey patching some methods into AMQP to make it more testable
module AMQP

  # Initializes new AMQP client/connection without starting another EM loop
  def self.start_connection(opts={}, &block)
#    puts "!!!!!!!!! Existing connection: #{@conn}" if @conn
    @conn = connect opts
    @conn.callback(&block) if block
  end

  # Closes AMQP connection gracefully
  def self.stop_connection
    if AMQP.conn and not AMQP.closing
#   MQ.reset ?
      @closing = true
      @conn.close {
        yield if block_given?
        cleanup_state
      }
    end
  end

  # Cleans up AMQP state after AMQP connection closes
  def self.cleanup_state
#   MQ.reset ?
    Thread.list.each { |thread| thread[:mq] = nil }
    Thread.list.each { |thread| thread[:mq_id] = nil }
    @conn    = nil
    @closing = false
  end
end