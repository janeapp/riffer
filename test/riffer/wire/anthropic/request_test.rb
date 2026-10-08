# frozen_string_literal: true

require "test_helper"

describe Riffer::Wire::Anthropic::Request do
  def build(messages = [Riffer::Messages::User.new("Hello")], **options)
    Riffer::Wire::Anthropic::Request.build(messages, options)
  end

  it "builds a body without a model" do
    expect(build).must_equal({ messages: [{ role: "user", content: "Hello" }], max_tokens: 4096 })
  end

  it "passes caller options through and honors max_tokens" do
    body = build(max_tokens: 100, temperature: 0.2)

    expect(body.slice(:max_tokens, :temperature)).must_equal({ max_tokens: 100, temperature: 0.2 })
  end

  it "moves system messages to the system field" do
    body = build([Riffer::Messages::System.new("Be brief"), Riffer::Messages::User.new("Hi")])

    expect(body[:system]).must_equal [{ type: "text", text: "Be brief" }]
    expect(body[:messages]).must_equal [{ role: "user", content: "Hi" }]
  end

  it "maps only the user_id tag to metadata" do
    body = build(tags: { "user_id" => "u_1", "team" => "growth" })

    expect(body[:metadata]).must_equal({ user_id: "u_1" })
    expect(body.key?(:tags)).must_equal false
  end

  it "converts tools, encoding namespaced names" do
    tool = stub_tool("Lookup") { description "Look things up" }
    tool.identifier("crm/lookup")

    expect(build(tools: [tool])[:tools].first.slice(:name, :description)).
      must_equal({ name: "crm__lookup", description: "Look things up" })
  end

  it "appends the web search server tool" do
    body = build(web_search: { max_uses: 2 })

    expect(body[:tools]).must_equal [{ type: "web_search_20250305", name: "web_search", max_uses: 2 }]
  end

  it "sets a strict json_schema output format for structured output" do
    params = Riffer::Params.new
    params.required(:answer, String)

    format = build(structured_output: Riffer::Agent::StructuredOutput.new(params))[:output_config][:format]

    expect(format[:type]).must_equal "json_schema"
    expect(format[:schema][:additionalProperties]).must_equal false
  end

  it "converts an assistant turn with replayable reasoning and tool calls" do
    assistant = Riffer::Messages::Assistant.new(
      "Checking",
      reasoning: [
        Riffer::Messages::Assistant::ReasoningPart.new(
          type: :text, text: "Think", signature: "sig", format: "anthropic-messages-v1",
        ),
        Riffer::Messages::Assistant::ReasoningPart.new(type: :text, text: "foreign", format: "mock-v1"),
      ],
      tool_calls: [Riffer::Messages::Assistant::ToolCall.new(call_id: "toolu_1", name: "crm/lookup", arguments: "")],
    )

    message = build([Riffer::Messages::User.new("Hi"), assistant])[:messages].last

    expect(message).must_equal(
      role: "assistant",
      content: [
        { type: "thinking", thinking: "Think", signature: "sig" },
        { type: "text", text: "Checking" },
        { type: "tool_use", id: "toolu_1", name: "crm__lookup", input: {} },
      ],
    )
  end

  it "sends a tool result as a user tool_result block" do
    tool = Riffer::Messages::Tool.new("15C", tool_call_id: "toolu_1", name: "get_weather")

    expect(build([Riffer::Messages::User.new("Hi"), tool])[:messages].last).must_equal(
      role: "user",
      content: [{ type: "tool_result", tool_use_id: "toolu_1", content: "15C" }],
    )
  end

  it "sends base64 files inline and URL files by reference" do
    files = [
      Riffer::Messages::User::FilePart.new(data: "aGk=", media_type: "image/png"),
      Riffer::Messages::User::FilePart.new(url: "https://example.com/a.pdf", media_type: "application/pdf"),
    ]

    content = build([Riffer::Messages::User.new("Look", files: files)])[:messages].first[:content]

    expect(content[1]).must_equal({ type: "image", source: { type: "base64", media_type: "image/png", data: "aGk=" } })
    expect(content[2]).must_equal({ type: "document", source: { type: "url", url: "https://example.com/a.pdf" } })
  end
end
