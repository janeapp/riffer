# frozen_string_literal: true
# rbs_inline: enabled

# Wraps MCP-generated tool classes so +tools/call+ resolves
# +Riffer.config.mcp.credentials+ per invocation, delegating metadata to the
# inner class.
module Riffer::Mcp::AuthenticatedTool
  # Returns one wrapper class per inner tool, sharing +manifest+ and +matched_tags+.
  #
  #--
  #: (Array[singleton(Riffer::Tool)], Riffer::Mcp::Manifest, Array[Symbol]) -> Array[singleton(Riffer::Tool)]
  def self.wrap_all(tool_classes, manifest, matched_tags)
    tool_classes.map { |tc| wrap_one(tc, manifest, matched_tags) }
  end

  #--
  #: (singleton(Riffer::Tool), Riffer::Mcp::Manifest, Array[Symbol]) -> singleton(Riffer::Tool)
  # Class.new(Riffer::Tool) is typed as ::Class by steep — it cannot verify the subtype
  # relationship for dynamically created anonymous classes, so the ignore is required.
  def self.wrap_one(inner_class, manifest, matched_tags) # steep:ignore MethodBodyTypeMismatch
    inner = inner_class
    man = manifest
    tags = matched_tags

    Class.new(Riffer::Tool) do
      # steep cannot type the body of a dynamically created anonymous class:
      # its ivars and `self` inside define_method are unresolvable.
      # steep:ignore:start
      @identifier = inner.identifier

      define_singleton_method(:name) { inner.name }
      define_singleton_method(:mcp_server_tool_name) { inner.mcp_server_tool_name }
      define_singleton_method(:description) { inner.description }
      define_singleton_method(:parameters_schema) { |strict: false| inner.parameters_schema(strict: strict) }

      # Creates a fresh client per +tools/call+ so headers from the credentials
      # proc stay current.
      # TODO: A per-headers cache would reduce connection churn under load, and
      # requires a follow-up investigation to determine how to invalidate failing
      # clients.
      define_method(:build_call_client) do |endpoint, headers|
        Riffer::Mcp::Client.new(endpoint: endpoint, headers: headers)
      end
      private :build_call_client

      define_method(:call) do |context:, **kwargs|
        cred = Riffer.config.mcp.credentials
        unless cred
          # `next` rather than `return`: inside define_method the block IS the method
          # body, so both exit :call identically at runtime. `next` avoids a false
          # steep ReturnTypeMismatch that would otherwise need a steep:ignore.
          next inner.new.call(context: context, **kwargs)
        end

        headers = cred.call(manifest: man, matched_tags: tags, context: context)
        if headers.nil?
          raise Riffer::Mcp::CredentialsDeniedError,
            "MCP credentials returned nil for server '#{man.name}' during tools/call"
        end

        client = build_call_client(man.endpoint, headers)
        text(client.tools_call(inner.mcp_server_tool_name, kwargs))
      end
      # steep:ignore:end
    end
  end
end
