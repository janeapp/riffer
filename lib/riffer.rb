# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "open_ai" => "OpenAI"
)
loader.setup

module Riffer
  class Error < StandardError; end

  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield config if block_given?
    end
  end

  Agent = Agents::Base
  Tool = Tools::Base
  Provider = Providers::Base
end
