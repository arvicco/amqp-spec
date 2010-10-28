# encoding: utf-8

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |gem|
  gem.name        = "amqp-spec"
  gem.version     = File.open('VERSION').read.strip #::AMQP::Spec::VERSION conflicts with Bundler
  gem.summary     = %q{Simple API for writing asynchronous EventMachine/AMQP specs. Supports RSpec and RSpec2.}
  gem.description = %q{Simple API for writing asynchronous EventMachine/AMQP specs. Supports RSpec and RSpec2.}
  gem.authors     = ["Arvicco"]
  gem.email       = "arvitallian@gmail.com"
  gem.homepage    = %q{http://github.com/arvicco/amqp-spec}
  gem.platform    = Gem::Platform::RUBY
  gem.date        = Time.now.strftime "%Y-%m-%d"

  # Files setup
  versioned         = `git ls-files -z`.split("\0")
  gem.files         = Dir['{bin,lib,man,spec,features,tasks}/**/*', 'Rakefile', 'README*', 'LICENSE*',
                      'VERSION*', 'CHANGELOG*', 'HISTORY*', 'ROADMAP*', '.gitignore'] & versioned
  gem.test_files    = Dir['spec/**/*'] & versioned
  gem.require_paths = ["lib"]

  # RDoc setup
  gem.has_rdoc = true
  gem.rdoc_options.concat %W{--charset UTF-8 --main README.rdoc --title amqp-spec}
  gem.extra_rdoc_files = ["LICENSE", "HISTORY", "README.rdoc"]
    
  # Dependencies
  gem.add_development_dependency(%q{rspec}, [">= 1.2.9"])
  gem.add_dependency(%q{amqp}, ["~> 0.6.7"])
end
