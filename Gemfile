source :gemcutter

if `hostname`.strip.split(/-/).first.upcase == 'VB'
  # I have my own experimental fork of tmm1/amqp with advanced features
  gem 'arvicco-amqp', '~>0.6.8'
else
  # But you're probably better off using plain vanilla gem
  gem 'amqp', '~>0.6.6'
end

group :test do
  # Should work for either RSpec1 or Rspec2, but you cannot have both at once.
  # Also, keep in mind that if you install Rspec 2 it prevents Rspec 1 from running normally.
  # Unless you use it like 'bundle exec spec spec', that is.
#  gem 'rspec', '~>2.0.0'
  gem 'rspec', '~>1.3.0', require: 'spec'

  # Finally, for color support on Windows
  gem 'win32console' if RUBY_PLATFORM =~ /mswin|windows|mingw/
end
