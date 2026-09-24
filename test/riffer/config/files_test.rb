# frozen_string_literal: true

require "test_helper"

describe Riffer::Config::Files do
  describe "#allow_downloads" do
    it "initializes allow_downloads to false" do
      files = Riffer::Config::Files.new

      expect(files.allow_downloads).must_equal false
    end

    it "coerces a 'true' string for allow_downloads" do
      files = Riffer::Config::Files.new
      files.allow_downloads = "true"

      expect(files.allow_downloads).must_equal true
    end

    it "coerces a 'false' string for allow_downloads" do
      files = Riffer::Config::Files.new
      files.allow_downloads = "false"

      expect(files.allow_downloads).must_equal false
    end

    it "raises for an unrecognized allow_downloads value" do
      files = Riffer::Config::Files.new

      expect { files.allow_downloads = "yes" }.must_raise Riffer::ArgumentError
    end
  end

  describe "#max_bytes" do
    it "initializes max_bytes to 3_500_000" do
      files = Riffer::Config::Files.new

      expect(files.max_bytes).must_equal 3_500_000
    end

    it "allows setting max_bytes to a positive integer" do
      files = Riffer::Config::Files.new
      files.max_bytes = 1_000

      expect(files.max_bytes).must_equal 1_000
    end

    it "raises for a zero max_bytes" do
      files = Riffer::Config::Files.new

      expect { files.max_bytes = 0 }.must_raise Riffer::ArgumentError
    end

    it "raises for a negative max_bytes" do
      files = Riffer::Config::Files.new

      expect { files.max_bytes = -1 }.must_raise Riffer::ArgumentError
    end

    it "raises for a non-integer max_bytes" do
      files = Riffer::Config::Files.new

      expect { files.max_bytes = "1000" }.must_raise Riffer::ArgumentError
    end
  end

  describe "#timeout" do
    it "initializes timeout to 60" do
      files = Riffer::Config::Files.new

      expect(files.timeout).must_equal 60
    end

    it "allows setting timeout to a positive integer" do
      files = Riffer::Config::Files.new
      files.timeout = 30

      expect(files.timeout).must_equal 30
    end

    it "raises for a zero timeout" do
      files = Riffer::Config::Files.new

      expect { files.timeout = 0 }.must_raise Riffer::ArgumentError
    end

    it "raises for a negative timeout" do
      files = Riffer::Config::Files.new

      expect { files.timeout = -1 }.must_raise Riffer::ArgumentError
    end

    it "raises for a non-integer timeout" do
      files = Riffer::Config::Files.new

      expect { files.timeout = "30" }.must_raise Riffer::ArgumentError
    end
  end

  describe "#max_per_message" do
    it "initializes max_per_message to nil" do
      files = Riffer::Config::Files.new

      expect(files.max_per_message).must_be_nil
    end

    it "allows setting max_per_message to a positive integer" do
      files = Riffer::Config::Files.new
      files.max_per_message = 2

      expect(files.max_per_message).must_equal 2
    end

    it "allows clearing max_per_message with nil" do
      files = Riffer::Config::Files.new
      files.max_per_message = 2
      files.max_per_message = nil

      expect(files.max_per_message).must_be_nil
    end

    it "raises for a zero max_per_message" do
      files = Riffer::Config::Files.new

      expect { files.max_per_message = 0 }.must_raise Riffer::ArgumentError
    end

    it "raises for a negative max_per_message" do
      files = Riffer::Config::Files.new

      expect { files.max_per_message = -1 }.must_raise Riffer::ArgumentError
    end

    it "raises for a non-integer max_per_message" do
      files = Riffer::Config::Files.new

      expect { files.max_per_message = "2" }.must_raise Riffer::ArgumentError
    end
  end

  describe "#runner" do
    it "initializes runner to a Sequential instance" do
      files = Riffer::Config::Files.new

      expect(files.runner).must_be_instance_of Riffer::Runner::Sequential
    end

    it "allows setting runner to a Riffer::Runner instance" do
      files = Riffer::Config::Files.new
      runner = Riffer::Runner::Sequential.new
      files.runner = runner

      expect(files.runner).must_be_same_as runner
    end

    it "raises for a runner that isn't a Riffer::Runner instance" do
      files = Riffer::Config::Files.new

      expect { files.runner = Object.new }.must_raise Riffer::ArgumentError
    end
  end

  describe "#downloader" do
    it "initializes downloader to a Downloader instance" do
      files = Riffer::Config::Files.new

      expect(files.downloader).must_be_instance_of Riffer::Files::Downloader
    end

    it "allows setting downloader to any object responding to #call" do
      files = Riffer::Config::Files.new
      downloader = ->(_url, max_bytes:, timeout:) { "" }
      files.downloader = downloader

      expect(files.downloader).must_be_same_as downloader
    end

    it "raises for a downloader that doesn't respond to #call" do
      files = Riffer::Config::Files.new

      expect { files.downloader = Object.new }.must_raise Riffer::ArgumentError
    end
  end
end
