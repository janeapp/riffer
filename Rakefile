# frozen_string_literal: true

require "bundler/gem_helper"
require "minitest/test_task"

GEM_DIRS = Dir["*/*.gemspec"].map { |gemspec| File.dirname(gemspec) }.freeze

# Bundler's gem tasks share fixed names (build, install, release), so each
# gem's set lives in a namespace named after its directory.
GEM_DIRS.each do |dir|
  namespace(dir) { Bundler::GemHelper.install_tasks(dir:) }
end

desc "Build every gem into its pkg/ directory"
task build: GEM_DIRS.map { |dir| "#{dir}:build" }

# One test process per gem: each gem's tests `require "test_helper"`, and a
# load path holding every gem's test/ would resolve them all to the first.
GEM_DIRS.each do |dir|
  Minitest::TestTask.create(:"test:#{dir}") do |t|
    t.libs = ["#{dir}/lib", "#{dir}/test", "."]
    t.test_globs = ["#{dir}/test/**/*_test.rb"]
  end
end

desc "Run every gem's tests"
task test: GEM_DIRS.map { |dir| "test:#{dir}" }

require "rubocop/rake_task"

RuboCop::RakeTask.new

require "rdoc/task"

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "_site/api"
  rdoc.title = "Riffer API Reference"
  rdoc.main = "README.md"
  rdoc.rdoc_files.include("README.md", "riffer-core/CHANGELOG.md", "LICENSE.txt")
  rdoc.rdoc_files.include(*GEM_DIRS.map { |dir| "#{dir}/lib/**/*.rb" })
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
    GEM_DIRS.each { |dir| sh "bundle exec rbs-inline --output sig/generated lib", chdir: dir }
  end

  desc "Watch each gem's lib/ for changes and regenerate RBS files"
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
