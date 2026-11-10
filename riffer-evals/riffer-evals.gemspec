# frozen_string_literal: true

# Read rather than required: a path- or git-sourced bundle evaluates this file
# before riffer loads, and a Riffer::Evals defined that early makes Zeitwerk
# skip lib/riffer/evals.rb and trips the guard in lib/riffer-evals.rb.
version_file = File.read(File.expand_path("lib/riffer/evals/version.rb", __dir__))

Gem::Specification.new do |spec|
  spec.name = "riffer-evals"
  spec.version = version_file[/VERSION = "([^"]+)"/, 1]
  spec.authors = ["Jake Bottrall"]
  spec.email = ["jakebottrall@gmail.com"]

  spec.summary = "LLM-as-judge evals for Riffer agents."
  spec.description = "Measure the quality of Riffer agent outputs with evaluators, scenarios, and an " \
                     "LLM-as-judge runner."
  spec.homepage = "https://riffer.ai"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/janeapp/riffer/tree/main/riffer-evals"
  spec.metadata["changelog_uri"] = "https://github.com/janeapp/riffer/blob/main/riffer-evals/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?(*%w[bin/ test/ .bundle Gemfile Rakefile])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "riffer", ">= 0.56.0", "< 1.0"
  spec.add_dependency "zeitwerk", "~> 2.6", ">= 2.6.0"
end
