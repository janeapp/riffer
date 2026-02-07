# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "standard/rake"
require "rdoc/task"

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "doc"
  rdoc.title = "Riffer Documentation"
  rdoc.main = "README.md"

  # Explicitly include top-level docs and the library
  rdoc.rdoc_files.include("README.md", "CHANGELOG.md", "LICENSE.txt", "docs/**/*.md", "docs_providers/**/*.md")
  rdoc.rdoc_files.include("lib/**/*.rb")

  # Use Markdown where available and ensure UTF-8
  rdoc.options << "--charset" << "utf-8" << "--markup" << "markdown"
end

task docs: :rdoc

namespace :rbs do
  desc "Generate RBS type signatures from inline annotations"
  task :generate do
    sh "bundle exec rbs-inline --output sig/generated lib"
  end

  desc "Watch lib/ for changes and regenerate RBS files"
  task :watch do
    require "guard"
    require "guard/commander"

    Guard.start(no_interactions: true)
  end
end

namespace :steep do
  desc "Run Steep type checker"
  task :check do
    sh "bundle exec steep check"
  end
end

task default: %i[test standard steep:check]
