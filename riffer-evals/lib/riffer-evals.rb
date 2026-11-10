# frozen_string_literal: true
# rbs_inline: enabled

require "riffer"
require "zeitwerk"

# True for riffer's still-pending autoload as well as a loaded copy.
if Riffer.const_defined?(:Evals, false)
  raise LoadError,
        "riffer loaded its own deprecated Riffer::Evals before riffer-evals. Upgrade riffer to a release that " \
        "skips it when riffer-evals is installed, and without Bundler require riffer-evals before riffer."
end

loader = Zeitwerk::Loader.new
loader.tag = "riffer-evals"
loader.inflector.inflect("version" => "VERSION")
loader.push_dir("#{__dir__}/riffer", namespace: Riffer)
loader.setup
