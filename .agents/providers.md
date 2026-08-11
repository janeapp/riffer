# Adding a New Provider

## Steps

1. Create `lib/riffer/providers/your_provider.rb` extending `Riffer::Providers::Base`
2. Implement the required hook methods (see [Custom Providers](../docs/providers/CUSTOM_PROVIDERS.md) for the full API)
3. Register in `Riffer::Providers::Repository::REPO`
4. Add provider config to `Riffer::Config` if needed — a `Struct` with credential members plus a `client` member
5. Create tests in `test/riffer/providers/your_provider_test.rb`

## Constructor and client contract

- Constructors take **credentials only** as optional keywords (strict kwargs, no `**` passthrough) — agents call `provider_class.new` bare. Set `@explicit_credentials = !!<any credential kwarg>` in the constructor.
- Never hold a client ivar; call the private `client` method from `execute_generate`/`execute_stream`. Base resolves: constructor credentials → `provider_config&.client` (a client instance, or a no-argument Proc resolved on every call) → memoized `build_default_client`.
- Providers hold no agent state — no context, no reference to the owning agent. Client selection is process-global by design, so a configured Proc takes no arguments.
- Implement `build_default_client` (build the SDK client from `@<credential> || config fallback`) and override `provider_config` to return the provider's config struct.
- **Never pass an SDK an explicit nil credential.** Build the kwargs as a hash and `.compact` it, so an unset value stays _absent_: SDKs distinguish absent from nil to decide whether to read their own env vars, and an explicit nil suppresses that. Passing `base_url: nil` skips `OPENAI_BASE_URL` and pins requests to api.openai.com; passing `region: nil` makes the AWS SDK raise `MissingRegionError` even with `AWS_REGION` exported.
- **Exception — a provider borrowing another vendor's SDK** (`OpenRouter` and `AzureOpenAI` reuse `::OpenAI::Client`) must keep its credential and endpoint concrete, nil included. Compacting there would let the OpenAI SDK fall back to `OPENAI_API_KEY` / `OPENAI_BASE_URL` and send one vendor's credential to another's endpoint. Compact a key only when the SDK's env fallback for it names the same service the provider talks to.

## Architecture

The base class uses the **template method** pattern. The public methods `generate_text` and `stream_text` orchestrate the flow, delegating to hook methods that each provider implements:

```
generate_text
  ├─ build_request_params
  ├─ execute_generate
  ├─ extract_content
  ├─ extract_tool_calls
  └─ extract_token_usage

stream_text
  ├─ build_request_params
  └─ execute_stream
```

## Registration

Add to `Riffer::Providers::Repository::REPO`:

```ruby
REPO = {
  # ... existing providers
  your_provider: -> { YourProvider }
}.freeze
```

## Dependencies

Use `depends_on` helper for runtime dependency checking if your provider requires external gems.

## Reference

For hook method signatures, structured output handling, file handling, and complete examples, see [Custom Providers](../docs/providers/CUSTOM_PROVIDERS.md).
