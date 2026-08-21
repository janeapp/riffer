# frozen_string_literal: true

require "test_helper"

describe Riffer::Files::Downloader do
  let(:downloader) { Riffer::Files::Downloader.new }
  let(:url) { "https://example.com/file.pdf" }

  describe "#call" do
    it "returns the base64-encoded response body" do
      stub_request(:get, url).to_return(status: 200, body: "hello world")
      result = downloader.call(url, max_bytes: 1_000, timeout: 5)

      expect(result).must_equal Base64.strict_encode64("hello world")
    end

    it "raises Riffer::FileDownloadError for a non-success status" do
      stub_request(:get, url).to_return(status: 404, body: "not found")

      expect { downloader.call(url, max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end

    it "raises Riffer::FileTooLargeError when content-length exceeds max_bytes" do
      stub_request(:get, url).to_return(status: 200, body: "hello world", headers: { "content-length" => "11" })

      expect { downloader.call(url, max_bytes: 5, timeout: 5) }.must_raise Riffer::FileTooLargeError
    end

    it "raises Riffer::FileTooLargeError when the streamed body exceeds max_bytes without a content-length header" do
      stub_request(:get, url).to_return(status: 200, body: "hello world")

      expect { downloader.call(url, max_bytes: 5, timeout: 5) }.must_raise Riffer::FileTooLargeError
    end

    it "raises Riffer::FileDownloadError for an unparseable URL" do
      expect { downloader.call("not a url", max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end

    it "raises Riffer::FileDownloadError for a URL with no host" do
      expect { downloader.call("https:", max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end

    it "raises Riffer::FileDownloadError for a non-https scheme" do
      expect { downloader.call("http://example.com/file.pdf", max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end

    it "follows a redirect and returns the final response body" do
      redirected_url = "https://example.com/final.pdf"
      stub_request(:get, url).to_return(status: 302, headers: { "location" => redirected_url })
      stub_request(:get, redirected_url).to_return(status: 200, body: "final content")

      result = downloader.call(url, max_bytes: 1_000, timeout: 5)

      expect(result).must_equal Base64.strict_encode64("final content")
    end

    it "raises Riffer::FileDownloadError when redirects exceed the limit" do
      stub_request(:get, url).to_return(status: 302, headers: { "location" => url })

      expect { downloader.call(url, max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end

    it "raises Riffer::FileDownloadError when a redirect has no Location header" do
      stub_request(:get, url).to_return(status: 302)

      expect { downloader.call(url, max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end

    it "wraps an unexpected transport error as Riffer::FileDownloadError" do
      stub_request(:get, url).to_raise(SocketError)

      expect { downloader.call(url, max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
    end
  end
end
