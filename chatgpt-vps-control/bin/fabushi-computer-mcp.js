#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { registerComputerUseTools } from "../computer-use.js";
import { computerControlPolicyDecision } from "../lib/fabushi-computer-policy.js";
import { registerCiSessionTools } from "../lib/ci-session-tools.js";
import { registerAppAgentTools } from "../lib/app-agent-tools.js";

const server = new McpServer({
  name: "fabushi-computer",
  version: "1.0.0",
});

const toolMeta = (invoking, invoked) => ({
  "openai/toolInvocation/invoking": invoking,
  "openai/toolInvocation/invoked": invoked,
});


registerComputerUseTools(server, {
  // This is a bundled, stdio-only server. It is never network exposed and is
  // spawned by the signed Fabushi Host for the current desktop user. The MCP
  // tool annotations keep mutating calls inside Codex's approval policy, and
  // the operating system remains the final Accessibility/Screen Recording
  // permission boundary. This process is not a remotely reachable service.
  hasReadScope: () => computerControlPolicyDecision().allowed,
  hasWriteScope: () => computerControlPolicyDecision().allowed,
  readAuthChallenge: "",
  writeAuthChallenge: "",
  toolAuthError: () => {
    const decision = computerControlPolicyDecision();
    return {
      isError: true,
      content: [{ type: "text", text: decision.reason || "Fabushi 电脑控制当前未获授权。" }],
    };
  },
  readSecuritySchemes: [],
  writeSecuritySchemes: [],
  toolMeta,
  audit: async (record) => {
    process.stderr.write(`${JSON.stringify({ type: "fabushi.computer.audit", ...record })}\n`);
  },
});


registerAppAgentTools(server, {
  canRead: () => computerControlPolicyDecision().allowed,
  canWrite: () => computerControlPolicyDecision().allowed,
  authError: () => {
    const decision = computerControlPolicyDecision();
    return {
      isError: true,
      content: [{ type: "text", text: decision.reason || "Fabushi App MCP 当前未获电脑控制授权。" }],
    };
  },
  readSecuritySchemes: [],
  writeSecuritySchemes: [],
  toolMeta,
  audit: async (record) => {
    process.stderr.write(`${JSON.stringify({ type: "fabushi.app-agent.audit", ...record })}\n`);
  },
});

registerCiSessionTools(server, {
  allowed: () => computerControlPolicyDecision().allowed,
});

await server.connect(new StdioServerTransport());
