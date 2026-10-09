# frozen_string_literal: true

require "test_helper"
require "tmpdir"

describe Riffer::Catalog do
  before { @dir = Dir.mktmpdir }
  after { FileUtils.remove_entry(@dir) }

  def write_file(name, data)
    path = File.join(@dir, name)
    File.write(path, data.is_a?(String) ? data : JSON.generate(data))
    path
  end

  def write_catalog(name, models, version: 1)
    write_file(name, { version: version, models: models })
  end

  def load_error(*paths)
    expect { Riffer::Catalog.load(paths) }.must_raise(Riffer::ArgumentError).message
  end

  let(:prices) { { "input" => 1, "output" => 2 } }

  describe ".load" do
    it "builds an empty catalog from no files" do
      expect(Riffer::Catalog.load([]).empty?).must_equal true
    end

    it "reads reasoning fragments with symbol keys" do
      fragment = { "thinking" => { "type" => "enabled", "budget_tokens" => 1024 } }
      path = write_catalog("a.json", { "anthropic/claude-haiku-4-5" => { "reasoning" => { "low" => fragment } } })
      options = Riffer::Catalog.load([path]).reasoning_options("anthropic/claude-haiku-4-5", :low)

      expect(options).must_equal({ thinking: { type: "enabled", budget_tokens: 1024 } })
    end

    it "returns nil for a level the entry does not define" do
      path = write_catalog("a.json", { "openai/gpt-5.1" => { "reasoning" => { "low" => { "reasoning" => "low" } } } })

      expect(Riffer::Catalog.load([path]).reasoning_options("openai/gpt-5.1", :high)).must_be_nil
    end

    it "reads pricing as rates" do
      path = write_catalog("a.json", { "openai/gpt-5.1" => { "pricing" => { "input" => 1.25, "output" => 10 } } })
      rates = Riffer::Catalog.load([path]).rates_for("openai/gpt-5.1")

      expect([rates.input, rates.output]).must_equal [1.25, 10.0]
    end

    it "returns nil for an unknown model" do
      catalog = Riffer::Catalog.load([write_catalog("a.json", { "openai/gpt-5.1" => { "pricing" => prices } })])

      expect(catalog.rates_for("openai/gpt-7")).must_be_nil
      expect(catalog.reasoning_options("openai/gpt-7", :low)).must_be_nil
    end

    it "is frozen all the way down" do
      path = write_catalog("a.json", { "openai/gpt-5.1" => { "reasoning" => { "low" => { "reasoning" => "low" } } } })
      catalog = Riffer::Catalog.load([path])

      expect(catalog.frozen?).must_equal true
      expect(catalog.reasoning_options("openai/gpt-5.1", :low).frozen?).must_equal true
    end
  end

  describe "aliases" do
    it "resolves an alias to its entry" do
      entry = { "aliases" => ["openai/gpt-5.1-2025-11-13"], "pricing" => prices }
      catalog = Riffer::Catalog.load([write_catalog("a.json", { "openai/gpt-5.1" => entry })])

      expect(catalog.rates_for("openai/gpt-5.1-2025-11-13").input).must_equal 1.0
    end

    it "resolves an alias across providers" do
      entry = { "aliases" => ["azure_openai/my-gpt-prod"], "reasoning" => { "low" => { "reasoning" => "low" } } }
      catalog = Riffer::Catalog.load([write_catalog("a.json", { "openai/gpt-5.1" => entry })])

      expect(catalog.reasoning_options("azure_openai/my-gpt-prod", :low)).must_equal({ reasoning: "low" })
    end

    it "raises when two entries in one file list the same alias" do
      models = {
        "openai/gpt-5.1" => { "aliases" => ["openai/prod"] },
        "openai/gpt-5.2" => { "aliases" => ["openai/prod"] },
      }
      path = write_catalog("a.json", models)

      expect(load_error(path)).
        must_equal "#{path}: alias \"openai/prod\" is listed by both \"openai/gpt-5.1\" and \"openai/gpt-5.2\""
    end

    it "raises when an alias is also a model key" do
      models = {
        "openai/gpt-5.1" => { "aliases" => ["openai/gpt-5.2"] },
        "openai/gpt-5.2" => {},
      }
      path = write_catalog("a.json", models)

      expect(load_error(path)).must_equal 'catalog alias "openai/gpt-5.2" on "openai/gpt-5.1" is also a model key'
    end
  end

  describe "layering" do
    it "replaces a whole section and keeps the others" do
      base_entry = {
        "pricing" => { "input" => 3, "output" => 15, "cache_read" => 0.3 },
        "reasoning" => { "low" => { "output_config" => { "effort" => "low" } } },
      }
      base = write_catalog("base.json", { "anthropic/claude-sonnet-4-6" => base_entry })
      override_entry = { "pricing" => { "input" => 2.4, "output" => 12 } }
      override = write_catalog("override.json", { "anthropic/claude-sonnet-4-6" => override_entry })
      catalog = Riffer::Catalog.load([base, override])
      rates = catalog.rates_for("anthropic/claude-sonnet-4-6")
      options = catalog.reasoning_options("anthropic/claude-sonnet-4-6", :low)

      expect([rates.input, rates.cache_read]).must_equal [2.4, nil]
      expect(options).must_equal({ output_config: { effort: "low" } })
    end

    it "combines alias arrays across files" do
      base_entry = { "aliases" => ["openai/gpt-5.1-2025-11-13"], "pricing" => prices }
      base = write_catalog("base.json", { "openai/gpt-5.1" => base_entry })
      override = write_catalog("override.json", { "openai/gpt-5.1" => { "aliases" => ["azure_openai/my-gpt-prod"] } })
      catalog = Riffer::Catalog.load([base, override])

      expect(catalog.rates_for("openai/gpt-5.1-2025-11-13")).wont_be_nil
      expect(catalog.rates_for("azure_openai/my-gpt-prod")).wont_be_nil
    end

    it "lets a later file win an alias an earlier file claimed" do
      base = write_catalog("base.json", { "openai/gpt-5.1" => { "aliases" => ["openai/prod"], "pricing" => prices } })
      override_entry = { "aliases" => ["openai/prod"], "pricing" => { "input" => 5, "output" => 6 } }
      override = write_catalog("override.json", { "openai/gpt-5.2" => override_entry })

      expect(Riffer::Catalog.load([base, override]).rates_for("openai/prod").input).must_equal 5.0
    end
  end

  describe "validation" do
    it "raises on a missing file" do
      path = File.join(@dir, "missing.json")

      expect(load_error(path)).must_match(/\A#{Regexp.escape(path)}: cannot load catalog file/)
    end

    it "raises on invalid JSON" do
      path = write_file("bad.json", "{")

      expect(load_error(path)).must_match(/\A#{Regexp.escape(path)}: cannot load catalog file/)
    end

    it "raises when the file is not an object" do
      path = write_file("array.json", "[]")

      expect(load_error(path)).must_equal "#{path}: must be a JSON object"
    end

    it "raises on a missing version" do
      path = write_file("noversion.json", { models: {} })

      expect(load_error(path)).must_equal "#{path}: unsupported version nil; supported: [1]"
    end

    it "raises on an unsupported version" do
      path = write_catalog("a.json", {}, version: 2)

      expect(load_error(path)).must_equal "#{path}: unsupported version 2; supported: [1]"
    end

    it "raises on unknown top-level keys" do
      path = write_file("extra.json", { version: 1, models: {}, families: {} })

      expect(load_error(path)).must_equal "#{path}: unknown keys [\"families\"]; allowed: [\"version\", \"models\"]"
    end

    it "raises when models is not an object" do
      path = write_file("models.json", { version: 1, models: [] })

      expect(load_error(path)).must_equal "#{path}: models must be an object"
    end

    it "raises when models is null" do
      path = write_file("null_models.json", { version: 1, models: nil })

      expect(load_error(path)).must_equal "#{path}: models must be an object"
    end

    it "raises on a model key without a provider" do
      path = write_catalog("a.json", { "gpt-5.1" => {} })

      expect(load_error(path)).must_equal "#{path}: model key must be in \"provider/model\" form, got \"gpt-5.1\""
    end

    it "raises when an entry is not an object" do
      path = write_catalog("a.json", { "openai/gpt-5.1" => [] })

      expect(load_error(path)).must_equal "#{path}: openai/gpt-5.1: entry must be an object"
    end

    it "raises on unknown entry keys" do
      path = write_catalog("a.json", { "openai/gpt-5.1" => { "family" => "gpt" } })

      expect(load_error(path)).must_match(%r{openai/gpt-5.1: unknown keys \["family"\]; allowed: \["aliases", })
    end

    it "raises when aliases is not an array" do
      path = write_catalog("a.json", { "openai/gpt-5.1" => { "aliases" => "openai/prod" } })

      expect(load_error(path)).must_equal "#{path}: openai/gpt-5.1: aliases must be an array of strings"
    end

    it "raises on a malformed alias" do
      path = write_catalog("a.json", { "openai/gpt-5.1" => { "aliases" => ["prod"] } })

      expect(load_error(path)).
        must_equal "#{path}: openai/gpt-5.1: alias must be in \"provider/model\" form, got \"prod\""
    end

    it "raises when pricing is missing output" do
      path = write_catalog("a.json", { "openai/gpt-5.1" => { "pricing" => { "input" => 1 } } })

      expect(load_error(path)).must_equal "#{path}: openai/gpt-5.1: pricing is missing [\"output\"]"
    end

    it "raises on a negative price" do
      path = write_catalog("a.json", { "openai/gpt-5.1" => { "pricing" => { "input" => -1, "output" => 2 } } })

      expect(load_error(path)).
        must_equal "#{path}: openai/gpt-5.1: pricing input rate must be a non-negative number, got -1"
    end

    it "raises on unknown pricing keys" do
      path = write_catalog("a.json", { "openai/gpt-5.1" => { "pricing" => prices.merge("batch" => 1) } })

      expect(load_error(path)).must_match(%r{openai/gpt-5.1: unknown pricing keys \["batch"\]})
    end

    it "raises on an unknown reasoning level" do
      path = write_catalog("a.json", { "openai/gpt-5.1" => { "reasoning" => { "minimal" => {} } } })

      expect(load_error(path)).must_match(%r{openai/gpt-5.1: unknown reasoning level "minimal"})
    end

    it "raises when a reasoning level is not an object" do
      path = write_catalog("a.json", { "openai/gpt-5.1" => { "reasoning" => { "low" => "low" } } })

      expect(load_error(path)).must_equal "#{path}: openai/gpt-5.1: reasoning low must be an object"
    end
  end
end
