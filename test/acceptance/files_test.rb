# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: files" do
  acceptance_providers.each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { acceptance_setting(provider_name, :model) }
      let(:cassette_prefix) { "files/#{provider_name}" }

      let(:image) do
        Riffer::Messages::User::FilePart.new(
          data: Base64.strict_encode64(acceptance_file("red_square.png")),
          media_type: "image/png",
        )
      end
      let(:document) do
        Riffer::Messages::User::FilePart.new(
          data: Base64.strict_encode64(acceptance_file("invoice.pdf")),
          media_type: "application/pdf",
          filename: "invoice.pdf",
        )
      end

      ACCEPTANCE_MODES.each do |mode|
        it "reads an image (#{mode})" do
          message = acceptance_cassette("#{cassette_prefix}/image_#{mode}") do
            call_provider(provider, mode, prompt: "What color is this square? One word.", model: model, files: [image])
          end

          expect(message.content).must_match(/red/i)
        end

        it "reads a PDF (#{mode})" do
          message = acceptance_cassette("#{cassette_prefix}/pdf_#{mode}") do
            call_provider(
              provider,
              mode,
              prompt: "What is the invoice number in this document?",
              model: model,
              files: [document],
            )
          end

          expect(message.content).must_include "INV-4821"
        end

        it "reads several files in one message (#{mode})" do
          message = acceptance_cassette("#{cassette_prefix}/several_#{mode}") do
            call_provider(
              provider,
              mode,
              prompt: "Give the color of the square and the invoice number, in one sentence.",
              model: model,
              files: [image, document],
            )
          end

          expect(message.content).must_match(/red/i)
          expect(message.content).must_include "INV-4821"
        end

        describe "from a URL" do
          before do
            Riffer.config.files.allow_downloads = true
            Riffer.config.files.downloader = ->(_url, **) { acceptance_file("red_square.png") }
          end

          after do
            Riffer.config.files.allow_downloads = false
            Riffer.config.files.downloader = Riffer::Files::Downloader.new
          end

          it "reads an image (#{mode})" do
            file = Riffer::Messages::User::FilePart.from_url("https://files.example.com/red_square.png")
            message = acceptance_cassette("#{cassette_prefix}/image_url_#{mode}") do
              call_provider(provider, mode, prompt: "What color is this square? One word.", model: model, files: [file])
            end

            expect(message.content).must_match(/red/i)
          end
        end

        it "reads a file passed to an Agent (#{mode})" do
          agent = Class.new(Riffer::Agent) { model acceptance_model_id(provider_name) }.new

          response = acceptance_cassette("#{cassette_prefix}/agent_#{mode}") do
            run_agent(agent, mode, "What is the invoice number in this document?", files: [document])
          end

          expect(response.content).must_include "INV-4821"
        end
      end
    end
  end
end
