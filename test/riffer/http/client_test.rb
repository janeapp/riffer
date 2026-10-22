# frozen_string_literal: true

require "test_helper"

describe Riffer::HTTP::Client do
  let(:client_class) do
    Class.new(Riffer::HTTP::Client) do
      private

      def url_for(path) = "https://api.example.test/#{path}"

      def headers = { "x-api-key" => "secret" }

      def error_label = "Example"
    end
  end
  let(:client) { client_class.new }
  let(:url) { "https://api.example.test/v1/messages" }

  # Re-runs the adapter the way faraday-retry does, restoring the request body
  # the first run replaced with the response body.
  let(:repeat_middleware) do
    Class.new(Faraday::Middleware) do
      def call(env)
        request_body = env.body
        response = @app.call(env)
        return response unless repeat?(response)

        env.body = request_body
        @app.call(env)
      end

      def repeat?(_response) = true
    end
  end

  # Mimics httpx: on_data gets two arguments, the second being the chunk size.
  let(:two_arg_adapter) do
    Class.new(Faraday::Adapter) do
      def call(env)
        super
        env.request.on_data.call("data: a\n\n", 9)
        env.request.on_data.call("data: b\n\n", 9)
        save_response(env, env.request_headers["x-status"].to_i, "")
        @app.call(env)
      end
    end
  end

  describe "#initialize" do
    it "applies the default timeouts" do
      options = client.instance_variable_get(:@connection).options

      expect(options.open_timeout).must_equal 10
      expect(options.read_timeout).must_equal 600
    end

    it "sends requests through a custom connection and keeps its headers" do
      stub = stub_request(:post, url).
        with(headers: { "anthropic-beta" => "beta-1", "x-api-key" => "secret" }).
        to_return(status: 200, body: "{}")
      connection = Faraday.new(headers: { "anthropic-beta" => "beta-1" })
      client_class.new(connection: connection).post("v1/messages", {})

      assert_requested stub
      expect(connection.headers.key?("x-api-key")).must_equal false
    end
  end

  describe "#post" do
    it "sends the subclass headers and a JSON body" do
      stub = stub_request(:post, url).
        with(headers: { "x-api-key" => "secret", "Content-Type" => "application/json" }, body: '{"model":"m"}').
        to_return(status: 200, body: "{}")
      client.post("v1/messages", { model: "m" })

      assert_requested stub
    end

    it "returns the parsed body with symbol keys" do
      stub_request(:post, url).to_return(status: 200, body: '{"content":[{"type":"text"}]}')

      expect(client.post("v1/messages", {})).must_equal({ content: [{ type: "text" }] })
    end

    it "raises Riffer::APIError with the status and raw body on a failing status" do
      body = '{"error":{"message":"bad request"}}'
      stub_request(:post, url).to_return(status: 400, body: body)
      error = expect { client.post("v1/messages", {}) }.must_raise Riffer::APIError

      expect(error.message).must_equal "Example API error (400): bad request"
      expect(error.status).must_equal 400
      expect(error.body).must_equal body
    end

    it "uses a top-level message" do
      stub_request(:post, url).to_return(status: 404, body: '{"message":"not found"}')
      error = expect { client.post("v1/messages", {}) }.must_raise Riffer::APIError

      expect(error.message).must_equal "Example API error (404): not found"
    end

    it "uses an error given as a string" do
      stub_request(:post, url).to_return(status: 404, body: '{"error":"Not Found"}')
      error = expect { client.post("v1/messages", {}) }.must_raise Riffer::APIError

      expect(error.message).must_equal "Example API error (404): Not Found"
    end

    it "unwraps an error wrapped in a one-element array" do
      stub_request(:post, url).to_return(status: 429, body: '[{"error":{"message":"quota exceeded"}}]')
      error = expect { client.post("v1/messages", {}) }.must_raise Riffer::APIError

      expect(error.message).must_equal "Example API error (429): quota exceeded"
    end

    it "uses the raw body when the error is not JSON" do
      stub_request(:post, url).to_return(status: 502, body: "Bad Gateway")
      error = expect { client.post("v1/messages", {}) }.must_raise Riffer::APIError

      expect(error.message).must_equal "Example API error (502): Bad Gateway"
    end

    it "uses the raw body when the error JSON is not an object" do
      stub_request(:post, url).to_return(status: 500, body: '"overloaded"')
      error = expect { client.post("v1/messages", {}) }.must_raise Riffer::APIError

      expect(error.message).must_equal 'Example API error (500): "overloaded"'
    end

    it "takes the message from an overridden error_message" do
      custom = Class.new(client_class) do
        private

        def error_message(parsed, _raw) = "#{parsed.dig(:error, :type)}: #{parsed.dig(:error, :message)}"
      end
      stub_request(:post, url).to_return(status: 400, body: '{"error":{"type":"invalid","message":"no"}}')
      error = expect { custom.new.post("v1/messages", {}) }.must_raise Riffer::APIError

      expect(error.message).must_equal "Example API error (400): invalid: no"
    end
  end

  describe "#post_stream" do
    def collect(client)
      chunks = []
      client.post_stream("v1/messages", {}) { |chunk| chunks << chunk }
      chunks
    end

    it "yields the streamed body" do
      stub_request(:post, url).to_return(status: 200, body: "data: one\n\ndata: two\n\n")

      expect(collect(client).join).must_equal "data: one\n\ndata: two\n\n"
    end

    it "asks for an uncompressed event stream" do
      stub = stub_request(:post, url).
        with(headers: { "Accept" => "text/event-stream", "Accept-Encoding" => "identity", "x-api-key" => "secret" }).
        to_return(status: 200, body: "")
      collect(client)

      assert_requested stub
    end

    it "raises Riffer::APIError with the streamed error body and yields nothing" do
      body = '{"error":{"message":"overloaded"}}'
      stub_request(:post, url).to_return(status: 529, body: body)
      chunks = []
      error = expect { client.post_stream("v1/messages", {}) { |chunk| chunks << chunk } }.must_raise Riffer::APIError

      expect(error.message).must_equal "Example API error (529): overloaded"
      expect(error.body).must_equal body
      expect(chunks).must_be_empty
    end

    it "yields the whole body once when the adapter does not stream" do
      connection = Faraday.new do |f|
        f.adapter :test do |stubs|
          stubs.post(url) { [200, {}, "data: one\n\n"] }
        end
      end

      expect(collect(client_class.new(connection: connection))).must_equal ["data: one\n\n"]
    end

    it "raises Riffer::APIError when a non-streaming adapter gets a failing status" do
      connection = Faraday.new do |f|
        f.adapter :test do |stubs|
          stubs.post(url) { [401, {}, '{"error":{"message":"invalid key"}}'] }
        end
      end
      error = expect { collect(client_class.new(connection: connection)) }.must_raise Riffer::APIError

      expect(error.message).must_equal "Example API error (401): invalid key"
    end

    it "yields every chunk after the response when the adapter passes no env" do
      connection = Faraday.new(headers: { "x-status" => "200" }) { |f| f.adapter two_arg_adapter }

      expect(collect(client_class.new(connection: connection)).join).must_equal "data: a\n\ndata: b\n\n"
    end

    it "raises Riffer::APIError with every chunk when the adapter passes no env" do
      connection = Faraday.new(headers: { "x-status" => "500" }) { |f| f.adapter two_arg_adapter }
      error = expect { collect(client_class.new(connection: connection)) }.must_raise Riffer::APIError

      expect(error.body).must_equal "data: a\n\ndata: b\n\n"
    end

    it "raises Riffer::Error when the stream restarts after data was yielded" do
      stub_request(:post, url).to_return(status: 200, body: "data: one\n\n")
      connection = Faraday.new { |f| f.use repeat_middleware }
      error = expect { collect(client_class.new(connection: connection)) }.must_raise Riffer::Error

      expect(error.message).must_match(/stream restarted after data was delivered/)
    end

    it "streams a retry that starts before any data was yielded" do
      stub_request(:post, url).to_return(
        { status: 429, body: '{"error":{"message":"slow down"}}' },
        { status: 200, body: "data: ok\n\n" },
      )
      retry_on_rate_limit = Class.new(repeat_middleware) do
        def repeat?(response) = response.status == 429
      end
      connection = Faraday.new { |f| f.use retry_on_rate_limit }

      expect(collect(client_class.new(connection: connection))).must_equal ["data: ok\n\n"]
    end
  end
end
