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

  describe ".builtin_key_for" do
    after { Riffer::Providers::Repository.unregister(:bedrock_canada) }

    it "returns the built-in identifier for a built-in class" do
      expect(Riffer::Providers::Repository.builtin_key_for(Riffer::Providers::OpenAI)).must_equal :openai
    end

    it "distinguishes providers that share a wire format" do
      expect(Riffer::Providers::Repository.builtin_key_for(Riffer::Providers::AzureOpenAI)).must_equal :azure_openai
    end

    it "ignores custom registrations of a built-in class" do
      Riffer::Providers::Repository.register(:bedrock_canada) { Riffer::Providers::AmazonBedrock }

      expect(Riffer::Providers::Repository.builtin_key_for(Riffer::Providers::AmazonBedrock)).must_equal :amazon_bedrock
    end

    it "returns nil for a class outside the built-ins" do
      expect(Riffer::Providers::Repository.builtin_key_for(Class.new(Riffer::Providers::OpenAI))).must_be_nil
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

    it "stamps the built-in identifier as the registry_key" do
      provider = Riffer::Providers::Repository.build(:mock)

      expect(provider.registry_key).must_equal :mock
    end

    it "works with a string identifier" do
      provider = Riffer::Providers::Repository.build("mock")

      expect(provider).must_be_instance_of Riffer::Providers::Mock
    end

    it "returns the same instance an instance-returning factory produced" do
      instance = Riffer::Providers::Mock.new
      Riffer::Providers::Repository.register(:instance_jane) { instance }

      expect(Riffer::Providers::Repository.build(:instance_jane)).must_equal instance
    end

    it "stamps registry_key on an instance-returning factory's result" do
      instance = Riffer::Providers::Mock.new
      Riffer::Providers::Repository.register(:instance_jane) { instance }

      Riffer::Providers::Repository.build(:instance_jane)

      expect(instance.registry_key).must_equal :instance_jane
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
