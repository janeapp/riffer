# Testing

## Framework

Use Minitest with the spec DSL for all tests.

## Test Structure

```ruby
# frozen_string_literal: true

require "test_helper"

describe Riffer::Feature do
  describe "#method_name" do
    before do
      # setup code
    end

    it "does something expected" do
      result = Riffer::Feature.method_name(args)
      assert_equal expected, result
    end

    it "handles edge case" do
      result = Riffer::Feature.method_name(edge_case_args)
      assert_equal edge_case_expected, result
    end
  end
end
```

## Guidelines

- Test files go in `test/` directory with `*_test.rb` suffix
- Use `before`/`after` blocks for setup and cleanup
- Stick to the single assertion rule where possible
- Test edge cases and error conditions
- Use Minitest assertions: `assert_equal`, `assert_instance_of`, `refute_nil`, etc.

## VCR Cassettes

Record external API interactions in `test/fixtures/vcr_cassettes/`.

## Running Tests

```bash
# Run all tests
bin/test

# Run a single test file (or multiple files)
bin/test test/riffer/agent_test.rb
bin/test test/riffer/agent_test.rb test/riffer/config_test.rb

# Filter by test name (regex or substring)
bin/test test/riffer/agent_test.rb --name /generates/

# Filter across the whole suite
bin/test --name /generates/
```
