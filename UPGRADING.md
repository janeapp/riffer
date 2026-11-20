# Upgrading

Upgrade guides for breaking releases will appear here. See the [stability policy](https://riffer.ai/guides/stability/) for when breaking changes can happen. To try a breaking release's new behaviour early, turn on its [future flag](https://riffer.ai/guides/configuration/#future-flags).

## Unreleased

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
