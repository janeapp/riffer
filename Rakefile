# frozen_string_literal: true

require "bundler/gem_helper"
require "minitest/test_task"

Bundler::GemHelper.install_tasks(dir: "riffer-core")

Minitest::TestTask.create do |t|
  t.libs = %w[riffer-core/lib riffer-core/test .]
  t.test_globs = ["riffer-core/test/**/*_test.rb"]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

require "rdoc/task"

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "_site/api"
  rdoc.title = "Riffer API Reference"
  rdoc.main = "README.md"
  rdoc.rdoc_files.include("README.md", "riffer-core/CHANGELOG.md", "LICENSE.txt")
  rdoc.rdoc_files.include("riffer-core/lib/**/*.rb")
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
    sh "bundle exec rbs-inline --output sig/generated lib", chdir: "riffer-core"
  end

  desc "Watch riffer-core/lib/ for changes and regenerate RBS files"
  task :watch do
    require "guard"
    require "guard/commander"

    Guard.start(no_interactions: true)
  end
end

namespace :steep do
  desc "Run Steep type checker"
  task :check do
    sh "bin/typecheck"
  end
end

task default: %i[test rubocop steep:check]
