# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Helpers::Dependencies
  extend self

  class LoadError < ::LoadError; end

  #--
  #: (String) -> true
  def depends_on(gem_name)
    require gem_name
    true
  rescue ::LoadError
    raise LoadError, "Could not load #{gem_name}. Please ensure that the #{gem_name} gem is installed."
  end
end
