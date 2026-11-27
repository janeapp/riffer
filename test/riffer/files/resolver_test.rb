# frozen_string_literal: true

require "test_helper"

describe Riffer::Files::Resolver do
  let(:downloaded_calls) { [] }
  let(:downloaded_content) { "downloaded content" }
  let(:fake_downloader) do
    calls = downloaded_calls
    content = downloaded_content
    lambda do |file, max_bytes:, timeout:|
      calls << { file: file, max_bytes: max_bytes, timeout: timeout }
      content
    end
  end

  # Counts riffer's own hashing; the fake downloaders here never hash.
  def count_sha256_digests
    count = 0
    original = Digest::SHA256.method(:hexdigest)
    Digest::SHA256.define_singleton_method(:hexdigest) do |*args|
      count += 1
      original.call(*args)
    end
    yield
    count
  ensure
    Digest::SHA256.singleton_class.send(:remove_method, :hexdigest)
  end

  before do
    @original_allow_downloads = Riffer.config.files.allow_downloads
    @original_max_per_message = Riffer.config.files.max_per_message
    @original_downloader = Riffer.config.files.downloader
    @original_runner = Riffer.config.files.runner
    @original_max_bytes = Riffer.config.files.max_bytes
    @original_timeout = Riffer.config.files.timeout
    Riffer.config.files.allow_downloads = true
    Riffer.config.files.downloader = fake_downloader
    Riffer.config.future.file_downloads = true
  end

  after do
    Riffer.config.files.allow_downloads = @original_allow_downloads
    Riffer.config.files.max_per_message = @original_max_per_message
    Riffer.config.files.downloader = @original_downloader
    Riffer.config.files.runner = @original_runner
    Riffer.config.files.max_bytes = @original_max_bytes
    Riffer.config.files.timeout = @original_timeout
    Riffer.config.future.file_downloads = false
  end

  def checked_url_file(sha256: Digest::SHA256.hexdigest(downloaded_content))
    Riffer::Messages::User::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf",
                                                                              sha256: sha256,)
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
        file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", data: data)
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:base64).resolve!([message])

        expect(file.data).must_equal data
        expect(downloaded_calls).must_be_empty
      end

      it "passes verification when the sha256 matches" do
        file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", data: data, sha256: sha256)
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:base64).resolve!([message])

        expect(file.data).must_equal data
      end

      it "raises Riffer::FileChecksumMismatchError when the sha256 doesn't match" do
        file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", data: data,
                                                    sha256: Digest::SHA256.hexdigest("something else"),)
        message = Riffer::Messages::User.new("hi", files: [file])

        expect { resolver_for(:base64).resolve!([message]) }.must_raise Riffer::FileChecksumMismatchError
      end

      it "raises Riffer::FileUnsupportedError when the provider doesn't accept files, even with data inline" do
        file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", data: data)
        message = Riffer::Messages::User.new("hi", files: [file])

        expect { resolver_for(:unsupported).resolve!([message]) }.must_raise Riffer::FileUnsupportedError
      end

      it "rejects data with smuggled content past a padding boundary instead of verifying a truncated prefix" do
        smuggled = Base64.strict_encode64(body) + Base64.strict_encode64("smuggled payload")
        file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", data: smuggled, sha256: sha256)
        message = Riffer::Messages::User.new("hi", files: [file])

        expect { resolver_for(:base64).resolve!([message]) }.must_raise Riffer::FileEncodingError
      end
    end

    describe "a raw bytes source" do
      let(:body) { "inline body" }
      let(:sha256) { Digest::SHA256.hexdigest(body) }

      %i[url base64 bytes].each do |delivery|
        it "never downloads with a #{delivery} provider, even when downloads are disabled" do
          Riffer.config.files.allow_downloads = false
          file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", bytes: body, sha256: sha256)
          message = Riffer::Messages::User.new("hi", files: [file])
          resolver_for(delivery).resolve!([message])

          expect(downloaded_calls).must_be_empty
          expect(file.data_bytes).must_be_same_as body
          expect(file.instance_variable_get(:@encoded_bytes)).must_be_nil
        end
      end

      it "resolves without encoding the bytes when no sha256 is given" do
        file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", bytes: body)
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:base64).resolve!([message])

        expect(file.instance_variable_get(:@encoded_bytes)).must_be_nil
      end

      it "verifies the bytes instead of downloading the url when both are given" do
        file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", bytes: body,
                                                    url: "https://example.com/a.txt", sha256: sha256,)
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:url).resolve!([message])

        expect(downloaded_calls).must_be_empty
      end

      it "raises Riffer::FileChecksumMismatchError when the sha256 doesn't match" do
        file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", bytes: body,
                                                    sha256: Digest::SHA256.hexdigest("something else"),)
        message = Riffer::Messages::User.new("hi", files: [file])

        expect { resolver_for(:bytes).resolve!([message]) }.must_raise Riffer::FileChecksumMismatchError
      end
    end

    describe "a url-only source with a provider that doesn't support files" do
      it "raises Riffer::FileUnsupportedError" do
        file = Riffer::Messages::User::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])

        expect { resolver_for(:unsupported).resolve!([message]) }.must_raise Riffer::FileUnsupportedError
      end
    end

    describe "a url-only source with a provider returning an unrecognized file_delivery value" do
      it "raises Riffer::ArgumentError" do
        file = Riffer::Messages::User::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])

        expect { resolver_for(:something_else).resolve!([message]) }.must_raise Riffer::ArgumentError
      end
    end

    describe "a url-only source with a provider that passes URLs through" do
      it "leaves the file untouched when no sha256 is given" do
        file = Riffer::Messages::User::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:url).resolve!([message])

        expect(file.data).must_be_nil
        expect(downloaded_calls).must_be_empty
      end

      it "passes the URL through unchecked when a sha256 is given, even with downloads disabled" do
        Riffer.config.files.allow_downloads = false
        file = checked_url_file
        message = Riffer::Messages::User.new("hi", files: [file])
        digests = count_sha256_digests { resolver_for(:url).resolve!([message]) }

        expect(downloaded_calls).must_be_empty
        expect(digests).must_equal 0
        expect(file.verified?).must_equal false
      end

      describe "before config.future.file_downloads" do
        before do
          Riffer.config.future.file_downloads = false
          Riffer.config.files.downloader = Riffer::Files::Downloader.new
          stub_request(:get, "https://example.com/file.pdf").to_return(status: 200, body: downloaded_content)
        end

        it "reports the :url_sha256_check deprecation" do
          message = Riffer::Messages::User.new("hi", files: [checked_url_file])
          error = expect { resolver_for(:url).resolve!([message]) }.must_raise Riffer::DeprecationError

          expect(error.message).must_include "[url_sha256_check]"
        end

        it "downloads and verifies without caching the bytes" do
          file = checked_url_file
          allow_deprecations { resolver_for(:url).resolve!([Riffer::Messages::User.new("hi", files: [file])]) }

          expect(file.verified?).must_equal true
          expect(file.data).must_be_nil
          expect(file.instance_variable_get(:@data_bytes)).must_be_nil
        end

        it "raises Riffer::FileChecksumMismatchError when the downloaded content doesn't match" do
          message = Riffer::Messages::User.new("hi", files: [checked_url_file(sha256: Digest::SHA256.hexdigest("other"))])

          expect do
            allow_deprecations { resolver_for(:url).resolve!([message]) }
          end.must_raise Riffer::FileChecksumMismatchError
        end

        it "downloads once across two resolves" do
          message = Riffer::Messages::User.new("hi", files: [checked_url_file])
          allow_deprecations { 2.times { resolver_for(:url).resolve!([message]) } }

          assert_requested :get, "https://example.com/file.pdf", times: 1
        end

        it "skips the download once an earlier :base64 resolution verified the file" do
          message = Riffer::Messages::User.new("hi", files: [checked_url_file])
          resolver_for(:base64).resolve!([message])
          resolver_for(:url).resolve!([message])

          assert_requested :get, "https://example.com/file.pdf", times: 1
        end
      end
    end

    describe "a url-only source with a provider that requires base64 data" do
      it "downloads and caches base64 even without a sha256" do
        file = Riffer::Messages::User::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:base64).resolve!([message])

        expect(file.data).must_equal Base64.strict_encode64(downloaded_content)
      end

      it "never caches raw bytes, since a base64-only provider has no use for them" do
        file = Riffer::Messages::User::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:base64).resolve!([message])

        expect(file.instance_variable_get(:@data_bytes)).must_be_nil
      end
    end

    describe "a url-only source with a provider that requires raw bytes (e.g. Bedrock)" do
      it "downloads and caches raw bytes even without a sha256" do
        file = Riffer::Messages::User::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:bytes).resolve!([message])

        expect(file.data_bytes).must_equal downloaded_content
      end

      it "never caches base64, closing the gap where downloading for Bedrock still encoded a copy nothing reads" do
        file = Riffer::Messages::User::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:bytes).resolve!([message])

        expect(file.data).must_be_nil
      end

      it "caches raw bytes from the sha256 check without decoding data again" do
        sha256 = Digest::SHA256.hexdigest(downloaded_content)
        file = Riffer::Messages::User::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf",
                                                                                         sha256: sha256,)
        message = Riffer::Messages::User.new("hi", files: [file])
        resolver_for(:bytes).resolve!([message])

        # Identity, not equality: proves the bytes were cached, not decoded again.
        expect(file.data_bytes).must_be_same_as downloaded_content
      end
    end

    describe "when downloads are disabled" do
      before { Riffer.config.files.allow_downloads = false }

      it "raises Riffer::FileDownloadsDisabledError instead of downloading" do
        file = Riffer::Messages::User::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])

        expect { resolver_for(:base64).resolve!([message]) }.must_raise Riffer::FileDownloadsDisabledError
        expect(downloaded_calls).must_be_empty
      end
    end

    describe "when a message exceeds max_per_message" do
      before { Riffer.config.files.max_per_message = 1 }

      it "raises Riffer::TooManyFilesError" do
        files = [
          Riffer::Messages::User::FilePart.from_url("https://example.com/a.pdf", media_type: "application/pdf"),
          Riffer::Messages::User::FilePart.from_url("https://example.com/b.pdf", media_type: "application/pdf"),
        ]
        message = Riffer::Messages::User.new("hi", files: files)

        expect { resolver_for(:url).resolve!([message]) }.must_raise Riffer::TooManyFilesError
      end
    end

    describe "resolving the same file again under a different provider" do
      it "still raises Riffer::FileUnsupportedError even after an earlier :base64 resolution cached data" do
        file = Riffer::Messages::User::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])

        resolver_for(:base64).resolve!([message])

        expect(file.data).wont_be_nil

        expect { resolver_for(:unsupported).resolve!([message]) }.must_raise Riffer::FileUnsupportedError
      end

      it "still raises Riffer::FileUnsupportedError even after an earlier :bytes resolution cached data" do
        file = Riffer::Messages::User::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        message = Riffer::Messages::User.new("hi", files: [file])

        resolver_for(:bytes).resolve!([message])

        expect(file.data_bytes).wont_be_nil

        expect { resolver_for(:unsupported).resolve!([message]) }.must_raise Riffer::FileUnsupportedError
      end

      it "downloads for :bytes after a :url resolution passed the URL through" do
        file = checked_url_file
        message = Riffer::Messages::User.new("hi", files: [file])

        resolver_for(:url).resolve!([message])
        resolver_for(:bytes).resolve!([message])

        expect(downloaded_calls.size).must_equal 1
        expect(file.data_bytes).must_equal downloaded_content
      end
    end

    describe "the downloader" do
      let(:file) { checked_url_file }

      it "receives the FilePart with the configured max_bytes and timeout" do
        Riffer.config.files.max_bytes = 1_234
        Riffer.config.files.timeout = 7
        resolver_for(:bytes).resolve!([Riffer::Messages::User.new("hi", files: [file])])

        expect(downloaded_calls).must_equal [{ file: file, max_bytes: 1_234, timeout: 7 }]
      end

      it "propagates the downloader's own exception class unwrapped" do
        host_error = Class.new(StandardError)
        Riffer.config.files.downloader = ->(_file, **) { raise host_error, "denied" }
        message = Riffer::Messages::User.new("hi", files: [file])

        error = expect { resolver_for(:bytes).resolve!([message]) }.must_raise host_error

        expect(error.message).must_equal "denied"
      end

      it "leaves the file unverified when the downloader raises" do
        Riffer.config.files.downloader = ->(_file, **) { raise Riffer::FileChecksumMismatchError, "File checksum mismatch" }
        message = Riffer::Messages::User.new("hi", files: [file])

        expect { resolver_for(:bytes).resolve!([message]) }.must_raise Riffer::FileChecksumMismatchError
        expect(file.verified?).must_equal false
      end

      it "is not reported as deprecated when it's the built-in one and the future flag is off" do
        Riffer.config.future.file_downloads = false
        Riffer.config.files.downloader = Riffer::Files::Downloader.new
        stub_request(:get, file.url).to_return(status: 200, body: downloaded_content)
        resolver_for(:bytes).resolve!([Riffer::Messages::User.new("hi", files: [file])])

        expect(file.data_bytes).must_equal downloaded_content
      end
    end

    describe "a url-only downloader, before config.future.file_downloads" do
      let(:url_downloader) do
        calls = downloaded_calls
        content = downloaded_content
        lambda do |url, max_bytes:, timeout:|
          calls << { url: url, max_bytes: max_bytes, timeout: timeout }
          content
        end
      end

      before do
        Riffer.config.future.file_downloads = false
        Riffer.config.files.downloader = url_downloader
      end

      it "reports the :url_downloader deprecation" do
        message = Riffer::Messages::User.new("hi", files: [checked_url_file])
        error = expect { resolver_for(:bytes).resolve!([message]) }.must_raise Riffer::DeprecationError

        expect(error.message).must_include "[url_downloader]"
      end

      it "is still called with the URL, and riffer checks the sha256" do
        file = checked_url_file
        message = Riffer::Messages::User.new("hi", files: [file])
        allow_deprecations { resolver_for(:bytes).resolve!([message]) }

        expect(downloaded_calls.map { |call| call[:url] }).must_equal ["https://example.com/file.pdf"]
        expect(file.verified?).must_equal true
      end

      it "raises Riffer::FileChecksumMismatchError when the downloaded content doesn't match" do
        message = Riffer::Messages::User.new("hi", files: [checked_url_file(sha256: Digest::SHA256.hexdigest("other"))])

        expect do
          allow_deprecations { resolver_for(:url).resolve!([message]) }
        end.must_raise Riffer::FileChecksumMismatchError
      end

      it "downloads and hashes once across two resolves with :url delivery" do
        message = Riffer::Messages::User.new("hi", files: [checked_url_file])
        digests = count_sha256_digests do
          allow_deprecations { 2.times { resolver_for(:url).resolve!([message]) } }
        end

        expect(downloaded_calls.size).must_equal 1
        expect(digests).must_equal 1
      end
    end

    describe "resolving the same messages on a second agent step" do
      %i[base64 bytes].each do |delivery|
        it "downloads once with #{delivery} delivery and never hashes the downloaded content" do
          file = checked_url_file
          message = Riffer::Messages::User.new("hi", files: [file])
          digests = count_sha256_digests { 2.times { resolver_for(delivery).resolve!([message]) } }

          expect(downloaded_calls.size).must_equal 1
          expect(digests).must_equal 0
        end
      end

      %i[url base64 bytes].each do |delivery|
        it "hashes data: content once with #{delivery} delivery" do
          body = "inline body"
          file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", data: Base64.strict_encode64(body),
                                                      sha256: Digest::SHA256.hexdigest(body),)
          message = Riffer::Messages::User.new("hi", files: [file])
          digests = count_sha256_digests { 2.times { resolver_for(delivery).resolve!([message]) } }

          expect(digests).must_equal 1
        end

        it "hashes bytes: content once with #{delivery} delivery" do
          body = "inline body"
          file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", bytes: body,
                                                      sha256: Digest::SHA256.hexdigest(body),)
          message = Riffer::Messages::User.new("hi", files: [file])
          digests = count_sha256_digests { 2.times { resolver_for(delivery).resolve!([message]) } }

          expect(digests).must_equal 1
        end
      end

      it "keeps no decoded copy of data: content when the provider sends base64" do
        body = "inline body"
        file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", data: Base64.strict_encode64(body),
                                                    sha256: Digest::SHA256.hexdigest(body),)
        resolver_for(:base64).resolve!([Riffer::Messages::User.new("hi", files: [file])])

        expect(file.verified?).must_equal true
        expect(file.instance_variable_get(:@data_bytes)).must_be_nil
      end

      it "keeps the decoded copy of data: content when the provider sends bytes" do
        body = "inline body"
        file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", data: Base64.strict_encode64(body),
                                                    sha256: Digest::SHA256.hexdigest(body),)
        resolver_for(:bytes).resolve!([Riffer::Messages::User.new("hi", files: [file])])

        expect(file.instance_variable_get(:@data_bytes)).must_equal body
      end

      it "still raises for inline data with a wrong sha256 on every resolve" do
        file = Riffer::Messages::User::FilePart.new(media_type: "text/plain", bytes: "inline body",
                                                    sha256: Digest::SHA256.hexdigest("something else"),)
        message = Riffer::Messages::User.new("hi", files: [file])

        2.times { expect { resolver_for(:bytes).resolve!([message]) }.must_raise Riffer::FileChecksumMismatchError }
      end
    end

    describe "a FilePart attached more than once" do
      it "is downloaded once" do
        file = Riffer::Messages::User::FilePart.from_url("https://example.com/file.pdf", media_type: "application/pdf")
        messages = [
          Riffer::Messages::User.new("hi", files: [file, file]),
          Riffer::Messages::User.new("again", files: [file]),
        ]
        Riffer.config.files.runner = Riffer::Runner::Threaded.new(max_concurrency: 3)
        resolver_for(:bytes).resolve!(messages)

        expect(downloaded_calls.size).must_equal 1
      end
    end

    describe "a deprecation reported while a concurrent runner resolves files" do
      it "names the line that called resolve!" do
        Riffer.config.future.file_downloads = false
        Riffer.config.files.downloader = ->(_url, **) { downloaded_content }
        Riffer.config.files.runner = Riffer::Runner::Threaded.new(max_concurrency: 3)
        message = Riffer::Messages::User.new("hi", files: [checked_url_file])

        error = expect { resolver_for(:bytes).resolve!([message]) }.must_raise Riffer::DeprecationError

        expect(error.message).must_include "#{__FILE__}:#{__LINE__ - 2}"
      end
    end

    describe "download concurrency" do
      let(:sleepy_downloader) do
        intervals = downloaded_calls
        mutex = Mutex.new
        lambda do |_file, max_bytes:, timeout:|
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          sleep 0.05
          finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          mutex.synchronize { intervals << [start, finish] }
          "content"
        end
      end

      let(:files) do
        [
          Riffer::Messages::User::FilePart.from_url("https://example.com/a.pdf", media_type: "application/pdf"),
          Riffer::Messages::User::FilePart.from_url("https://example.com/b.pdf", media_type: "application/pdf"),
        ]
      end

      before { Riffer.config.files.downloader = sleepy_downloader }

      it "overlaps downloads when configured with Riffer::Runner::Threaded" do
        Riffer.config.files.runner = Riffer::Runner::Threaded.new(max_concurrency: 3)
        message = Riffer::Messages::User.new("hi", files: files)
        resolver_for(:base64).resolve!([message])

        a, b = downloaded_calls
        overlap = a[0] < b[1] && b[0] < a[1]

        expect(overlap).must_equal true
      end

      it "does not overlap downloads when configured with Riffer::Runner::Sequential (the default)" do
        Riffer.config.files.runner = Riffer::Runner::Sequential.new
        message = Riffer::Messages::User.new("hi", files: files)
        resolver_for(:base64).resolve!([message])

        a, b = downloaded_calls

        expect(b[0] >= a[1]).must_equal true
      end
    end
  end
end
