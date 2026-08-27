# frozen_string_literal: true

require_relative "lib/riffer/version"

Gem::Specification.new do |spec|
  spec.name = "riffer"
  spec.version = Riffer::VERSION
  spec.authors = ["Jake Bottrall"]
  spec.email = ["jakebottrall@gmail.com"]

  spec.summary = "The all-in-one Ruby framework for building AI-powered applications and agents."
  spec.description = "Riffer is a comprehensive Ruby framework designed to simplify the development of " \
                     "AI-powered applications and agents. It provides a complete toolkit for integrating " \
                     "artificial intelligence capabilities into your Ruby projects."
  spec.homepage = "https://riffer.ai"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/janeapp/riffer"
  spec.metadata["changelog_uri"] = "https://github.com/janeapp/riffer/blob/main/CHANGELOG.md"

  # Extra files to include in generated documentation
  spec.extra_rdoc_files = ["README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.rdoc_options = ["--main", "README.md", "--title", "Riffer Documentation", "--markup", "markdown"]

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ examples/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "zeitwerk", "~> 2.6", ">= 2.6.0"
  # Ruby 3.4 moved base64 from a default gem to a bundled one, so it's no
  # longer guaranteed to be on a consumer's load path without this.
  spec.add_dependency "base64"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
