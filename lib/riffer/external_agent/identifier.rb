# frozen_string_literal: true
# rbs_inline: enabled

# Frozen value object describing the agent an external implementation runs as.
#
# Carries the parsed pieces of an identifier string returned by
# Riffer::ExternalAgent.parse_identifier:
#
# - +vendor+ — the vendor namespace (e.g. "claude-code").
# - +raw+ — the identifier as supplied by the caller (e.g. "latest" or "2.1.0").
# - +resolved+ — the same value after any vendor-specific alias resolution.
#   For vendors that do not alias, +resolved+ equals +raw+.
#
# Instances are deep-frozen on construction.
class Riffer::ExternalAgent::Identifier
  # The vendor namespace (e.g. "claude-code").
  attr_reader :vendor #: String

  # The identifier as supplied by the caller, before alias resolution.
  attr_reader :raw #: String

  # The identifier after any vendor-specific alias resolution.
  attr_reader :resolved #: String

  # [vendor] the vendor namespace.
  # [raw] the identifier as supplied.
  # [resolved] the identifier after any vendor-specific alias resolution.
  #
  #--
  #: (vendor: String, raw: String, resolved: String) -> void
  def initialize(vendor:, raw:, resolved:)
    @vendor = vendor.frozen? ? vendor : vendor.dup.freeze
    @raw = raw.frozen? ? raw : raw.dup.freeze
    @resolved = resolved.frozen? ? resolved : resolved.dup.freeze
    freeze
  end
end
