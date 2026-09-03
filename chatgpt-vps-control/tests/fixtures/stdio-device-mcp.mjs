import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "stdio-device-fixture", version: "1.0.0" });
server.registerTool("computer_state", {
  title: "Computer state fixture",
  description: "Return the fixture application state.",
  inputSchema: { application: z.string().optional() },
  outputSchema: { activeApp: z.string(), requestedApp: z.string().nullable() },
  annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
}, async ({ application }) => ({
  structuredContent: { activeApp: "Fabushi", requestedApp: application || null },
  content: [{ type: "text", text: "Fabushi fixture is active." }],
}));
await server.connect(new StdioServerTransport());
