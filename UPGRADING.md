# Upgrading

Each breaking release has an upgrade guide below. See the [stability policy](https://riffer.ai/guides/stability/) for when breaking changes can happen. To try a breaking release's new behaviour early, turn on its [future flag](https://riffer.ai/guides/configuration/#future-flags).

## Unreleased

### MCP client support is removed

Riffer no longer connects to MCP servers. 0.57.0 deprecated MCP client support, and this release removes it:

- `Riffer::Mcp` and everything under it, including `Riffer::Mcp.register`, `.unregister` and `.registrations`
- `Agent.use_mcp`, `Agent.mcp_configs` and `Agent::Config#mcp_configs`
- `config.mcp`, with its `credentials` and `discovery_runner` settings
- the `mcp_search` tool, and the `mcp_progressive_tools` and `discovered_tools` context keys

`mcp_progressive_tools` and `discovered_tools` are no longer reserved, so a `context:` hash can now pass them as ordinary keys. To find every call before you upgrade, run your suite on 0.57 with [deprecations raising](https://riffer.ai/guides/testing/#deprecations).

#### Calling an MCP server yourself

The [`mcp`](https://github.com/modelcontextprotocol/ruby-sdk) gem speaks the protocol, and ordinary riffer tools do the rest. Each part of the old client maps to a few lines of your own code:

| Before                                          | After                                                                                                                                                                                                |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Riffer::Mcp.register` listing a server's tools | `MCP::Client#tools`, once per process, with one [`Riffer::Tool`](https://riffer.ai/guides/tools/) built per server tool                                                                              |
| `config.mcp.credentials`                        | A client connected with the user's token, passed in `context`                                                                                                                                        |
| `use_mcp :tag`, with `mcp_search`               | [`deferred_tools`](https://riffer.ai/guides/agents/#deferred_tools-experimental) plus a search tool that returns [`load_tools`](https://riffer.ai/guides/tools/#loading-deferred-tools-experimental) |
| `use_mcp :tag, progressive: false`              | `uses_tools`                                                                                                                                                                                         |
| Tags                                            | One `McpServer` per server; give each agent the servers' tools it should have, e.g. `GITHUB_MCP.tools + JIRA_MCP.tools`                                                                              |

Start with a class whose instances each stand for one server. An instance lists the server's tools once and builds a tool class for each:

```ruby
# Gemfile: gem "mcp"
require "mcp"

class McpServer
  def initialize(name:, url:, service_token:)
    @name = name
    @url = url
    @service_token = service_token
  end

  def tools
    @tools ||= connect(@service_token) { |client| client.tools.map { |tool| build(tool) } }.freeze
  end

  def connect(token)
    transport = MCP::Client::HTTP.new(url: @url, headers: { "Authorization" => "Bearer #{token}" })
    client = MCP::Client.new(transport: transport)
    client.connect
    yield client
  ensure
    transport&.close
  end

  private

  def build(mcp_tool)
    key = @name
    tool_name = "#{@name}__#{mcp_tool.name.gsub(/[^a-zA-Z0-9_-]/, "_")}"

    Class.new(Riffer::Tool) do
      identifier tool_name
      description mcp_tool.description.to_s.empty? ? mcp_tool.name : mcp_tool.description
      define_singleton_method(:parameters_schema) { |strict: false| mcp_tool.input_schema }

      define_method(:call) do |context:, **arguments|
        result = context[key].call_tool(tool: mcp_tool, arguments: arguments).fetch("result")
        content = result["content"].filter_map { |item| item["text"] }.join

        result["isError"] ? error(content) : text(content)
      end
    end
  end
end

GITHUB_MCP = McpServer.new(name: :github, url: "https://api.githubcopilot.com/mcp/", service_token: ENV.fetch("GITHUB_TOKEN"))
```

The service token lists the tools once per process. The tools have no `params`, so the server's own schema goes to the provider and the server validates the arguments. A server tool without a description is described by its name, since riffer requires one. OpenAI, Azure OpenAI and OpenRouter send every tool in strict mode, which rejects a schema unless each object sets `additionalProperties: false` and lists every property as required, and most MCP schemas don't. On those providers, defer the tools with [`strategy: :gateway`](https://riffer.ai/guides/agents/#deferred-tools-strategy-experimental), which never sends their schemas as tools, or rewrite the schema in `parameters_schema`. The name prefix keeps tool names from different servers apart. A result with `isError` goes back to the model as a tool error. A JSON-RPC error raises `MCP::Client::ServerError` from `call_tool`, which riffer returns to the model as an `:unhandled_error`.

The tools call the server through a client in the agent's context, under the server's name. Connect once per request with the user's own token, in place of the `credentials` callback, and every tool call in the run reuses that session. The connection closes when the block returns:

```ruby
GITHUB_MCP.connect(user.github_token) do |github|
  ResearchAgent.new(context: { github: github }).generate(prompt)
end
```

A transport's headers are fixed when it's built, so each user needs their own client; don't share one between requests. The default tool runtime makes one call at a time; with a concurrent [tool runtime](https://riffer.ai/guides/advanced-tools/#tool-runtime), a turn's calls use the client concurrently.

To give an agent every tool up front, the way `progressive: false` did, list them with `uses_tools`:

```ruby
class ResearchAgent < Riffer::Agent
  model "anthropic/claude-sonnet-4-6"
  uses_tools ->(context) { GITHUB_MCP.tools }
end
```

To hold them back until the model asks, the way `mcp_search` did, defer them and give the agent a search tool that loads the ones it finds:

```ruby
class FindGithubTools < Riffer::Tool
  description "Find GitHub tools for a task. Describe what you need to do in a few words."
  params { required :query, :string }

  def call(context:, query:)
    words = query.downcase.split
    matches = context.deferred_tools.select do |tool|
      words.any? { |word| "#{tool.name} #{tool.description}".downcase.include?(word) }
    end
    load_tools(matches.first(5))
  end
end

class ResearchAgent < Riffer::Agent
  model "anthropic/claude-sonnet-4-6"
  instructions "For anything on GitHub, use find_github_tools to get the tools you need."

  uses_tools [FindGithubTools]
  deferred_tools ->(context) { context[:github] ? GITHUB_MCP.tools : [] }
end
```

An agent without a GitHub connection gets no GitHub tools, which is what a `credentials` callback returning `nil` did. A loaded tool stays loaded for the rest of the conversation, including after the agent is [serialized](https://riffer.ai/guides/serialization/) and restored. To run these tools in a restored agent, pass `from_json` a `tool_resolver:` that returns the real classes, such as `->(descriptor) { (GITHUB_MCP.tools + [FindGithubTools]).find { |tool| tool.name == descriptor[:name] } }`, and the connected client in `context:`. Anthropic, OpenAI and Azure OpenAI load deferred tools natively; on any other provider, pass [`strategy: :gateway`](https://riffer.ai/guides/agents/#deferred-tools-strategy-experimental). Deferred tools are experimental, so this part of the recipe can change in a minor release.

### File downloads move to the agent

This release adds the `config.future.file_downloads` [future flag](https://riffer.ai/guides/configuration/#future-flags). Apart from the deprecation warnings below, nothing changes until you turn it on; a later breaking release makes it the default and removes the old path. With it on, the agent downloads files before the first model call, file policy goes in guardrails, and riffer checks no file content. See [File Downloads](https://riffer.ai/guides/configuration/#file-downloads).

```ruby
Riffer.configure do |config|
  config.future.file_downloads = true
  config.files.allow_downloads = true
end
```

Turn the flag on before your agent classes load: registering an `:after_files_download` guardrail without it raises `Riffer::ArgumentError`.

Without the flag, each of these reports a deprecation. With the flag, do this instead:

| Before                                                          | With the flag                                                                                                                                                                                    |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `config.files.max_bytes`, `config.files.timeout`                | Ignored. The default downloader has no size cap and uses Net::HTTP's default timeouts; set your own limits in a [custom downloader](https://riffer.ai/guides/configuration/#custom-downloaders). |
| `config.files.max_per_message`, `Riffer::TooManyFilesError`     | Count files in a [`:before` guardrail](https://riffer.ai/guides/guardrails/#files).                                                                                                              |
| `config.files.runner`                                           | Ignored. Download in parallel inside a custom downloader.                                                                                                                                        |
| A downloader with `call(url, max_bytes:, timeout:)`             | `call(files)`: it gets the `FilePart`s that need bytes and returns their raw bytes in the same order.                                                                                            |
| Riffer verifying `sha256:`, `Riffer::FileChecksumMismatchError` | Check it in a custom downloader or an [`:after_files_download` guardrail](https://riffer.ai/guides/guardrails/#files).                                                                           |
| `Riffer::FileTooLargeError`                                     | Raise your own error from a custom downloader.                                                                                                                                                   |

A downloader before:

```ruby
config.files.downloader = ->(url, max_bytes:, timeout:) { MyStore.read(url) }
```

After:

```ruby
config.files.downloader = ->(files) { files.map { |file| MyStore.read(file.url) } }
```

Other changes with the flag:

- Providers never download. A direct `generate_text` or `stream_text` call with a file the provider sends as base64 or bytes and that has no data raises `Riffer::FileDataMissingError`. Pass `data:` or `bytes:`, or download with `Riffer.config.files.downloader.call(files)` yourself.
- The default downloader fetches http as well as https, and follows redirects between them.
- A `sha256:` no longer makes riffer download a file the provider takes as a URL.

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
