# Adding a New Provider

## Steps

1. Create `lib/riffer/providers/your_provider.rb` extending `Riffer::Providers::Base`
2. Implement the required hook methods (see [Custom Providers](../docs/providers/CUSTOM_PROVIDERS.md) for the full API)
3. Register in `Riffer::Providers::Repository::REPO`
4. Add provider config to `Riffer::Config` if needed
5. Create tests in `test/riffer/providers/your_provider_test.rb`

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
