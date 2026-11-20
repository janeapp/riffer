# Upgrading

Each breaking release has an upgrade guide below. See the [stability policy](https://riffer.ai/guides/stability/) for when breaking changes can happen. To try a breaking release's new behaviour early, turn on its [future flag](https://riffer.ai/guides/configuration/#future-flags).

## 0.58.0

### `config.pricing` is removed

`config.pricing` and `Riffer::Config::Pricing` are gone, and cost comes only from the [model catalog](https://riffer.ai/guides/catalog/). Calling `config.pricing` raises `NoMethodError`, and a model with no catalog pricing carries no cost (`token_usage.cost` is `nil`, and spans have no `riffer.cost`).

Move each rate into a catalog file and list it in `config.catalog_files`. Before:

```ruby
Riffer.configure do |config|
  config.pricing.set("anthropic/claude-sonnet-4-6", input: 3.0, output: 15.0, cache_read: 0.3, cache_write: 3.75)
  config.pricing.set(["openai/gpt-5.1", "azure_openai/my-gpt-prod"], input: 1.25, output: 10.0)
end
```

After:

```ruby
Riffer.configure do |config|
  config.catalog_files = ["config/riffer/models.json"]
end
```

```json
{
  "version": 1,
  "models": {
    "anthropic/claude-sonnet-4-6": {
      "pricing": { "input": 3.0, "output": 15.0, "cache_read": 0.3, "cache_write": 3.75 }
    },
    "openai/gpt-5.1": {
      "aliases": ["azure_openai/my-gpt-prod"],
      "pricing": { "input": 1.25, "output": 10.0 }
    }
  }
}
```

The rates and the cost formula are unchanged: prices per million tokens, with `cache_read` and `cache_write` optional. A `set` call with an array of ids becomes one entry, with the other ids listed under `aliases`. `Riffer.configure` loads the file at boot and raises `Riffer::ArgumentError` if it is missing or malformed. See [Model Catalog → Pricing](https://riffer.ai/guides/catalog/#pricing).

### MCP client support is removed

Riffer no longer connects to MCP servers. 0.57.0 deprecated MCP client support, and this release removes it:

- `Riffer::Mcp` and everything under it, including `Riffer::Mcp.register`, `.unregister` and `.registrations`
- `Agent.use_mcp`, `Agent.mcp_configs` and `Agent::Config#mcp_configs`
- `config.mcp`, with its `credentials` and `discovery_runner` settings
- the `mcp_search` tool, and the `mcp_progressive_tools` and `discovered_tools` context keys

`mcp_progressive_tools` and `discovered_tools` are no longer reserved, so a `context:` hash can now pass them as ordinary keys. To find every call before you upgrade, run your suite on 0.57 with [deprecations raising](https://riffer.ai/guides/testing/#deprecations).

To hold tools back from the model until it asks for them, the way progressive discovery did, use [deferred tools](https://riffer.ai/guides/agents/#deferred_tools-experimental).

To keep calling an MCP server, wrap the [`mcp`](https://github.com/modelcontextprotocol/ruby-sdk) gem in your own [`Riffer::Tool`](https://riffer.ai/guides/tools/) and list it with `uses_tools`. Headers you build from `context` take the place of the `config.mcp.credentials` callback:

```ruby
# Gemfile: gem "mcp"
require "mcp"

class CreateIssueTool < Riffer::Tool
  description "Creates a GitHub issue"

  params do
    required :title, :string, description: "The issue title"
    optional :body, :string, description: "The issue body"
  end

  def call(context:, title:, body: nil)
    transport = MCP::Client::HTTP.new(
      url: "https://mcp.github.com",
      headers: { "Authorization" => "Bearer #{context[:github_token]}" }
    )
    client = MCP::Client.new(transport: transport)
    result = client.call_tool(name: "create_issue", arguments: { title: title, body: body }.compact).fetch("result")
    content = result["content"].filter_map { |item| item["text"] }.join

    result["isError"] ? error(content) : text(content)
  end
end
```

A JSON-RPC error raises `MCP::Client::ServerError` from `call_tool`.
