# frozen_string_literal: true

# Remote Tool Runtime
#
# When an agent is rebuilt from a wire dict on a receiver that holds only the
# Riffer gem (no tool bodies), Riffer::Agent::Serializer.from_h synthesizes
# body-less tool *shells* — their #call raises. The receiver advertises the
# tool schemas to the LLM, but actual execution must happen back on the
# origin. A remote Tools::Runtime is the seam for that: override
# #dispatch_tool_call to forward the call over your transport (HTTP, gRPC, a
# queue) and map the reply (or any failure) back to a Riffer::Tools::Response.
#
# The base class already gives you Runner concurrency, #around_tool_call, and
# error handling — you only supply transport. Note that #dispatch_tool_call
# never looks at the +tools+ argument: shells carry no behavior, so dispatch
# is purely by name + arguments.
#
# Usage:
#
#   dict = origin_agent.to_h                       # on the origin
#   runtime = RemoteToolRuntime.new(client: my_rpc_client)
#   agent = Riffer::Agent.from_h(dict, context: {tenant: "acme"}, tool_runtime: runtime)
#   agent.generate("What's the weather in Paris?") # tool calls round-trip to the origin
#
class RemoteToolRuntime < Riffer::Tools::Runtime
  # A timeout (seconds) for the whole round-trip to the origin executor.
  REMOTE_TIMEOUT = 30

  # [client] anything that responds to #call(name:, arguments:, timeout:) and
  #   returns a String result. Inject your HTTP/gRPC/queue client here — the
  #   runtime stays transport-agnostic and testable.
  # [runner] the concurrency runner; defaults to sequential. Pass a threaded
  #   or fiber runner to dispatch a batch of tool calls in parallel.
  def initialize(client:, runner: Riffer::Runner::Sequential.new)
    super(runner: runner)
    @client = client
  end

  private

  # Forward a single tool call to the origin and map the reply back. A dead or
  # slow executor degrades to Tools::Response.error rather than crashing the
  # loop — the LLM sees the error and can react.
  def dispatch_tool_call(tool_call, tools:, context:, assistant_message: nil)
    arguments = (tool_call.arguments.nil? || tool_call.arguments.empty?) ? {} : JSON.parse(tool_call.arguments)

    result = @client.call(name: tool_call.name, arguments: arguments, timeout: REMOTE_TIMEOUT)

    Riffer::Tools::Response.text(result)
  rescue JSON::ParserError => e
    Riffer::Tools::Response.error("Bad tool arguments: #{e.message}", type: :validation_error)
  rescue => e
    # Replace with the specific transport/timeout errors your client raises.
    Riffer::Tools::Response.error("Remote tool '#{tool_call.name}' failed: #{e.message}", type: :execution_error)
  end
end
