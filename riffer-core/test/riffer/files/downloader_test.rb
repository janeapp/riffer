# frozen_string_literal: true

require "test_helper"
require "webrick"

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

    # WebMock and VCR sort the query before matching, so these record the
    # request line a real server receives.
    describe "query strings" do
      before do
        WebMock.disable_net_connect!(allow_localhost: true)
        @request_paths = []
        paths = @request_paths
        @server = WEBrick::HTTPServer.new(Port: 0, BindAddress: "127.0.0.1", Logger: WEBrick::Log.new(File::NULL),
                                          AccessLog: [],)
        @server.mount_proc("/") do |req, res|
          paths << req.request_line.split[1]
          if req.path == "/redirect"
            res.status = 302
            res["Location"] = "/final?z=1&a=2&a=1&s=%20x"
          else
            res.body = "ok"
          end
        end
        @thread = Thread.new { @server.start }
      end

      after do
        WebMock.disable_net_connect!
        @server&.shutdown
        @thread&.join
      end

      def fetch(path)
        VCR.turned_off { downloader.call([file_for("http://127.0.0.1:#{@server.config[:Port]}#{path}")]) }
      end

      ["/a?b=2&a=1", "/a?a=1&a=2", "/a?x=%20y&sig=ab%2Fcd", "/a"].each do |path|
        it "requests #{path} as given" do
          fetch(path)

          expect(@request_paths).must_equal [path]
        end
      end

      it "requests an empty query without the ?" do
        fetch("/a?")

        expect(@request_paths).must_equal ["/a"]
      end

      it "follows a redirect Location with its query as given" do
        fetch("/redirect?q=1")

        expect(@request_paths).must_equal ["/redirect?q=1", "/final?z=1&a=2&a=1&s=%20x"]
      end
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

  describe "the subclasses in docs/CONFIGURATION.md" do
    parallel = Class.new(Riffer::Files::Downloader) do
      def initialize(max_concurrency: 4)
        super()
        @max_concurrency = max_concurrency
      end

      def call(files)
        files.each_slice(@max_concurrency).flat_map do |group|
          threads = group.map do |file|
            Thread.new do
              super([file]).first
            rescue StandardError => e
              e
            end
          end
          results = threads.map(&:value)
          error = results.find { |result| result.is_a?(StandardError) }
          raise error if error

          results
        end
      end
    end

    checksum = Class.new(parallel) do
      def call(files)
        super.zip(files).map do |bytes, file|
          raise Riffer::FileError, file.url if file.sha256 && Digest::SHA256.hexdigest(bytes) != file.sha256

          bytes
        end
      end
    end

    let(:urls) { (1..5).map { |i| "https://example.com/#{i}.pdf" } }

    before do
      urls.each_with_index { |u, i| stub_request(:get, u).to_return(status: 200, body: "body #{i}") }
    end

    it "downloads in parallel groups and keeps the order of the files" do
      bodies = parallel.new(max_concurrency: 2).call(urls.map { |u| file_for(u) })

      expect(bodies).must_equal((0..4).map { |i| "body #{i}" })
    end

    it "fails the batch when one file fails" do
      stub_request(:get, urls[2]).to_return(status: 500)

      files = urls.map { |u| file_for(u) }

      expect { parallel.new(max_concurrency: 2).call(files) }.must_raise Riffer::FileDownloadError
    end

    it "waits for the rest of the group before failing the batch" do
      stub_request(:get, urls[0]).to_return(status: 500)
      stub_request(:get, urls[1]).to_return do
        sleep 0.05
        { status: 200, body: "slow" }
      end
      threads_before = Thread.list.size

      expect { parallel.new(max_concurrency: 2).call(urls.map { |u| file_for(u) }) }.must_raise Riffer::FileDownloadError
      expect(Thread.list.size).must_equal threads_before
    end

    it "checks sha256 on top of the parallel downloader" do
      good = Riffer::Messages::User::FilePart.new(
        url: urls[0], media_type: "application/pdf", sha256: Digest::SHA256.hexdigest("body 0"),
      )
      bad = Riffer::Messages::User::FilePart.new(url: urls[1], media_type: "application/pdf", sha256: "0" * 64)

      expect(checksum.new.call([good])).must_equal ["body 0"]
      expect { checksum.new.call([good, bad]) }.must_raise Riffer::FileError
    end
  end
end
