# frozen_string_literal: true

module Riffer
  module DependencyHelper
    class LoadError < ::LoadError; end

    class VersionError < ScriptError; end

    def depends_on(gem_name, req: true)
      gem(gem_name)

      return true unless defined?(Bundler)

      gem_version = Gem.loaded_specs[gem_name].version
      gem_requirement = Bundler.load.dependencies.find { |g| g.name == gem_name }&.requirement

      raise LoadError unless gem_requirement

      unless gem_requirement.satisfied_by?(gem_version)
        raise VersionError, "The #{gem_name} gem is installed, but version #{gem_requirement} is required. You have #{gem_version}."
      end

      lib_name = gem_name if req == true
      lib_name = req if req.is_a?(String)

      require(lib_name) if lib_name

      true
    rescue ::LoadError
      raise LoadError, "Could not load #{gem_name}. Please ensure that the #{gem_name} gem is installed."
    end
  end
end
