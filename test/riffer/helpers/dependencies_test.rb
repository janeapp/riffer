# frozen_string_literal: true

require "test_helper"

describe Riffer::Helpers::Dependencies do
  let(:subject_class) do
    Class.new { include Riffer::Helpers::Dependencies }
  end

  let(:instance) { subject_class.new }

  describe "#depends_on" do
    describe "when the gem is installed" do
      it "returns true" do
        result = instance.depends_on("rake")

        expect(result).must_equal true
      end
    end

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

    describe "error classes" do
      it "defines LoadError as a subclass of ::LoadError" do
        expect(Riffer::Helpers::Dependencies::LoadError < LoadError).must_equal true
      end
    end
  end
end
