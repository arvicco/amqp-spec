source :gemcutter

gem 'amqp'

group :test do
  # Should work for either one, but you cannot have both at once.
  # Also, keep in mind that if you install Rspec 2 it prevents Rspec 1 from running normally
#  gem 'rspec', '~>2.0.0'
  gem 'rspec', '~>1.3.0', require: 'spec'
  gem 'win32console' if RUBY_PLATFORM =~ /mswin|windows|mingw/
end
