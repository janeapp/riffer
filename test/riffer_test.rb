# frozen_string_literal: true

require "test_helper"
require "tmpdir"

describe Riffer do
  describe ".version" do
    it "has a version number" do
      expect(Riffer.version).wont_be_nil
    end
  end

  describe ".config" do
    it "returns a Config instance" do
      expect(Riffer.config).must_be_instance_of Riffer::Config
    end

    it "returns the same instance on multiple calls" do
      config1 = Riffer.config
      config2 = Riffer.config

      expect(config1.object_id).must_equal config2.object_id
    end
  end

  describe ".configure" do
    it "yields the config object" do
      yielded = nil
      Riffer.configure do |config|
        yielded = config
      end

      expect(yielded).must_be_instance_of Riffer::Config
    end

    it "allows setting configuration" do
      original_api_key = Riffer.config.openai.api_key
      Riffer.configure do |config|
        config.openai.api_key = "new-test-key"
      end

      expect(Riffer.config.openai.api_key).must_equal "new-test-key"
      Riffer.config.openai.api_key = original_api_key
    end

    describe "catalog" do
      before { Riffer.instance_variable_set(:@config, Riffer::Config.new) }

      after do
        Riffer.instance_variable_set(:@config, Riffer::Config.new)
        FileUtils.remove_entry(@dir) if @dir
      end

      def write_catalog(models)
        @dir ||= Dir.mktmpdir
        path = File.join(@dir, "catalog-#{models.keys.first.tr('/', '_')}.json")
        File.write(path, JSON.generate({ version: 1, models: models }))
        path
      end

      it "fails during configure on a bad catalog file" do
        path = write_catalog({ "gpt-5.1" => {} })

        expect { Riffer.configure { |config| config.catalog_files = [path] } }.must_raise Riffer::ArgumentError
      end

      it "rebuilds the catalog from scratch on a second configure" do
        first = write_catalog({ "openai/gpt-5.1" => { "pricing" => { "input" => 1, "output" => 2 } } })
        second = write_catalog({ "openai/gpt-5.2" => { "pricing" => { "input" => 1, "output" => 2 } } })
        Riffer.configure { |config| config.catalog_files = [first] }
        Riffer.configure { |config| config.catalog_files = [second] }

        expect(Riffer.config.catalog.rates_for("openai/gpt-5.1")).must_be_nil
        expect(Riffer.config.catalog.rates_for("openai/gpt-5.2")).wont_be_nil
      end
    end
  end
end
