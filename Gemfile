source :gemcutter

group :test do
  # Should work for either RSpec1 or Rspec2, but you cannot have both at once.
  # Also, keep in mind that if you install Rspec 2 it prevents Rspec 1 from running normally.
  # Unless you use it like 'bundle exec spec spec', that is.

  if RUBY_PLATFORM =~ /mswin|windows|mingw/
    # For color support on Windows (deprecated?)
    gem 'win32console'
    gem 'rspec', '~>1.3.0', require: 'spec'
  else
    gem 'rspec', '>=2.0.0'
  end

  gem 'amqp', '~>0.6.7'
end