# frozen_string_literal: true

require "spec_helper"

RSpec.describe "VCR configuration" do
  it "has VCR available" do
    expect(defined?(VCR)).to be_truthy
  end

  it "has WebMock available" do
    expect(defined?(WebMock)).to be_truthy
  end

  it "has the cassette library directory configured" do
    expect(VCR.configuration.cassette_library_dir).to end_with("spec/fixtures/vcr_cassettes")
  end
end
