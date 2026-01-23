# Adding a New Provider

## Steps

1. Create `lib/riffer/providers/your_provider.rb` extending `Riffer::Providers::Base`
2. Implement required methods (see below)
3. Register in `Riffer::Providers::Repository::REPO`
4. Add provider config to `Riffer::Config` if needed
5. Create tests in `test/riffer/providers/your_provider_test.rb`

## Required Methods

```ruby
# frozen_string_literal: true

module Riffer
  module Providers
    class YourProvider < Base
      # Returns Riffer::Messages::Assistant
      def perform_generate_text(messages, model:)
        # Implementation
      end

      # Returns Enumerator yielding stream events
      def perform_stream_text(messages, model:)
        # Implementation
      end
    end
  end
end
```

## Registration

Add to `Riffer::Providers::Repository::REPO`:

```ruby
REPO = {
  # ... existing providers
  "your_provider" => YourProvider
}.freeze
```

## Dependencies

Use `depends_on` helper for runtime dependency checking if your provider requires external gems.
