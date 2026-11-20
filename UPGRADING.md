# Upgrading

Upgrade guides for breaking releases will appear here. See the [stability policy](https://riffer.ai/guides/stability/) for when breaking changes can happen. To try a breaking release's new behaviour early, turn on its [future flag](https://riffer.ai/guides/configuration/#future-flags).

## 0.58.0

### Evals moved to the riffer-evals gem

`Riffer::Evals` and `config.evals` are no longer part of riffer. Add the `riffer-evals` gem to your Gemfile:

```ruby
gem "riffer-evals"
```

If your app doesn't call `Bundler.require`, add `require "riffer/evals"` after `require "riffer"`.

The `Riffer::Evals` API (`Evaluator`, `Judge`, `EvaluatorRunner`, `Result`, `RunResult`, `ScenarioResult`) is unchanged. The judge model setting moves from riffer's config to the gem's own:

```ruby
# Before
Riffer.config.evals.judge_model = "anthropic/claude-opus-4-5-20251101"

# After
Riffer::Evals.config.judge_model = "anthropic/claude-opus-4-5-20251101"

# Or
Riffer::Evals.configure do |config|
  config.judge_model = "anthropic/claude-opus-4-5-20251101"
end
```
