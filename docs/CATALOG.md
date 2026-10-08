# Model Catalog

The model catalog holds per-model data that riffer can't derive from the model name: how a [`reasoning`](AGENTS.md#reasoning) level maps to request params, and what the model costs. It lives in JSON files you list in your configuration, so a new model or a price change is a data edit, not a riffer release.

Riffer ships no catalog. Without one:

- `reasoning` still works through each provider's default mapping (see [Provider defaults](#provider-defaults)).
- Calls carry no cost (`token_usage.cost` is `nil`).

## Loading catalog files

```ruby
Riffer.configure do |config|
  config.catalog_files = ["config/riffer/models.json"]
end
```

- `catalog_files` takes an Array of paths (Strings or Pathnames). Files load in the order listed.
- `Riffer.configure` builds the catalog at the end of the block, so a missing file or invalid data raises `Riffer::ArgumentError` at boot.
- Calling `configure` again rebuilds the catalog from scratch.
- Files load at boot only. There is no API to add entries at runtime. The built catalog is frozen.

## File format

```json
{
  "version": 1,
  "models": {
    "anthropic/claude-haiku-4-5-20251001": {
      "aliases": ["anthropic/claude-haiku-4-5"],
      "pricing": {
        "input": 1.0,
        "output": 5.0,
        "cache_read": 0.1,
        "cache_write": 1.25
      },
      "reasoning": {
        "off": { "thinking": { "type": "disabled" } },
        "low": {
          "thinking": { "type": "enabled", "budget_tokens": 1024 },
          "max_tokens": 5120
        },
        "high": {
          "thinking": { "type": "enabled", "budget_tokens": 24576 },
          "max_tokens": 28672
        }
      }
    },
    "gemini/gemini-2.5-flash": {
      "reasoning": {
        "off": { "thinkingConfig": { "thinkingBudget": 0 } },
        "low": { "thinkingConfig": { "thinkingBudget": 1024 } }
      }
    },
    "amazon_bedrock/us.amazon.nova-2-lite-v1:0": {
      "reasoning": {
        "low": {
          "additional_model_request_fields": {
            "reasoningConfig": {
              "type": "enabled",
              "maxReasoningEffort": "low"
            }
          }
        }
      }
    }
  }
}
```

| Key       | Description                                                                                |
| --------- | ------------------------------------------------------------------------------------------ |
| `version` | Required. The file format version. Only `1` is supported.                                  |
| `models`  | An object keyed by exact `provider/model` id: the same string you give an agent's `model`. |

Each model entry can have any of these keys:

| Key         | Description                                                                                                                                                       |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `aliases`   | Other `provider/model` ids that share this entry, pricing included. An alias may name a different provider, e.g. `"azure_openai/my-gpt-prod"` on an OpenAI entry. |
| `pricing`   | Per-million-token rates. See [Pricing](#pricing).                                                                                                                 |
| `reasoning` | An object keyed by level (`off`, `low`, `medium`, `high`, `xhigh`, `max`). Each value is a `model_options` fragment. See [Reasoning](#reasoning).                 |

### Lookup

A model id matches an entry by its exact key first, then by an alias. There are no patterns, families, or fallback entries.

The provider part of the key is the provider's [repository](providers/CUSTOM_PROVIDERS.md#registering-your-provider) identifier, so a custom provider registered as `:my_provider` reads entries under `my_provider/...`.

## Reasoning

A reasoning fragment is written exactly as you would write it in `model_options`, using the provider's own param names. Bedrock fragments spell out `additional_model_request_fields` and `inference_config` themselves.

When an agent sets `reasoning`, riffer picks the params for that level in this order:

1. The catalog entry's fragment for the level (by exact key, then alias).
2. The provider's default mapping, when the entry is missing or doesn't define the level.
3. If the provider has no default either, riffer raises `Riffer::ArgumentError` before the request:
   `No reasoning mapping for my_provider/my-model at level :low. Add one in a catalog file (see docs/CATALOG.md).`

Riffer doesn't check whether a model supports a level. If the model rejects the params, you get the provider's error unchanged.

### Provider defaults

The defaults send the level name as the provider's effort value:

| Provider             | `:off`                                                                | Other levels                                                                                                |
| -------------------- | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| OpenAI, Azure OpenAI | `reasoning: "none"`                                                   | `reasoning: "<level>"`                                                                                      |
| OpenRouter           | `reasoning: "none"`                                                   | `reasoning: "<level>"`                                                                                      |
| Anthropic            | `thinking: { type: "disabled" }`                                      | `thinking: { type: "adaptive" }, output_config: { effort: "<level>" }`                                      |
| Amazon Bedrock       | `additional_model_request_fields: { thinking: { type: "disabled" } }` | `additional_model_request_fields: { thinking: { type: "adaptive" }, output_config: { effort: "<level>" } }` |
| Gemini               | `thinkingConfig: { thinkingLevel: "off" }`                            | `thinkingConfig: { thinkingLevel: "<level>" }`                                                              |
| Mock                 | nothing                                                               | nothing                                                                                                     |

Add a catalog entry for models that need different params, for example:

- Claude 4.5 and earlier, which take a `budget_tokens` thinking budget instead of adaptive thinking.
- Gemini 2.5, which takes `thinkingBudget`.
- Non-Claude models on Amazon Bedrock (Nova, OpenAI), which use their own fields.

A [custom provider](providers/CUSTOM_PROVIDERS.md#reasoning-level) can supply its own default.

### Merging with model_options

The agent's `model_options` always win. Riffer deep-merges them over the fragment: nested objects merge key by key, and any other value (including arrays) replaces the fragment's. So you can override one field without repeating the rest:

```ruby
class SummaryAgent < Riffer::Agent
  model "anthropic/claude-haiku-4-5-20251001"
  reasoning :low
  model_options max_tokens: 8000 # keeps the catalog's thinking budget, replaces its max_tokens
end
```

Riffer doesn't check the merged result. If a partial override makes the request invalid, the provider rejects it.

## Pricing

```json
{
  "pricing": {
    "input": 3.0,
    "output": 15.0,
    "cache_read": 0.3,
    "cache_write": 3.75
  }
}
```

| Key           | Description                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------ |
| `input`       | Required. Price per **million** input tokens. Applies to the uncached portion of `input_tokens`. |
| `output`      | Required. Price per **million** output tokens.                                                   |
| `cache_read`  | Price per million cache-read tokens. When omitted, cache reads bill at the `input` rate.         |
| `cache_write` | Price per million cache-write tokens. When omitted, cache writes bill at the `input` rate.       |

Because the cache buckets are subsets of `input_tokens`, the cost formula subtracts them before applying the input rate:

```text
cost = (input − cache_read − cache_write) × input_rate
     + cache_read  × cache_read_rate
     + cache_write × cache_write_rate
     + output      × output_rate
```

(all rates ÷ 1,000,000; an unset cache rate falls back to `input_rate`.) Cost is for observability, not billing: it's a `Float`, and sub-cent rounding can accumulate over a long run. See [Messages → Token Usage Semantics](MESSAGES.md#token-usage-semantics) for how cost surfaces and aggregates.

A model with no catalog pricing carries no cost. The deprecated [`config.pricing`](CONFIGURATION.md#pricing-deprecated) is still read as a fallback; catalog pricing wins when both price a model.

## Layering files

Later files override earlier ones, so you can keep shared data in one file and local overrides in another:

- For an entry with the same key, a later file replaces whole sections (`pricing`, `reasoning`) and leaves the others alone.
- `aliases` arrays are combined, so a later file can add aliases without repeating earlier ones.
- If a later file lists an alias an earlier file gave to a different entry, the later file wins.

```json
{
  "version": 1,
  "models": {
    "anthropic/claude-haiku-4-5-20251001": {
      "pricing": { "input": 0.8, "output": 4.0 }
    },
    "openai/gpt-5.1": {
      "aliases": ["azure_openai/my-gpt-prod"]
    }
  }
}
```

Listed after the first example, this file replaces Haiku's pricing but keeps its reasoning, and routes an Azure deployment to the `openai/gpt-5.1` entry.

## Validation

Loading raises `Riffer::ArgumentError`, naming the file and the model key, when:

- The file is missing or isn't valid JSON, or `version` is missing or unsupported.
- The file has keys other than `version` and `models`, or an entry has keys other than `aliases`, `pricing`, and `reasoning`.
- A model key or alias isn't in `provider/model` form, or `aliases` isn't an array of strings.
- `pricing` is missing `input` or `output`, has unknown keys, or has a rate that isn't a non-negative number.
- A reasoning level isn't one of `off`, `low`, `medium`, `high`, `xhigh`, `max`, or its value isn't an object.
- Two entries in the same file list the same alias.
- After all files are layered, an alias is also a model key.
