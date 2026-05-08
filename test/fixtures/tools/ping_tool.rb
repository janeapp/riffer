# frozen_string_literal: true

# Minimal +Riffer::Tool+ used in +Riffer::McpServer+ tests to exercise the
# server's dispatch path. Echoes the +message+ argument back as text.
module Test
  class PingTool < Riffer::Tool
    identifier "ping_tool"
    description "Echoes the supplied message back to the caller."

    params do
      required :message, String, description: "The message to echo"
    end

    def call(context:, message:)
      text(message)
    end
  end
end
