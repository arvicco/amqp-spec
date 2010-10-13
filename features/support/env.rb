$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../../lib')
require 'amqp-spec'
require 'spec/expectations'
require 'spec/stubs/cucumber'

require 'pathname'
BASE_PATH = Pathname.new(__FILE__).dirname + '../..'
