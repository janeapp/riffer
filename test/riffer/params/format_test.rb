# frozen_string_literal: true

require "test_helper"

describe Riffer::Params::Format do
  {
    "date-time" => {
      valid: %w[2026-10-19T15:30:00Z 2026-10-19T15:30:00.000000000+00:00 2026-10-19t15:30:00z 2016-12-31T23:59:60Z],
      invalid: [
        "2026-10-19T15:30:00", "2026-02-30T10:00:00Z", "2026-10-19 15:30:00Z", "2026-10-19T24:00:00Z",
        "2026-10-19T15:30:00Z\n",
      ],
    },
    "time" => {
      valid: ["09:00:00", "09:00:00Z", "20:26:10.000Z", "09:00:00-05:00"],
      invalid: ["09:00", "9:00:00", "25:00:00", "09:00:00 PM"],
    },
    "date" => {
      valid: %w[2026-10-19 2024-02-29 1582-10-10],
      invalid: %W[20261019 2026-02-30 2025-02-29 1500-02-29 2026-W42 2026-10-19\n],
    },
    "duration" => {
      valid: %w[PT1H30M P0DT1H30M P1Y2M3D P2W],
      invalid: ["P", "PT", "P1H", "PT1.5H", "P1Y2W"],
    },
    "email" => {
      valid: ["ada@example.com", "Ada+tag@Example.co.uk", "ada@localhost"],
      invalid: ["N/A - patient has none", "ada@", "@example.com", "ada@-example.com", "\u017F@example.com"],
    },
    "hostname" => {
      valid: ["example.com", "localhost", "example.com."],
      invalid: ["my server!!", "-example.com", "a..com", "#{'a' * 64}.com", "\u212A.com"],
    },
    "ipv4" => {
      valid: ["10.0.0.1", "255.255.255.255"],
      invalid: ["256.0.0.1", "01.2.3.4", "1.2.3", "10.0.0.0/24", "10.0.0.1\n", "::ffff:10.0.0.1"],
    },
    "ipv6" => {
      valid: %w[:: ::1 2001:db8::8a2e:370:7334 1:2:3:4:5:6:7:: ::ffff:10.0.0.1 1:2:3:4:5:6:10.0.0.1],
      invalid: [
        "fe80::1%eth0", "::1/64", "[::1]", "2001:db8::g", "::ffff:999.0.0.1", "::ffff:01.2.3.4", "::1\n",
        "1:2:3:4:5:6:7:8::", "::1:2:3:4:5:6:7:8", "1:2:3:4::5:6:7:8", "1.2.3.4",
      ],
    },
    "uuid" => {
      valid: %w[550e8400-e29b-41d4-a716-446655440000 550E8400-E29B-41D4-A716-446655440000],
      invalid: %w[550e8400e29b41d4a716446655440000 550e8400-e29b-41d4-a716],
    },
  }.each do |format, values|
    describe format do
      values[:valid].each do |value|
        it "accepts #{value.inspect}" do
          expect(Riffer::Params::Format.valid?(format, value)).must_equal true
        end
      end

      values[:invalid].each do |value|
        it "rejects #{value.inspect}" do
          expect(Riffer::Params::Format.valid?(format, value)).must_equal false
        end
      end
    end
  end

  it "lists the formats every provider accepts" do
    expect(Riffer::Params::Format::NAMES).must_equal %w[date-time time date duration email hostname ipv4 ipv6 uuid]
  end
end
