# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Mcp::AuthenticatedTool
  extend self

  #--
  #: (Array[singleton(Riffer::Mcp::Tool)], Riffer::Mcp::Manifest, Array[Symbol]) -> Array[singleton(Riffer::Mcp::Tool)]
  def wrap_all(tool_classes, manifest, matched_tags)
    tool_classes.map { |tc| wrap_one(tc, manifest, matched_tags) }
  end

  #--
  #: (singleton(Riffer::Mcp::Tool), Riffer::Mcp::Manifest, Array[Symbol]) -> singleton(Riffer::Mcp::Tool)
  def wrap_one(inner_class, manifest, matched_tags)
    inner = inner_class
    man = manifest
    tags = matched_tags

    # steep does not model Class.new's class_eval semantics — the block body
    # typechecks against the enclosing module.
    Class.new(Riffer::Mcp::Tool) do
      # steep:ignore:start
      @identifier = inner.identifier
      @description = inner.description
      @input_schema = inner.parameters_schema
      @mcp_server_tool_name = inner.mcp_server_tool_name

      # A fresh client per +tools/call+ keeps credentials-proc headers current at
      # the cost of connection churn; a per-headers cache would first need a way
      # to invalidate failing clients.
      define_method(:build_call_client) do |endpoint, headers|
        Riffer::Mcp::Client.new(endpoint: endpoint, headers: headers)
      end
      private :build_call_client

      define_method(:call) do |context:, **kwargs|
        cred = Riffer.config.mcp.credentials
        next inner.new.call(context: context, **kwargs) unless cred

        headers = cred.call(manifest: man, matched_tags: tags, context: context)
        if headers.nil?
          raise Riffer::Mcp::CredentialsDeniedError,
                "MCP credentials returned nil for server '#{man.name}' during tools/call"
        end

        client = build_call_client(man.endpoint, headers)
        text(client.tools_call(self.class.mcp_server_tool_name, kwargs))
      end
      # steep:ignore:end
    end #: singleton(Riffer::Mcp::Tool)
  end
end
