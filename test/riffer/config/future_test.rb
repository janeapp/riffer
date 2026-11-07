# frozen_string_literal: true

require "test_helper"

describe Riffer::Config::Future do
  let(:future) do
    Riffer::Config::Future.new(flags: { early_access: { default: false }, graduated: { default: true } })
  end

  it "ships a frozen registry where every flag declares a boolean default" do
    expect(Riffer::Config::Future::FLAGS).must_be :frozen?
    defaults = Riffer::Config::Future::FLAGS.values.map { |flag| flag[:default] }

    expect(defaults - [true, false]).must_be_empty
  end

  describe "#enabled?" do
    it "is false until a flag is turned on" do
      expect(future.enabled?(:early_access)).must_equal false
    end

    it "is always true for a graduated flag" do
      expect(future.enabled?(:graduated)).must_equal true
    end

    it "raises for an unknown flag" do
      error = expect { future.enabled?(:nope) }.must_raise Riffer::ArgumentError

      expect(error.message).must_include ":nope"
    end
  end

  describe "setting a flag" do
    it "turns a flag on and off" do
      future.early_access = true

      expect(future.enabled?(:early_access)).must_equal true

      future.early_access = false

      expect(future.enabled?(:early_access)).must_equal false
    end

    it "responds to the setter of a known flag only" do
      expect(future.respond_to?(:early_access=)).must_equal true
      expect(future.respond_to?(:nope=)).must_equal false
    end

    it "has no setter for an unknown flag" do
      expect { future.nope = true }.must_raise NoMethodError
    end

    it "raises for a non-boolean value" do
      expect { future.early_access = "yes" }.must_raise Riffer::ArgumentError
      expect { future.early_access = 2 }.must_raise Riffer::ArgumentError
    end

    it "reports a deprecation for a graduated flag" do
      error = expect { future.graduated = true }.must_raise Riffer::DeprecationError

      expect(error.message).must_include "config.future.graduated is now the default"
    end

    it "keeps a graduated flag enabled when set to false" do
      allow_deprecations { future.graduated = false }

      expect(future.enabled?(:graduated)).must_equal true
    end
  end
end
