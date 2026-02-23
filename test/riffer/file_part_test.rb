# frozen_string_literal: true

require "test_helper"

describe Riffer::FilePart do
  describe ".new" do
    it "creates a file part with data and media_type" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      expect(file.data).must_equal "aGVsbG8="
      expect(file.media_type).must_equal "image/png"
    end

    it "creates a file part with url and media_type" do
      file = Riffer::FilePart.new(url: "https://example.com/image.png", media_type: "image/png")
      expect(file.url).must_equal "https://example.com/image.png"
      expect(file.media_type).must_equal "image/png"
    end

    it "accepts optional filename" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png", filename: "photo.png")
      expect(file.filename).must_equal "photo.png"
    end

    it "raises when neither data nor url is provided" do
      error = expect {
        Riffer::FilePart.new(media_type: "image/png")
      }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Either data or url/)
    end

    it "raises for unsupported media type" do
      error = expect {
        Riffer::FilePart.new(data: "aGVsbG8=", media_type: "video/mp4")
      }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Unsupported media type/)
    end
  end

  describe ".from_url" do
    it "stores the url and detects media type from extension" do
      file = Riffer::FilePart.from_url("https://example.com/photo.jpg")
      expect(file.url).must_equal "https://example.com/photo.jpg"
      expect(file.media_type).must_equal "image/jpeg"
    end

    it "accepts explicit media_type" do
      file = Riffer::FilePart.from_url("https://example.com/file", media_type: "application/pdf")
      expect(file.media_type).must_equal "application/pdf"
    end

    it "raises when media type cannot be detected" do
      error = expect {
        Riffer::FilePart.from_url("https://example.com/file")
      }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Cannot detect media type/)
    end
  end

  describe "#url?" do
    it "returns true when created from url" do
      file = Riffer::FilePart.new(url: "https://example.com/image.png", media_type: "image/png")
      expect(file.url?).must_equal true
    end

    it "returns false when created from data" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      expect(file.url?).must_equal false
    end
  end

  describe "#image?" do
    it "returns true for image media types" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/jpeg")
      expect(file.image?).must_equal true
    end

    it "returns false for document media types" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "application/pdf")
      expect(file.image?).must_equal false
    end
  end

  describe "#document?" do
    it "returns true for document media types" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "application/pdf")
      expect(file.document?).must_equal true
    end

    it "returns false for image media types" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      expect(file.document?).must_equal false
    end
  end

  describe "#to_h" do
    it "includes media_type and data" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      hash = file.to_h
      expect(hash[:media_type]).must_equal "image/png"
      expect(hash[:data]).must_equal "aGVsbG8="
    end

    it "includes url when present" do
      file = Riffer::FilePart.new(url: "https://example.com/image.png", media_type: "image/png")
      hash = file.to_h
      expect(hash[:url]).must_equal "https://example.com/image.png"
    end

    it "includes filename when present" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png", filename: "photo.png")
      expect(file.to_h[:filename]).must_equal "photo.png"
    end

    it "omits data when source is url only" do
      file = Riffer::FilePart.new(url: "https://example.com/image.png", media_type: "image/png")
      expect(file.to_h.key?(:data)).must_equal false
    end

    it "omits url when source is data only" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      expect(file.to_h.key?(:url)).must_equal false
    end

    it "omits filename when nil" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      expect(file.to_h.key?(:filename)).must_equal false
    end
  end

  describe "#data with url source" do
    it "returns nil for url-only parts" do
      file = Riffer::FilePart.from_url("https://example.com/image.png")
      expect(file.data).must_be_nil
    end

    it "returns data when both url and data are provided" do
      file = Riffer::FilePart.new(url: "https://example.com/image.png", data: "aGVsbG8=", media_type: "image/png")
      expect(file.data).must_equal "aGVsbG8="
    end
  end

  describe "MEDIA_TYPES" do
    it "includes jpeg extensions" do
      expect(Riffer::FilePart::MEDIA_TYPES[".jpg"]).must_equal "image/jpeg"
      expect(Riffer::FilePart::MEDIA_TYPES[".jpeg"]).must_equal "image/jpeg"
    end

    it "includes png" do
      expect(Riffer::FilePart::MEDIA_TYPES[".png"]).must_equal "image/png"
    end

    it "includes pdf" do
      expect(Riffer::FilePart::MEDIA_TYPES[".pdf"]).must_equal "application/pdf"
    end
  end
end
