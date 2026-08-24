# frozen_string_literal: true

require "json"
require "digest"
require "active_support"
require "active_support/security_utils"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "estate/jobs"
require "estate/jobs/client"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
end
