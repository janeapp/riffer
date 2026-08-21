# frozen_string_literal: true

require "test_helper"

describe Riffer::Files::Resolver do
  let(:downloaded_calls) { [] }
  let(:downloaded_content) { "downloaded content" }
  let(:fake_downloader) do
    calls = downloaded_calls
    content = downloaded_content
    lambda do |url, max_bytes:, timeout:|
      calls << { url: url, max_bytes: max_bytes, timeout: timeout }
      Base64.strict_encode64(content)
    end
  end

  before do
    @original_allow_downloads = Riffer.config.files.allow_downloads
    @original_max_per_message = Riffer.config.files.max_per_message
    @original_downloader = Riffer.config.files.downloader
    @original_runner = Riffer.config.files.runner
    Riffer.config.files.allow_downloads = true
    Riffer.config.files.downloader = fake_downloader
  end

  after do
    Riffer.config.files.allow_downloads = @original_allow_downloads
    Riffer.config.files.max_per_message = @original_max_per_message
    Riffer.config.files.downloader = @original_downloader
    Riffer.config.files.runner = @original_runner
  end

  def resolver_for(delivery)
    provider = Object.new
    provider.define_singleton_method(:file_delivery) { |_file| delivery }
    Riffer::Files::Resolver.new(provider: provider)
  end

  describe "#resolve!" do
    it "ignores non-user messages" do
      messages = [Riffer::Messages::System.new("be helpful"), Riffer::Messages::Assistant.new("hi")]
      resolver_for(:url).resolve!(messages)

      expect(downloaded_calls).must_be_empty
    end

    describe "an inline data source" do
      let(:body) { "inline body" }
      let(:data) { Base64.strict_encode64(body) }
      let(:sha256) { Digest::SHA256.hexdigest(body) }

      it "leaves the file untouched when no sha256 is given" do
        file = Riffer::Messages::FilePart.new(media_type: "text/plain", data: data)
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:unsupported).resolve!([message])

        expect(file.data).must_equal data
        expect(downloaded_calls).must_be_empty
      end

      it "passes verification when the sha256 matches" do
        file = Riffer::Messages::FilePart.new(media_type: "text/plain", data: data, sha256: sha256)
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:unsupported).resolve!([message])

        expect(file.data).must_equal data
      end

      it "raises Riffer::FileChecksumMismatchError when the sha256 doesn't match" do
        file = Riffer::Messages::FilePart.new(media_type: "text/plain", data: data,
                                              sha256: Digest::SHA256.hexdigest("something else"),)
        message = Riffer::Messages::User.new("hi", files: [file])

        expect { resolver_for(:unsupported).resolve!([message]) }.must_raise Riffer::FileChecksumMismatchError
      end
    end

    describe "a url-only source with a provider that doesn't support files" do
      it "raises Riffer::FileUnsupportedError" do
        file = Riffer::Messages::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])

        expect { resolver_for(:unsupported).resolve!([message]) }.must_raise Riffer::FileUnsupportedError
      end
    end

    describe "a url-only source with a provider that passes URLs through" do
      it "leaves the file untouched when no sha256 is given" do
        file = Riffer::Messages::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:url).resolve!([message])

        expect(file.data).must_be_nil
        expect(downloaded_calls).must_be_empty
      end

      it "downloads and verifies when a sha256 is given, without caching the bytes" do
        sha256 = Digest::SHA256.hexdigest(downloaded_content)
        file = Riffer::Messages::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf",
                                                                                   sha256: sha256,)
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:url).resolve!([message])

        expect(file.data).must_be_nil
        expect(downloaded_calls.size).must_equal 1
      end

      it "raises Riffer::FileChecksumMismatchError when the downloaded content doesn't match" do
        sha256 = Digest::SHA256.hexdigest("something else")
        file = Riffer::Messages::FilePart.from_url(
          "https://example.com/file.pdf", media_type: "application/pdf", sha256: sha256,
        )
        message = Riffer::Messages::User.new("hi", files: [file])

        expect { resolver_for(:url).resolve!([message]) }.must_raise Riffer::FileChecksumMismatchError
      end
    end

    describe "a url-only source with a provider that requires inline data" do
      it "downloads even without a sha256" do
        file = Riffer::Messages::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:data).resolve!([message])

        expect(file.data).must_equal Base64.strict_encode64(downloaded_content)
      end
    end

    describe "when downloads are disabled" do
      before { Riffer.config.files.allow_downloads = false }

      it "raises Riffer::FileDownloadsDisabledError instead of downloading" do
        file = Riffer::Messages::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])

        expect { resolver_for(:data).resolve!([message]) }.must_raise Riffer::FileDownloadsDisabledError
        expect(downloaded_calls).must_be_empty
      end
    end

    describe "when a message exceeds max_per_message" do
      before { Riffer.config.files.max_per_message = 1 }

      it "raises Riffer::TooManyFilesError" do
        files = [
          Riffer::Messages::FilePart.from_url("https://example.com/a.pdf", media_type: "application/pdf"),
          Riffer::Messages::FilePart.from_url("https://example.com/b.pdf", media_type: "application/pdf"),
        ]
        message = Riffer::Messages::User.new("hi", files: files)

        expect { resolver_for(:url).resolve!([message]) }.must_raise Riffer::TooManyFilesError
      end
    end

    describe "download concurrency" do
      let(:sleepy_downloader) do
        intervals = downloaded_calls
        mutex = Mutex.new
        lambda do |_url, max_bytes:, timeout:|
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          sleep 0.05
          finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          mutex.synchronize { intervals << [start, finish] }
          Base64.strict_encode64("content")
        end
      end

      let(:files) do
        [
          Riffer::Messages::FilePart.from_url("https://example.com/a.pdf", media_type: "application/pdf"),
          Riffer::Messages::FilePart.from_url("https://example.com/b.pdf", media_type: "application/pdf"),
        ]
      end

      before { Riffer.config.files.downloader = sleepy_downloader }

      it "overlaps downloads when configured with Riffer::Runner::Threaded" do
        Riffer.config.files.runner = Riffer::Runner::Threaded.new(max_concurrency: 3)
        message = Riffer::Messages::User.new("hi", files: files)
        resolver_for(:data).resolve!([message])

        a, b = downloaded_calls
        overlap = a[0] < b[1] && b[0] < a[1]

        expect(overlap).must_equal true
      end

      it "does not overlap downloads when configured with Riffer::Runner::Sequential (the default)" do
        Riffer.config.files.runner = Riffer::Runner::Sequential.new
        message = Riffer::Messages::User.new("hi", files: files)
        resolver_for(:data).resolve!([message])

        a, b = downloaded_calls

        expect(b[0] >= a[1]).must_equal true
      end
    end
  end
end
