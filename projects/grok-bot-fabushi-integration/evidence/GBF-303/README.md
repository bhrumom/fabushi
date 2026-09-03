# GBF-303 Evidence — tool/MCP/extension dispatch

Removed the unused direct `runtime.callTool` AppHost method and its desktop edge exposure. The production MCP execution path is now evidenced as `FeatureCommand::McpToolCall` -> `FeatureHost` -> `RuntimeCommand::McpToolCall` -> agent backend `call_mcp_tool`, followed by action audit and `mcp.toolResult` event.

Plugin lifecycle/introspection remains a host management function; arbitrary tool execution is not a parallel renderer path.
