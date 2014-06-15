# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chronic_tree/version'

Gem::Specification.new do |spec|
  spec.name          = "chronic_tree"
  spec.version       = ChronicTree::VERSION
  spec.authors       = ["bigxiang"]
  spec.email         = ["bigxiang@gmail.com"]
  spec.description   = %q{Build a tree model with versions. You can retrieve the tree at any time.}
  spec.summary       = %q{Build a tree model with versions. You can retrieve the tree at any time.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_dependency "activerecord", ">= 4.0.0"
end
