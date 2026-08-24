# frozen_string_literal: true

require_relative "lib/estate/jobs/version"

Gem::Specification.new do |spec|
  spec.name          = "estate-jobs"
  spec.version       = Estate::Jobs::VERSION
  spec.authors       = ["Devoun Edwards"]
  spec.summary       = "One JSON reporter per Rails app: Solid Queue state for the estate panel."
  spec.description   = "Mount a token-gated /internal/jobs endpoint that reports this app's " \
                       "Solid Queue processes, queue depths, recurring tasks and recent failures. " \
                       "Includes a client for aggregators."
  spec.homepage      = "https://github.com/mukco/estate-jobs"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*.rb", "app/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 7.1"
  spec.add_dependency "activesupport", ">= 7.1"

  spec.metadata["rubygems_mfa_required"] = "true"
end
