# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'proxy_checker/version'

Gem::Specification.new do |spec|
  spec.name          = "proxy_checker"
  spec.version       = ProxyChecker::VERSION
  spec.authors       = ["Nikhil Gupta"]
  spec.email         = ["me@nikhgupta.com"]

  spec.summary       = %q{Gem to check proxy addresses for speed, ping, and efficacy.}
  spec.description   = %q{Gem to check proxy addresses for speed, ping, and efficacy.}
  spec.homepage      = "https://github.com/nikhgupta/proxy_checker"


  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "simplecov"

  spec.add_dependency "http"
end
