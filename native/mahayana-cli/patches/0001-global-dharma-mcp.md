# Required fork patch: Global Dharma MCP

Apply this patch to the pinned upstream CLI workspace:

1. Rename the distributed executable and user-visible product strings from
   `codex` to `mahayana`; retain upstream copyright and Apache-2.0 notices.
2. Disable ChatGPT login and require a configured API key plus an
   OpenAI-compatible base URL/model profile.
3. Add the bundled stdio MCP entry:

```toml
[mcp_servers.global-dharma]
command = "global-dharma-mcp"
```

4. Extend the TUI mention parser so `@global-dharma` filters and selects that
   server's `global_dharma.*` tools. Keep upstream approval prompts for all
   non-read-only calls.

The source fork must build the MCP executable from
`../global-dharma/crates/global-dharma-mcp` as a release artifact.
