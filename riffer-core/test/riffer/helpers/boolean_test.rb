# frozen_string_literal: true

require "test_helper"

describe Riffer::Helpers::Boolean do
  describe "#coerce" do
    it "passes a boolean through" do
      expect(Riffer::Helpers::Boolean.coerce(true, attribute: "flag")).must_equal true
    end

    it "coerces truthy strings and integers" do
      coerced = ["true", "1", 1].map { |value| Riffer::Helpers::Boolean.coerce(value, attribute: "flag") }

      expect(coerced).must_equal [true, true, true]
    end

    it "coerces falsy strings, integers, and nil" do
      coerced = ["false", "0", 0, nil].map { |value| Riffer::Helpers::Boolean.coerce(value, attribute: "flag") }

      expect(coerced).must_equal [false, false, false, false]
    end

    it "raises for an unrecognized value" do
      expect { Riffer::Helpers::Boolean.coerce("yes", attribute: "flag") }.must_raise Riffer::ArgumentError
    end

    it "names the attribute in the error message" do
      error = expect { Riffer::Helpers::Boolean.coerce("yes", attribute: "enabled") }.must_raise Riffer::ArgumentError
      expect(error.message).must_match(/^enabled /)
    end
  end
end
