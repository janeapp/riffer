# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Evals
  extend self

  # @rbs @config: Riffer::Evals::Config?

  #--
  #: () -> Riffer::Evals::Config
  def config
    @config ||= Config.new
  end

  #--
  #: () ?{ (Riffer::Evals::Config) -> void } -> void
  def configure
    yield config if block_given?
  end
end
