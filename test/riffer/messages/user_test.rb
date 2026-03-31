# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::User do
  describe "#role" do
    it "returns user" do
      message = Riffer::Messages::User.new("Hello")
      expect(message.role).must_equal :user
    end
  end

  describe "#files" do
    it "defaults to empty array" do
      message = Riffer::Messages::User.new("Hello")
      expect(message.files).must_equal []
    end

    it "stores file parts" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      message = Riffer::Messages::User.new("Describe this", files: [file])
      expect(message.files.length).must_equal 1
    end

    it "returns the provided file parts" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      message = Riffer::Messages::User.new("Describe this", files: [file])
      expect(message.files.first).must_equal file
    end
  end

  describe "#timestamp" do
    it "sets a default timestamp" do
      before = Time.now
      message = Riffer::Messages::User.new("Hello")
      after = Time.now
      expect(message.timestamp).must_be :>=, before
      expect(message.timestamp).must_be :<=, after
    end

    it "accepts a custom timestamp" do
      custom_time = Time.new(2025, 1, 15, 12, 0, 0)
      message = Riffer::Messages::User.new("Hello", timestamp: custom_time)
      expect(message.timestamp).must_equal custom_time
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      message = Riffer::Messages::User.new("Hello")
      expect(message.to_h.except(:timestamp)).must_equal({role: :user, content: "Hello"})
    end

    it "includes timestamp as ISO 8601 with milliseconds" do
      custom_time = Time.new(2025, 1, 15, 12, 0, 0)
      message = Riffer::Messages::User.new("Hello", timestamp: custom_time)
      expect(message.to_h[:timestamp]).must_equal custom_time.iso8601(3)
    end

    it "omits files key when files is empty" do
      message = Riffer::Messages::User.new("Hello")
      expect(message.to_h.key?(:files)).must_equal false
    end

    it "includes files when present" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      message = Riffer::Messages::User.new("Describe this", files: [file])
      expect(message.to_h[:files]).must_be_instance_of Array
    end

    it "serializes files as hashes" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      message = Riffer::Messages::User.new("Describe this", files: [file])
      expect(message.to_h[:files].first[:media_type]).must_equal "image/png"
    end
  end
end
