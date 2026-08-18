---
paths: ["lib/riffer/providers/**/*.rb"]
---

# Providers

- **Never pass an SDK an explicit nil credential.** Build the kwargs as a hash and `.compact` it, so an unset value stays _absent_: SDKs distinguish absent from nil to decide whether to read their own env vars, and an explicit nil suppresses that. Passing `base_url: nil` skips `OPENAI_BASE_URL` and pins requests to api.openai.com; passing `region: nil` makes the AWS SDK raise `MissingRegionError` even with `AWS_REGION` exported.
- **Exception — a provider borrowing another vendor's SDK** (`OpenRouter` and `AzureOpenAI` reuse `::OpenAI::Client`) must keep its credential and endpoint concrete, nil included. Compacting there would let the OpenAI SDK fall back to `OPENAI_API_KEY` / `OPENAI_BASE_URL` and send one vendor's credential to another's endpoint. Compact a key only when the SDK's env fallback for it names the same service the provider talks to.
