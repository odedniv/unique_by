# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'unique_by/version'

Gem::Specification.new do |spec|
  spec.name          = "unique_by"
  spec.version       = UniqueBy::VERSION
  spec.authors       = ["Oded Niv"]
  spec.email         = ["oded.niv@gmail.com"]
  spec.summary       = %q{Specify uniqueness group for an attribute.}
  spec.description   = %q{Allows uniqueness of a record when sharding (specifying the shard ID as the group) or span accross tables (receipts).}
  spec.homepage      = ""
  spec.license       = "UNLICENSE"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.1.0"
end
