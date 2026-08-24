# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::FilePart do
  describe ".new" do
    it "creates a file part with data and media_type" do
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png")

      expect(file.data).must_equal "aGVsbG8="
      expect(file.media_type).must_equal "image/png"
    end

    it "creates a file part with url and media_type" do
      file = Riffer::Messages::FilePart.new(url: "https://example.com/image.png", media_type: "image/png")

      expect(file.url).must_equal "https://example.com/image.png"
      expect(file.media_type).must_equal "image/png"
    end

    it "accepts optional filename" do
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png", filename: "photo.png")

      expect(file.filename).must_equal "photo.png"
    end

    it "raises when neither data nor url is provided" do
      error = expect do
        Riffer::Messages::FilePart.new(media_type: "image/png")
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Either data or url/)
    end

    it "raises for unsupported media type" do
      error = expect do
        Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "video/mp4")
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Unsupported media type/)
    end

    it "accepts a valid sha256 and downcases it" do
      sha256 = Digest::SHA256.hexdigest("hello").upcase
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png", sha256: sha256)

      expect(file.sha256).must_equal sha256.downcase
    end

    it "raises for a malformed sha256 string" do
      error = expect do
        Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png", sha256: "not-a-hash")
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Invalid sha256/)
    end

    it "raises for a non-String sha256 instead of crashing on #match?" do
      error = expect do
        Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png", sha256: 123)
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Invalid sha256/)
    end
  end

  describe ".from_url" do
    it "stores the url and detects media type from extension" do
      file = Riffer::Messages::FilePart.from_url("https://example.com/photo.jpg")

      expect(file.url).must_equal "https://example.com/photo.jpg"
      expect(file.media_type).must_equal "image/jpeg"
    end

    it "accepts explicit media_type" do
      file = Riffer::Messages::FilePart.from_url("https://example.com/file", media_type: "application/pdf")

      expect(file.media_type).must_equal "application/pdf"
    end

    it "accepts an explicit filename" do
      file = Riffer::Messages::FilePart.from_url("https://example.com/file", media_type: "application/pdf",
                                                                             filename: "report.pdf",)

      expect(file.filename).must_equal "report.pdf"
    end

    it "raises when media type cannot be detected" do
      error = expect do
        Riffer::Messages::FilePart.from_url("https://example.com/file")
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Cannot detect media type/)
    end
  end

  describe ".from_hash" do
    it "passes through FilePart objects" do
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      result = Riffer::Messages::FilePart.from_hash(file)

      expect(result).must_equal file
    end

    it "converts url hash" do
      result = Riffer::Messages::FilePart.from_hash({ url: "https://example.com/photo.jpg", media_type: "image/jpeg" })

      expect(result).must_be_instance_of Riffer::Messages::FilePart
      expect(result.url).must_equal "https://example.com/photo.jpg"
    end

    it "forwards filename for a url hash" do
      result = Riffer::Messages::FilePart.from_hash(
        { url: "https://example.com/file", media_type: "application/pdf", filename: "report.pdf" },
      )

      expect(result.filename).must_equal "report.pdf"
    end

    it "converts data hash" do
      result = Riffer::Messages::FilePart.from_hash({ data: "aGVsbG8=", media_type: "image/png" })

      expect(result).must_be_instance_of Riffer::Messages::FilePart
      expect(result.data).must_equal "aGVsbG8="
    end

    it "raises for invalid hash" do
      error = expect do
        Riffer::Messages::FilePart.from_hash({ media_type: "image/png" })
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/must include :url or :data/)
    end

    it "raises for a non-String sha256 in a data hash instead of crashing on #match?" do
      error = expect do
        Riffer::Messages::FilePart.from_hash({ data: "aGVsbG8=", media_type: "image/png", sha256: 123 })
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Invalid sha256/)
    end

    it "raises for a non-String sha256 in a url hash instead of crashing on #match?" do
      error = expect do
        Riffer::Messages::FilePart.from_hash({ url: "https://example.com/file.pdf", media_type: "application/pdf",
                                               sha256: 123, })
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Invalid sha256/)
    end

    it "raises for non-hash non-FilePart" do
      error = expect do
        Riffer::Messages::FilePart.from_hash("invalid")
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/must be a Hash or FilePart/)
    end
  end

  describe "#url?" do
    it "returns true when created from url" do
      file = Riffer::Messages::FilePart.new(url: "https://example.com/image.png", media_type: "image/png")

      expect(file.url?).must_equal true
    end

    it "returns false when created from data" do
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png")

      expect(file.url?).must_equal false
    end
  end

  describe "#inline_data?" do
    it "returns true when created with data" do
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png")

      expect(file.inline_data?).must_equal true
    end

    it "returns false for a url source that hasn't been downloaded" do
      file = Riffer::Messages::FilePart.from_url("https://example.com/image.png")

      expect(file.inline_data?).must_equal false
    end

    it "stays false for a url source after the resolver caches downloaded bytes" do
      file = Riffer::Messages::FilePart.from_url("https://example.com/image.png")
      file.cache_downloaded_data("aGVsbG8=")

      expect(file.inline_data?).must_equal false
      expect(file.data).must_equal "aGVsbG8="
    end
  end

  describe "#image?" do
    it "returns true for image media types" do
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/jpeg")

      expect(file.image?).must_equal true
    end

    it "returns false for document media types" do
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "application/pdf")

      expect(file.image?).must_equal false
    end
  end

  describe "#document?" do
    it "returns true for document media types" do
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "application/pdf")

      expect(file.document?).must_equal true
    end

    it "returns false for image media types" do
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png")

      expect(file.document?).must_equal false
    end
  end

  describe "#to_h" do
    it "includes media_type and data" do
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      hash = file.to_h

      expect(hash[:media_type]).must_equal "image/png"
      expect(hash[:data]).must_equal "aGVsbG8="
    end

    it "includes url when present" do
      file = Riffer::Messages::FilePart.new(url: "https://example.com/image.png", media_type: "image/png")
      hash = file.to_h

      expect(hash[:url]).must_equal "https://example.com/image.png"
    end

    it "includes filename when present" do
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png", filename: "photo.png")

      expect(file.to_h[:filename]).must_equal "photo.png"
    end

    it "omits data when source is url only" do
      file = Riffer::Messages::FilePart.new(url: "https://example.com/image.png", media_type: "image/png")

      expect(file.to_h.key?(:data)).must_equal false
    end

    it "omits url when source is data only" do
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png")

      expect(file.to_h.key?(:url)).must_equal false
    end

    it "omits filename when nil" do
      file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png")

      expect(file.to_h.key?(:filename)).must_equal false
    end
  end

  describe "#data with url source" do
    it "returns nil for url-only parts" do
      file = Riffer::Messages::FilePart.from_url("https://example.com/image.png")

      expect(file.data).must_be_nil
    end

    it "returns data when both url and data are provided" do
      file = Riffer::Messages::FilePart.new(
        url: "https://example.com/image.png",
        data: "aGVsbG8=",
        media_type: "image/png",
      )

      expect(file.data).must_equal "aGVsbG8="
    end
  end

  describe "#data_bytes" do
    it "decodes the base64 data" do
      file = Riffer::Messages::FilePart.new(data: Base64.strict_encode64("hello"), media_type: "text/plain")

      expect(file.data_bytes).must_equal "hello"
    end

    it "returns nil for a url source that hasn't been downloaded" do
      file = Riffer::Messages::FilePart.from_url("https://example.com/image.png")

      expect(file.data_bytes).must_be_nil
    end

    it "decodes only once, reusing the memoized value on later calls" do
      file = Riffer::Messages::FilePart.new(data: Base64.strict_encode64("hello"), media_type: "text/plain")

      first = file.data_bytes
      second = file.data_bytes

      # A fresh decode would allocate a new String; identity proves the
      # second call returned the memoized one instead of decoding again.
      expect(second).must_be_same_as first
    end

    it "uses bytes cached by cache_data_bytes without decoding" do
      file = Riffer::Messages::FilePart.from_url("https://example.com/image.png")
      raw = "raw bytes"
      file.cache_data_bytes(raw)

      expect(file.data_bytes).must_be_same_as raw
    end

    it "decodes line-wrapped Base64.encode64 output" do
      file = Riffer::Messages::FilePart.new(data: Base64.encode64("hello" * 20), media_type: "text/plain")

      expect(file.data_bytes).must_equal "hello" * 20
    end

    it "raises Riffer::FileEncodingError instead of silently truncating data with embedded padding" do
      # Base64.decode64 (lenient) stops at the first `=`, so naively decoding
      # this would yield "hello world" and hide the appended second payload
      # from anything that hashes the result — strict decoding must reject it.
      smuggled = Base64.strict_encode64("hello world") + Base64.strict_encode64("second payload")
      file = Riffer::Messages::FilePart.new(data: smuggled, media_type: "text/plain")

      expect(Base64.decode64(smuggled)).must_equal "hello world" # confirms the lenient decode would hide data
      expect { file.data_bytes }.must_raise Riffer::FileEncodingError
    end

    it "raises Riffer::FileEncodingError for data that isn't base64 at all" do
      file = Riffer::Messages::FilePart.new(data: "not base64!!!", media_type: "text/plain")

      expect { file.data_bytes }.must_raise Riffer::FileEncodingError
    end
  end

  describe "MEDIA_TYPES" do
    it "includes jpeg extensions" do
      expect(Riffer::Messages::FilePart::MEDIA_TYPES[".jpg"]).must_equal "image/jpeg"
      expect(Riffer::Messages::FilePart::MEDIA_TYPES[".jpeg"]).must_equal "image/jpeg"
    end

    it "includes png" do
      expect(Riffer::Messages::FilePart::MEDIA_TYPES[".png"]).must_equal "image/png"
    end

    it "includes pdf" do
      expect(Riffer::Messages::FilePart::MEDIA_TYPES[".pdf"]).must_equal "application/pdf"
    end
  end
end
