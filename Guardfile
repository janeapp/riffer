# frozen_string_literal: true

guard :shell do
  watch(%r{^lib/.*\.rb$}) do
    system("bundle exec rake rbs:generate")
  end
end
