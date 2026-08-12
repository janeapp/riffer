# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "rubocop/rake_task"

RuboCop::RakeTask.new

require "rdoc/task"

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "_site/api"
  rdoc.title = "Riffer API Reference"
  rdoc.main = "README.md"
  rdoc.rdoc_files.include("README.md", "CHANGELOG.md", "LICENSE.txt")
  rdoc.rdoc_files.include("lib/**/*.rb")
  rdoc.options << "--charset" << "utf-8"
end

namespace :docs do
  desc "Build the docs site (landing, guides, 404, assets) into _site/"
  task :site do
    ruby "docs-site/build.rb"
  end

  desc "Build the docs site and validate all internal links and anchors"
  task check: :site do
    ruby "docs-site/check.rb"
  end

  desc "Build the docs site and serve it at http://localhost:8000"
  task serve: :site do
    ruby "-run -e httpd _site -p 8000"
  end
end

desc "Build the full deployable docs tree (site + API reference) into _site/"
task docs: %w[docs:site rdoc]

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

task default: %i[test rubocop steep:check]
