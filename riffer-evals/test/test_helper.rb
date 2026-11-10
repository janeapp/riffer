# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "minitest/spec"

require "riffer-evals"
require "riffer/testing/minitest"

Riffer.config.deprecations = :raise

# Each agent builds its own provider instance, so a judge's provider is only
# reachable through a registered class that always hands back the same one.
def register_judge_provider(name)
  provider = Riffer::Providers::Mock.new
  provider_class = Class.new(Riffer::Providers::Mock) { define_singleton_method(:new) { provider } }
  Riffer::Providers::Repository.register(name) { provider_class }
  provider
end
