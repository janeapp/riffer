# frozen_string_literal: true
# rbs_inline: enabled

require "date"
require "ipaddr"

module Riffer::Params::Format
  extend self

  DATE = /\A(\d{4})-(\d{2})-(\d{2})\z/ #: Regexp

  DATE_TIME = /\A(\d{4})-(\d{2})-(\d{2})[Tt]([01]\d|2[0-3]):[0-5]\d:([0-5]\d|60)(\.\d+)?([Zz]|[+-]([01]\d|2[0-3]):[0-5]\d)\z/ #: Regexp

  # The offset is optional: Anthropic's grammar emits times without one.
  TIME = /\A([01]\d|2[0-3]):[0-5]\d:([0-5]\d|60)(\.\d+)?([Zz]|[+-]([01]\d|2[0-3]):[0-5]\d)?\z/ #: Regexp

  DURATION = /\AP(?!\z)((\d+Y)?(\d+M)?(\d+D)?(T(?=\d)(\d+H)?(\d+M)?(\d+S)?)?|\d+W)\z/ #: Regexp

  UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/ #: Regexp

  # The WHATWG HTML pattern: no single pattern matches RFC 5322 exactly, so
  # this one only rules out values that are clearly not an address.
  EMAIL = %r{\A[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\z} #: Regexp

  HOSTNAME = /\A(?=.{1,253}\.?\z)[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.?\z/ #: Regexp

  # The formats OpenAI, Anthropic and Bedrock all accept. OpenAI rejects uri.
  CHECKS = {
    "date-time" => ->(value) { calendar_date?(DATE_TIME, value) },
    "time" => ->(value) { TIME.match?(value) },
    "date" => ->(value) { calendar_date?(DATE, value) },
    "duration" => ->(value) { DURATION.match?(value) },
    "email" => ->(value) { EMAIL.match?(value) },
    "hostname" => ->(value) { HOSTNAME.match?(value) },
    "ipv4" => ->(value) { ip_address?(value, &:ipv4?) },
    "ipv6" => ->(value) { ip_address?(value, &:ipv6?) },
    "uuid" => ->(value) { UUID.match?(value) },
  }.freeze #: Hash[String, ^(String) -> bool]

  private_constant :DATE, :DATE_TIME, :TIME, :DURATION, :UUID, :EMAIL, :HOSTNAME, :CHECKS

  NAMES = CHECKS.keys.freeze #: Array[String]

  #--
  #: (String, String) -> bool
  def valid?(format, value)
    CHECKS.fetch(format).call(value)
  end

  private

  #--
  #: (Regexp, String) -> bool
  def calendar_date?(pattern, value)
    match = pattern.match(value)
    return false unless match

    # RFC 3339 dates are proleptic Gregorian; Date defaults to the Julian calendar before 1582.
    Date.valid_date?(match[1].to_i, match[2].to_i, match[3].to_i, Date::GREGORIAN)
  end

  #--
  #: (String) { (IPAddr) -> bool } -> bool
  def ip_address?(value)
    # IPAddr also accepts a prefix (10.0.0.0/24), a zone ID (fe80::1%eth0) and
    # brackets ([::1]), none of which are part of an address.
    return false if value.match?(%r{[/%\[\]]})

    yield IPAddr.new(value)
  rescue IPAddr::Error
    false
  end
end
