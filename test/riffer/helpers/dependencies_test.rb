# frozen_string_literal: true

require "test_helper"

describe Riffer::Helpers::Dependencies do
  let(:subject_class) do
    Class.new { include Riffer::Helpers::Dependencies }
  end

  let(:instance) { subject_class.new }

  describe "#depends_on" do
    describe "when the gem is not installed" do
      it "raises LoadError" do
        assert_raises(Riffer::Helpers::Dependencies::LoadError) do
          instance.depends_on("nonexistent_gem_xyz_12345")
        end
      end

      it "includes gem name in error message" do
        error = assert_raises(Riffer::Helpers::Dependencies::LoadError) do
          instance.depends_on("nonexistent_gem_xyz_12345")
        end

        assert_includes(error.message, "Could not load nonexistent_gem_xyz_12345")
      end

      it "includes installation guidance in error message" do
        error = assert_raises(Riffer::Helpers::Dependencies::LoadError) do
          instance.depends_on("nonexistent_gem_xyz_12345")
        end

        assert_includes(error.message, "ensure that the nonexistent_gem_xyz_12345 gem is installed")
      end
    end

    describe "when Bundler is not defined" do
      before do
        instance.define_singleton_method(:gem) { |_name| true }
        instance.define_singleton_method(:defined?) { |_const| false }
      end

      it "returns true when req is true" do
        result = instance.depends_on("rake", req: true)
        expect(result).must_equal true
      end

      it "returns true when req is false" do
        result = instance.depends_on("rake", req: false)
        expect(result).must_equal true
      end

      it "returns true when req is a truthy value other than true or false" do
        instance.define_singleton_method(:require) { |_lib| true }
        result = instance.depends_on("rake", req: "custom_lib")
        expect(result).must_equal true
      end
    end

    describe "error classes" do
      it "defines LoadError as a subclass of ::LoadError" do
        expect(Riffer::Helpers::Dependencies::LoadError < ::LoadError).must_equal true
      end

      it "defines VersionError as a subclass of ScriptError" do
        expect(Riffer::Helpers::Dependencies::VersionError < ScriptError).must_equal true
      end
    end

    describe "with a real installed gem from Gemfile" do
      # Using "rake" which is a dev dependency in the Gemfile
      before do
        instance.define_singleton_method(:gem) { |_name| true }
        instance.define_singleton_method(:defined?) { |const| (const == "Bundler") ? "constant" : nil }
      end

      it "returns true when gem is in Gemfile and version matches" do
        result = instance.depends_on("rake", req: false)
        expect(result).must_equal true
      end

      it "returns true when req is a custom library name and require succeeds" do
        instance.define_singleton_method(:require) { |_lib| true }
        result = instance.depends_on("rake", req: "custom_lib")
        expect(result).must_equal true
      end
    end
  end
end
