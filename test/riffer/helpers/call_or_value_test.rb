# frozen_string_literal: true

require "test_helper"

describe Riffer::Helpers::CallOrValue do
  describe ".resolve" do
    it "returns a String value unchanged" do
      assert_equal "hello", Riffer::Helpers::CallOrValue.resolve("hello", context: {})
    end

    it "returns an Integer value unchanged" do
      assert_equal 42, Riffer::Helpers::CallOrValue.resolve(42, context: {})
    end

    it "returns an Array value unchanged" do
      array = [1, 2, 3]

      assert_same array, Riffer::Helpers::CallOrValue.resolve(array, context: {})
    end

    it "returns a Hash value unchanged" do
      hash = { a: 1 }

      assert_same hash, Riffer::Helpers::CallOrValue.resolve(hash, context: {})
    end

    it "returns nil when thing is nil and no default is given" do
      assert_nil Riffer::Helpers::CallOrValue.resolve(nil, context: {})
    end

    it "returns the default when thing is nil" do
      assert_equal [], Riffer::Helpers::CallOrValue.resolve(nil, context: {}, default: [])
    end

    it "does not return the default when a proc returns nil" do
      result = Riffer::Helpers::CallOrValue.resolve(-> {}, context: {}, default: :unused)

      assert_nil result
    end

    it "calls an arity-0 lambda with no arguments" do
      result = Riffer::Helpers::CallOrValue.resolve(-> { :no_args }, context: { ignored: true })

      assert_equal :no_args, result
    end

    it "calls an arity-0 proc with no arguments" do
      result = Riffer::Helpers::CallOrValue.resolve(proc { :no_args }, context: { ignored: true })

      assert_equal :no_args, result
    end

    it "calls an arity-1 lambda with the supplied context" do
      ctx = { user_id: 7 }
      result = Riffer::Helpers::CallOrValue.resolve(->(c) { c[:user_id] }, context: ctx)

      assert_equal 7, result
    end

    it "calls an arity-1 proc with the supplied context" do
      ctx = { user_id: 7 }
      result = Riffer::Helpers::CallOrValue.resolve(proc { |c| c[:user_id] }, context: ctx)

      assert_equal 7, result
    end

    it "defaults context to nil and passes nil to arity-1 procs" do
      result = Riffer::Helpers::CallOrValue.resolve(lambda(&:inspect))

      assert_equal "nil", result
    end

    it "treats a variadic proc as non-zero arity and passes context" do
      ctx = { a: 1 }
      result = Riffer::Helpers::CallOrValue.resolve(->(*args) { args }, context: ctx)

      assert_equal [ctx], result
    end
  end
end
