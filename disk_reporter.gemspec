# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'disk_reporter/version'

Gem::Specification.new do |spec|
  spec.name          = "disk_reporter"
  spec.version       = DiskReporter::VERSION
  spec.authors       = ["Stuart Harland"]
  spec.email         = ["s.harland@livelinktechnology.net", "essjayhch@gmail.com"]
  spec.description   = %q{Uses sas2ircu and blkid to determine the status of various disks attached to our JBODS}
  spec.summary       = spec.description
  spec.homepage      = ""
  spec.license       = "MIT"
  spec.bindir        = 'bin'
  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "colorize"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
