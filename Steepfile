# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature "sig/generated"
  signature "sig/manual"
  signature "sig/_private"

  check "lib"

  # Steep 2.1 only registers `def` nodes as implementations, so it reports every
  # RBS `attr_reader`/`attr_accessor` member as unimplemented. The only in-source
  # escape is a `# @dynamic` comment beside each attribute, so the whole
  # diagnostic stays a hint (its level under the `strict` preset).
  configure_code_diagnostics(D::Ruby.all_error) do |hash|
    hash[D::Ruby::MethodDefinitionMissing] = :hint
  end
end
