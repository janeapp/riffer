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

  describe "#id" do
    it "is preserved when passed explicitly" do
      message = Riffer::Messages::User.new("Hi", id: "user-1")
      expect(message.id).must_equal "user-1"
    end
  end

  describe "#+" do
    it "concatenates content" do
      a = Riffer::Messages::User.new("First")
      b = Riffer::Messages::User.new("Second")

      result = a + b

      expect(result.content).must_equal "First\n\nSecond"
    end

    it "generates a fresh id rather than inheriting from operands" do
      original = Riffer.config.message_id_strategy
      Riffer.config.message_id_strategy = :uuidv7
      a = Riffer::Messages::User.new("First", id: "a-id")
      b = Riffer::Messages::User.new("Second", id: "b-id")

      result = a + b

      expect(result.id).wont_equal "a-id"
      expect(result.id).wont_equal "b-id"
      expect(result.id).wont_be_nil
    ensure
      Riffer.config.message_id_strategy = original
    end

    it "returns a User message" do
      a = Riffer::Messages::User.new("First")
      b = Riffer::Messages::User.new("Second")

      result = a + b

      expect(result).must_be_instance_of Riffer::Messages::User
    end

    it "combines files from both messages" do
      file_a = Riffer::FilePart.new(data: "abc", media_type: "image/png")
      file_b = Riffer::FilePart.new(data: "def", media_type: "image/jpeg")
      a = Riffer::Messages::User.new("With image", files: [file_a])
      b = Riffer::Messages::User.new("Another", files: [file_b])

      result = a + b

      expect(result.files).must_equal [file_a, file_b]
    end

    it "preserves empty files" do
      a = Riffer::Messages::User.new("No files")
      b = Riffer::Messages::User.new("Also no files")

      result = a + b

      expect(result.files).must_equal []
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      message = Riffer::Messages::User.new("Hello")
      expect(message.to_h).must_equal({role: :user, content: "Hello"})
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
