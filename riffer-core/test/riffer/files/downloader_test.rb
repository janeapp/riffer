# frozen_string_literal: true

require "test_helper"

describe Riffer::Files::Downloader do
  let(:downloader) { Riffer::Files::Downloader.new }
  let(:url) { "https://example.com/file.pdf" }

  def file_for(url)
    Riffer::Messages::User::FilePart.new(url: url, media_type: "application/pdf")
  end

  describe "#call" do
    it "returns the raw response body" do
      stub_request(:get, url).to_return(status: 200, body: "hello world")

      expect(downloader.call([file_for(url)])).must_equal ["hello world"]
    end

    it "returns the bodies in the order of the files" do
      stub_request(:get, "https://example.com/a.pdf").to_return(status: 200, body: "a")
      stub_request(:get, "https://example.com/b.pdf").to_return(status: 200, body: "b")
      files = [file_for("https://example.com/b.pdf"), file_for("https://example.com/a.pdf")]

      expect(downloader.call(files)).must_equal %w[b a]
    end

    it "returns an empty array for no files" do
      expect(downloader.call([])).must_equal []
    end

    it "downloads over http" do
      stub_request(:get, "http://example.com/file.pdf").to_return(status: 200, body: "plain")

      expect(downloader.call([file_for("http://example.com/file.pdf")])).must_equal ["plain"]
    end

    it "raises Riffer::FileDownloadError for a non-2xx status" do
      stub_request(:get, url).to_return(status: 404, body: "not found")
      error = expect { downloader.call([file_for(url)]) }.must_raise Riffer::FileDownloadError

      expect(error.message).must_equal "File download failed, status: 404"
    end

    it "raises Riffer::FileDownloadError for a 3xx without a Location header" do
      stub_request(:get, url).to_return(status: 302)

      expect { downloader.call([file_for(url)]) }.must_raise Riffer::FileDownloadError
    end

    it "fails the whole batch when one file fails" do
      stub_request(:get, "https://example.com/a.pdf").to_return(status: 200, body: "a")
      stub_request(:get, "https://example.com/b.pdf").to_return(status: 500)
      files = [file_for("https://example.com/a.pdf"), file_for("https://example.com/b.pdf")]

      expect { downloader.call(files) }.must_raise Riffer::FileDownloadError
    end

    it "wraps a Faraday error as Riffer::FileDownloadError with the original as its cause" do
      stub_request(:get, url).to_raise(SocketError)
      error = expect { downloader.call([file_for(url)]) }.must_raise Riffer::FileDownloadError

      expect(error.cause).must_be_kind_of Faraday::ConnectionFailed
    end

    it "wraps a timeout as Riffer::FileDownloadError with the original as its cause" do
      stub_request(:get, url).to_timeout
      error = expect { downloader.call([file_for(url)]) }.must_raise Riffer::FileDownloadError

      expect(error.cause).must_be_kind_of Faraday::Error
    end

    it "raises Riffer::FileDownloadError for an unparseable URL" do
      error = expect { downloader.call([file_for("https://exa mple.com/a.pdf")]) }.must_raise Riffer::FileDownloadError

      expect(error.cause).must_be_kind_of URI::InvalidURIError
    end

    it "raises Riffer::FileDownloadError for a URL with no host" do
      expect { downloader.call([file_for("https:/a.pdf")]) }.must_raise Riffer::FileDownloadError
    end

    it "raises Riffer::FileDownloadError for a scheme other than http or https" do
      error = expect { downloader.call([file_for("s3://bucket/a.pdf")]) }.must_raise Riffer::FileDownloadError

      expect(error.message).must_equal "Unsupported URL scheme: s3"
    end

    describe "called with a URL by a downloader on the old contract" do
      before { Riffer.config.silenced_deprecations = %i[file_error_constants] }
      after { Riffer.config.silenced_deprecations = [] }

      it "downloads through the old implementation" do
        stub_request(:get, url).to_return(status: 200, body: "hello world")

        expect(downloader.call(url, max_bytes: 1_000, timeout: 5)).must_equal "hello world"
      end

      it "keeps max_bytes and https-only" do
        stub_request(:get, url).to_return(status: 200, body: "hello world")

        expect { downloader.call(url, max_bytes: 5, timeout: 5) }.must_raise Riffer::FileTooLargeError
        expect { downloader.call("http://example.com/a.pdf", max_bytes: 1_000, timeout: 5) }.must_raise Riffer::FileDownloadError
      end
    end

    describe "redirects" do
      it "follows a redirect and returns the final body" do
        stub_request(:get, url).to_return(status: 302, headers: { "location" => "https://example.com/final.pdf" })
        stub_request(:get, "https://example.com/final.pdf").to_return(status: 200, body: "final content")

        expect(downloader.call([file_for(url)])).must_equal ["final content"]
      end

      it "resolves a relative Location against the URL that sent it" do
        stub_request(:get, url).to_return(status: 301, headers: { "location" => "/files/final.pdf" })
        stub_request(:get, "https://example.com/files/final.pdf").to_return(status: 200, body: "final content")

        expect(downloader.call([file_for(url)])).must_equal ["final content"]
      end

      it "follows a redirect from https to http" do
        stub_request(:get, url).to_return(status: 307, headers: { "location" => "http://cdn.example.com/a.pdf" })
        stub_request(:get, "http://cdn.example.com/a.pdf").to_return(status: 200, body: "plain")

        expect(downloader.call([file_for(url)])).must_equal ["plain"]
      end

      it "follows up to 3 redirects" do
        stub_request(:get, url).to_return(status: 302, headers: { "location" => "/1" })
        stub_request(:get, "https://example.com/1").to_return(status: 302, headers: { "location" => "/2" })
        stub_request(:get, "https://example.com/2").to_return(status: 302, headers: { "location" => "/3" })
        stub_request(:get, "https://example.com/3").to_return(status: 200, body: "third")

        expect(downloader.call([file_for(url)])).must_equal ["third"]
      end

      it "raises Riffer::FileDownloadError on the 4th redirect" do
        stub_request(:get, url).to_return(status: 302, headers: { "location" => url })
        error = expect { downloader.call([file_for(url)]) }.must_raise Riffer::FileDownloadError

        expect(error.message).must_equal "Too many redirects"
        assert_requested :get, url, times: 4
      end

      it "raises Riffer::FileDownloadError for a redirect to another scheme" do
        stub_request(:get, url).to_return(status: 302, headers: { "location" => "ftp://example.com/a.pdf" })

        expect { downloader.call([file_for(url)]) }.must_raise Riffer::FileDownloadError
      end
    end
  end
end
