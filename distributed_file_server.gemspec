# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'distributed_file_server/version'

Gem::Specification.new do |spec|
  spec.name          = "distributed_file_server"
  spec.version       = DistributedFileServer::VERSION
  spec.authors       = ["Ian Connolly"]
  spec.email         = ["ian@connolly.io"]
  spec.summary       = %q{Distributed File Server for TCD's CS4032}
  spec.description   = %q{Distributed File Server for TCD's CS4032}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_runtime_dependency "threadpool", "~> 0.0.2"
end
