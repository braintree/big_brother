# -*- encoding: utf-8 -*-
require File.expand_path('../lib/big_brother/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["TODO: Write your name"]
  gem.email         = ["code@getbraintree.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "big_brother"
  gem.require_paths = ["lib"]
  gem.version       = BigBrother::VERSION

  gem.add_dependency "sinatra-synchrony", "~> 0.3.0"
  gem.add_dependency "thin", "~> 1.3.1"

  gem.add_development_dependency "rspec", "2.9.0"
  gem.add_development_dependency "rack-test", "0.6.1"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "rake_commit", "0.13"
end
