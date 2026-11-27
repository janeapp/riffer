# frozen_string_literal: true

require "test_helper"

describe Riffer::Files::Downloader do
  let(:downloader) { Riffer::Files::Downloader.new }
  let(:url) { "https://example.com/file.pdf" }
  let(:file) { Riffer::Messages::User::FilePart.from_url(url) }

  def file_for(url, sha256: nil)
    Riffer::Messages::User::FilePart.new(url: url, media_type: "application/pdf", sha256: sha256)
  end

  describe "#call" do
    it "returns the raw response body" do
      stub_request(:get, url).to_return(status: 200, body: "hello world")
      result = downloader.call(file, max_bytes: 1_000, timeout: 5)

      expect(result).must_equal "hello world"
    end

    it "raises Riffer::FileDownloadError for a non-success status" do
      stub_request(:get, url).to_return(status: 404, body: "not found")

      expect { downloader.call(file, max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end

    it "raises Riffer::FileTooLargeError when content-length exceeds max_bytes" do
      stub_request(:get, url).to_return(status: 200, body: "hello world", headers: { "content-length" => "11" })

      expect { downloader.call(file, max_bytes: 5, timeout: 5) }.must_raise Riffer::FileTooLargeError
    end

    it "raises Riffer::FileTooLargeError when the streamed body exceeds max_bytes without a content-length header" do
      stub_request(:get, url).to_return(status: 200, body: "hello world")

      expect { downloader.call(file, max_bytes: 5, timeout: 5) }.must_raise Riffer::FileTooLargeError
    end

    it "raises Riffer::FileDownloadError for an unparseable URL" do
      expect { downloader.call(file_for("not a url"), max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end

    it "raises Riffer::FileDownloadError for a URL with no host" do
      expect { downloader.call(file_for("https:"), max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end

    it "raises Riffer::FileDownloadError for a non-https scheme" do
      expect { downloader.call(file_for("http://example.com/file.pdf"), max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end

    it "follows a redirect and returns the final response body" do
      redirected_url = "https://example.com/final.pdf"
      stub_request(:get, url).to_return(status: 302, headers: { "location" => redirected_url })
      stub_request(:get, redirected_url).to_return(status: 200, body: "final content")

      result = downloader.call(file, max_bytes: 1_000, timeout: 5)

      expect(result).must_equal "final content"
    end

    it "follows a relative redirect against the URL that sent it" do
      stub_request(:get, url).to_return(status: 302, headers: { "location" => "/files/final.pdf" })
      stub_request(:get, "https://example.com/files/final.pdf").to_return(status: 200, body: "final content")

      expect(downloader.call(file, max_bytes: 1_000, timeout: 5)).must_equal "final content"
    end

    it "keeps https for a scheme-relative redirect" do
      stub_request(:get, url).to_return(status: 302, headers: { "location" => "//cdn.example.com/final.pdf" })
      stub_request(:get, "https://cdn.example.com/final.pdf").to_return(status: 200, body: "final content")

      expect(downloader.call(file, max_bytes: 1_000, timeout: 5)).must_equal "final content"
    end

    it "raises Riffer::FileDownloadError when a redirect leaves https" do
      stub_request(:get, url).to_return(status: 302, headers: { "location" => "http://example.com/final.pdf" })

      expect { downloader.call(file, max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end

    it "raises Riffer::FileDownloadError when redirects exceed the limit" do
      stub_request(:get, url).to_return(status: 302, headers: { "location" => url })

      expect { downloader.call(file, max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end

    it "raises Riffer::FileDownloadError when a redirect has no Location header" do
      stub_request(:get, url).to_return(status: 302)

      expect { downloader.call(file, max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end

    it "returns the body when it matches the file's sha256" do
      stub_request(:get, url).to_return(status: 200, body: "hello world")
      matching = file_for(url, sha256: Digest::SHA256.hexdigest("hello world"))
      result = downloader.call(matching, max_bytes: 1_000, timeout: 5)

      expect(result).must_equal "hello world"
    end

    it "raises Riffer::FileChecksumMismatchError when the body doesn't match the file's sha256" do
      stub_request(:get, url).to_return(status: 200, body: "hello world")
      mismatched = file_for(url, sha256: Digest::SHA256.hexdigest("something else"))

      expect { downloader.call(mismatched, max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileChecksumMismatchError
    end

    it "checks the sha256 against the body after a redirect" do
      redirected_url = "https://example.com/final.pdf"
      stub_request(:get, url).to_return(status: 302, headers: { "location" => redirected_url })
      stub_request(:get, redirected_url).to_return(status: 200, body: "final content")
      mismatched = file_for(url, sha256: Digest::SHA256.hexdigest("hello world"))

      expect { downloader.call(mismatched, max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileChecksumMismatchError
    end

    it "still accepts a URL string, as passed under the deprecated url-only contract" do
      stub_request(:get, url).to_return(status: 200, body: "hello world")

      expect(downloader.call(url, max_bytes: 1_000, timeout: 5)).must_equal "hello world"
    end

    it "wraps an unexpected transport error as Riffer::FileDownloadError" do
      stub_request(:get, url).to_raise(SocketError)

      expect { downloader.call(file, max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end
  end
end
