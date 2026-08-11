#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates every internal link and anchor in the built _site/ HTML. Exits
# non-zero with a list of broken links on failure.

SITE = Pathname(__dir__).join("../_site").expand_path

EXTERNAL = %r{\A(?:https?:|mailto:|//)}

def site_pages
  Pathname.glob(SITE.join("**/*.html")).reject do |file|
    file.relative_path_from(SITE).to_s.start_with?("api/")
  end
end

def links(html)
  html.scan(/\b(?:href|src)="([^"]+)"/).flatten
end

def ids(html)
  html.scan(/\bid="([^"]+)"/).flatten
end

def resolve(file, path)
  target = path.start_with?("/") ? SITE.join(path.delete_prefix("/")) : file.dirname.join(path)
  target.directory? ? target.join("index.html") : target
end

def link_error(file, link, id_index)
  path, fragment = link.split("#", 2)
  target = path.empty? ? file : resolve(file, path)
  return "#{file.relative_path_from(SITE)}: broken link #{link}" unless target.file?
  return nil if fragment.nil? || fragment.empty?

  anchor_ids = id_index.fetch(target) { ids(target.read) }
  "#{file.relative_path_from(SITE)}: broken anchor #{link}" unless anchor_ids.include?(fragment)
end

# Links into /api/ are skipped: RDoc builds that tree in a separate task, so
# it is absent when only the site has been built.
def page_errors(file, id_index)
  links(file.read).
    grep_v(EXTERNAL).
    reject { |link| link.start_with?("/api/") }.
    filter_map { |link| link_error(file, link, id_index) }
end

pages = site_pages
abort "docs:check: no built site at _site/ — run `rake docs:site` first" if pages.empty?

id_index = pages.to_h { |file| [file, ids(file.read)] }
errors = pages.flat_map { |file| page_errors(file, id_index) }

if errors.empty?
  puts "docs:check passed: #{pages.size} pages, all internal links and anchors resolve"
else
  errors.each { |error| warn error }
  abort "docs:check failed: #{errors.size} broken link(s)"
end
