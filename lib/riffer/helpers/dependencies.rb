# frozen_string_literal: true
# rbs_inline: enabled

# Helper module for lazy loading gem dependencies.
#
# Used by providers to load their required gems only when needed.
module Riffer::Helpers::Dependencies
  # Raised when a required gem cannot be loaded.
  class LoadError < ::LoadError; end

  # Requires a gem by name, raising a helpful error if it is not installed.
  #
  # Raises LoadError if the gem cannot be required.
  #
  #--
  #: (String) -> true
  def depends_on(gem_name)
    require gem_name
    true
  rescue ::LoadError
    raise LoadError, "Could not load #{gem_name}. Please ensure that the #{gem_name} gem is installed."
  end
end
