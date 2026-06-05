# frozen_string_literal: true
# rbs_inline: enabled

# Lazy-loads gem dependencies — used by providers to load required gems only
# when needed.
module Riffer::Helpers::Dependencies
  extend self

  # Raised when a required gem cannot be loaded.
  class LoadError < ::LoadError; end

  # Requires a gem by name; raises LoadError if it isn't installed.
  #--
  #: (String) -> true
  def depends_on(gem_name)
    require gem_name
    true
  rescue ::LoadError
    raise LoadError, "Could not load #{gem_name}. Please ensure that the #{gem_name} gem is installed."
  end
end
