# frozen_string_literal: true

require "test_helper"

describe Riffer::Tools::Toolable do
  it "reports a deprecation when extended" do
    error = expect { Class.new { extend Riffer::Tools::Toolable } }.must_raise Riffer::DeprecationError

    expect(error.message).must_include "Riffer::Tools::Toolable is deprecated; subclass Riffer::Tool instead."
  end
end
