#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds the docs site — landing page, guide pages, 404, and assets — into
# _site/ at the repo root. Pages are declared in manifest.yml; the build fails
# if the manifest and docs/**/*.md ever disagree.

require "erb"
require "fileutils"
require "yaml"

require "kramdown"
require "kramdown-parser-gfm"
require "rouge"

require_relative "../lib/riffer/version"

HERE = Pathname(__dir__)
ROOT = HERE.parent
DOCS = ROOT.join("docs")
SITE = ROOT.join("_site")

ASSETS = %w[site.css landing.css copy.js 404.html].freeze

VERSION = Riffer::VERSION

Page = Data.define(:source, :slug, :title, :num, :description, :featured, :group_label) do
  def url = "/guides/#{slug}/"
end

Group = Data.define(:label, :tone, :pages)

def main
  manifest = YAML.safe_load_file(HERE.join("manifest.yml"), symbolize_names: true).fetch(:groups)
  validate_manifest!(manifest)

  groups = build_groups(manifest)
  pages = groups.flat_map(&:pages)
  pages_by_source = pages.to_h { |page| [page.source, page] }

  layout = ERB.new(HERE.join("layout.html.erb").read, trim_mode: "-")
  landing = ERB.new(HERE.join("index.html.erb").read, trim_mode: "-")

  FileUtils.rm_rf(SITE.join("guides"))
  FileUtils.mkdir_p(SITE)
  ASSETS.each { |asset| FileUtils.cp(HERE.join(asset), SITE) }

  SITE.join("index.html").write(landing.result_with_hash(groups: groups, pages: pages, version: VERSION))

  pages.each_with_index do |page, index|
    body = render_body(page, pages_by_source)
    html = layout.result_with_hash(
      page: page,
      groups: groups,
      pages: pages,
      body: body,
      toc: extract_toc(body),
      prev_page: index.positive? ? pages[index - 1] : nil,
      next_page: pages[index + 1],
      version: VERSION,
    )
    dir = SITE.join("guides", page.slug)
    FileUtils.mkdir_p(dir)
    dir.join("index.html").write(html)
  end

  puts "Built landing + #{pages.size} guide pages + 404 into #{SITE.relative_path_from(ROOT)}/"
end

def validate_manifest!(manifest)
  sources = manifest.flat_map { |group| group[:pages] }.map { |entry| entry[:source] }
  missing = sources.reject { |source| DOCS.join(source).file? }
  on_disk = Pathname.glob(DOCS.join("**/*.md")).map { |path| path.relative_path_from(DOCS).to_s }
  unlisted = on_disk - sources

  errors = missing.map { |source| "manifest entry has no source file: docs/#{source}" } +
           unlisted.map { |source| "docs/#{source} is missing from docs-site/manifest.yml" }
  abort errors.join("\n") unless errors.empty?
end

def build_groups(manifest)
  numbers = chapter_numbers(manifest)
  manifest.map do |group|
    Group.new(
      label: group[:label],
      tone: group[:tone],
      pages: group[:pages].map { |entry| build_page(entry, group[:label], numbers.fetch(entry[:source])) },
    )
  end
end

# Numbering restarts per docs/ subdirectory, so the providers pages read as
# their own sequence rather than continuing the main chapters.
def chapter_numbers(manifest)
  manifest.
    flat_map { |group| group[:pages] }.
    map { |entry| entry[:source] }.
    group_by { |source| File.dirname(source) }.
    values.
    flat_map { |sources| sources.each_with_index.map { |source, index| [source, format("%02d", index + 1)] } }.
    to_h
end

def build_page(entry, label, num)
  source = DOCS.join(entry[:source]).read
  Page.new(
    source: entry[:source],
    slug: entry[:slug],
    title: source[/^# (.+)$/, 1],
    num: num,
    description: entry[:description],
    featured: entry.fetch(:featured, false),
    group_label: label,
  )
end

def render_body(page, pages_by_source)
  markdown = DOCS.join(page.source).read.sub(/^# .+\n/, "")
  html = Kramdown::Document.new(
    markdown,
    input: "GFM",
    syntax_highlighter: :rouge,
    hard_wrap: false,
  ).to_html
  rewrite_links(html, page.source, pages_by_source)
end

def rewrite_links(html, source, pages_by_source)
  source_dir = Pathname(source).dirname
  html.gsub(/href="(?<path>[^":]+\.md)(?<fragment>#[^"]*)?"/) do
    match = Regexp.last_match
    target = source_dir.join(match[:path]).cleanpath.to_s
    page = pages_by_source.fetch(target) { abort "docs/#{source} links to unknown page: #{match[:path]}" }
    %(href="#{page.url}#{match[:fragment]}")
  end
end

def extract_toc(body)
  body.scan(%r{<h2 id="([^"]+)"[^>]*>(.*?)</h2>}m).map do |id, text|
    { id: id, title: text.gsub(/<[^>]+>/, "") }
  end
end

main
