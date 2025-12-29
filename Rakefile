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
  rdoc.rdoc_files.include("README.md", "CHANGELOG.md", "LICENSE.txt")
  rdoc.rdoc_files.include("lib/**/*.rb")

  # Use Markdown where available and ensure UTF-8
  rdoc.options << "--charset" << "utf-8" << "--markup" << "markdown"
end

task docs: :rdoc

task default: %i[test standard]
