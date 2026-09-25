# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Repository do
  describe ".find" do
    it "returns the OpenAI provider class for :openai symbol" do
      result = Riffer::Providers::Repository.find(:openai)

      expect(result).must_equal Riffer::Providers::OpenAI
    end

    it "returns the OpenAI provider class for 'openai' string" do
      result = Riffer::Providers::Repository.find("openai")

      expect(result).must_equal Riffer::Providers::OpenAI
    end

    it "returns the AmazonBedrock provider class for :amazon_bedrock symbol" do
      result = Riffer::Providers::Repository.find(:amazon_bedrock)

      expect(result).must_equal Riffer::Providers::AmazonBedrock
    end

    it "returns the AmazonBedrock provider class for 'amazon_bedrock' string" do
      result = Riffer::Providers::Repository.find("amazon_bedrock")

      expect(result).must_equal Riffer::Providers::AmazonBedrock
    end

    it "returns the OpenRouter provider class for :openrouter symbol" do
      expect(Riffer::Providers::Repository.find(:openrouter)).must_equal Riffer::Providers::OpenRouter
    end

    it "returns the OpenRouter provider class for 'openrouter' string" do
      expect(Riffer::Providers::Repository.find("openrouter")).must_equal Riffer::Providers::OpenRouter
    end

    it "returns the Mock provider class for :mock symbol" do
      expect(Riffer::Providers::Repository.find(:mock)).must_equal Riffer::Providers::Mock
    end

    it "returns the Mock provider class for 'mock' string" do
      expect(Riffer::Providers::Repository.find("mock")).must_equal Riffer::Providers::Mock
    end

    it "returns nil for unknown identifiers" do
      expect(Riffer::Providers::Repository.find(:missing)).must_be_nil
    end

    it "raises NoMethodError when identifier is nil" do
      expect { Riffer::Providers::Repository.find(nil) }.must_raise(NoMethodError)
    end
  end

  describe ".build" do
    after do
      %i[jane instance_jane openai].each { |id| Riffer::Providers::Repository.unregister(id) }
    end

    it "instantiates a class-returning factory" do
      provider = Riffer::Providers::Repository.build(:mock)

      expect(provider).must_be_instance_of Riffer::Providers::Mock
    end

    it "sets the identifier as the provider_key" do
      provider = Riffer::Providers::Repository.build(:mock)

      expect(provider.provider_key).must_equal :mock
    end

    it "works with a string identifier" do
      provider = Riffer::Providers::Repository.build("mock")

      expect(provider).must_be_instance_of Riffer::Providers::Mock
    end

    it "passes registration options to new" do
      client = Object.new
      Riffer::Providers::Repository.register(:instance_jane, client: client) { Riffer::Providers::OpenAI }

      provider = Riffer::Providers::Repository.build(:instance_jane)

      expect(provider.send(:client)).must_be_same_as client
    end

    it "sets the registered identifier as the provider_key" do
      Riffer::Providers::Repository.register(:instance_jane) { Riffer::Providers::Mock }

      expect(Riffer::Providers::Repository.build(:instance_jane).provider_key).must_equal :instance_jane
    end

    it "builds a new instance on every call" do
      first = Riffer::Providers::Repository.build(:mock)
      second = Riffer::Providers::Repository.build(:mock)

      expect(first).wont_be_same_as second
    end

    it "raises when a custom initialize does not accept key:" do
      custom = Class.new(Riffer::Providers::Base) do
        def initialize
          super
          @ready = true
        end
      end
      Riffer::Providers::Repository.register(:jane) { custom }

      expect { Riffer::Providers::Repository.build(:jane) }.must_raise ArgumentError
    end

    it "instantiates a class-returning custom registration" do
      custom = Class.new(Riffer::Providers::Base)
      Riffer::Providers::Repository.register(:jane) { custom }

      provider = Riffer::Providers::Repository.build(:jane)

      expect(provider).must_be_instance_of custom
    end

    it "returns nil for unknown identifiers" do
      expect(Riffer::Providers::Repository.build(:missing)).must_be_nil
    end

    it "prefers a registration over a built-in sharing the identifier" do
      custom = Class.new(Riffer::Providers::Base)
      Riffer::Providers::Repository.register(:openai) { custom }

      provider = Riffer::Providers::Repository.build(:openai)

      expect(provider).must_be_instance_of custom
    end
  end

  describe ".register" do
    after do
      %i[jane openai].each { |id| Riffer::Providers::Repository.unregister(id) }
    end

    it "rejects key: as an option" do
      expect do
        Riffer::Providers::Repository.register(:jane, key: :other) { Riffer::Providers::Mock }
      end.must_raise Riffer::ArgumentError
    end

    it "drops a registration's options on unregister" do
      Riffer::Providers::Repository.register(:mock, responses: [{ content: "custom" }]) { Riffer::Providers::Mock }
      Riffer::Providers::Repository.unregister(:mock)

      expect(Riffer::Providers::Repository.build(:mock).generate_text(prompt: "x").content).wont_equal "custom"
    end

    it "resolves a registered custom provider via find" do
      custom = Class.new(Riffer::Providers::Base)
      Riffer::Providers::Repository.register(:jane) { custom }

      expect(Riffer::Providers::Repository.find(:jane)).must_equal custom
    end

    it "resolves a registered custom provider from a string identifier" do
      custom = Class.new(Riffer::Providers::Base)
      Riffer::Providers::Repository.register(:jane) { custom }

      expect(Riffer::Providers::Repository.find("jane")).must_equal custom
    end

    it "takes precedence over a built-in sharing the identifier" do
      custom = Class.new(Riffer::Providers::Base)
      Riffer::Providers::Repository.register(:openai) { custom }

      expect(Riffer::Providers::Repository.find(:openai)).must_equal custom
    end

    it "replaces the previous factory when re-registering the same identifier" do
      first = Class.new(Riffer::Providers::Base)
      second = Class.new(Riffer::Providers::Base)
      Riffer::Providers::Repository.register(:jane) { first }
      Riffer::Providers::Repository.register(:jane) { second }

      expect(Riffer::Providers::Repository.find(:jane)).must_equal second
    end

    it "does not add custom registrations to the built-in REPO" do
      custom = Class.new(Riffer::Providers::Base)
      Riffer::Providers::Repository.register(:jane) { custom }

      expect(Riffer::Providers::Repository::REPO).wont_include(:jane)
    end
  end

  describe ".unregister" do
    it "removes a custom registration" do
      custom = Class.new(Riffer::Providers::Base)
      Riffer::Providers::Repository.register(:jane) { custom }
      Riffer::Providers::Repository.unregister(:jane)

      expect(Riffer::Providers::Repository.find(:jane)).must_be_nil
    end

    it "restores the built-in shadowed by a custom registration" do
      custom = Class.new(Riffer::Providers::Base)
      Riffer::Providers::Repository.register(:openai) { custom }
      Riffer::Providers::Repository.unregister(:openai)

      expect(Riffer::Providers::Repository.find(:openai)).must_equal Riffer::Providers::OpenAI
    end

    it "does not raise when the identifier is not registered" do
      expect(Riffer::Providers::Repository.unregister(:never_registered)).must_be_nil
    end
  end
end
