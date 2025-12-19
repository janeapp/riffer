# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "irb"
gem "rake", "~> 13.0"

group :test do
  gem "rspec", "~> 3.0"
  gem "vcr", "~> 6.0"
  gem "webmock", "~> 3.0"
end

group :development, :quality do
  gem "standard", "~> 1.3", require: false
  gem "rubocop-rspec", "~> 3.8", require: false
  gem "guard-rspec", require: false
end
