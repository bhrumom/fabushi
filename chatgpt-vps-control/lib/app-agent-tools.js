import { z } from "zod";
import { createAppAgentSurfaceClient } from "./app-agent-surface-client.js";

const APP_TOOL_NAMES = Object.freeze({
  status: "fabushi.app.status",
  snapshot: "fabushi.app.snapshot",
  find: "fabushi.app.find",
  action: "fabushi.app.action",
  wait: "fabushi.app.wait",
  assert: "fabushi.app.assert",
});

const queryShape = {
  route: z.string().max(500).optional(),
  screen: z.string().max(160).optional(),
  agentId: z.string().max(200).optional(),
  ref: z.string().max(240).optional(),
  role: z.string().max(80).optional(),
  name: z.string().max(240).optional(),
  text: z.string().max(400).optional(),
  state: z.enum(["present", "absent", "enabled", "disabled", "visible", "hidden"]).optional(),
};

function toolMeta(options, invoking, invoked) {
  return options.toolMeta?.(invoking, invoked) ?? {};
}

function authError(options, write) {
  return options.authError?.(write) ?? {
    isError: true,
    content: [{ type: "text", text: "Fabushi App MCP is not authorized by the local computer-control policy." }],
  };
}

function textSummary(name, result) {
  if (name === APP_TOOL_NAMES.status) {
    return result?.available
      ? `Fabushi App MCP is available on ${result.route || "the current route"}, screen ${result.screen || "unknown"}, generation ${result.generation ?? "unknown"}.`
      : `Fabushi App MCP is unavailable: ${result?.reason || "Fabushi is not running."}`;
  }
  if (name === APP_TOOL_NAMES.snapshot) {
    return `Read Fabushi semantic UI: route=${result?.route || "unknown"}, screen=${result?.screen || "unknown"}, generation=${result?.generation ?? "unknown"}, elements=${result?.elementCount ?? result?.elements?.length ?? 0}.`;
  }
  if (name === APP_TOOL_NAMES.find) return `Found ${result?.count ?? result?.matches?.length ?? 0} Fabushi semantic UI element(s).`;
  if (name === APP_TOOL_NAMES.action) return `Completed Fabushi semantic action ${result?.action || "unknown"}; current generation is ${result?.after?.generation ?? "unknown"}.`;
  if (name === APP_TOOL_NAMES.wait) return result?.passed ? "Fabushi semantic UI condition became true." : "Fabushi semantic UI wait timed out.";
  if (name === APP_TOOL_NAMES.assert) return result?.passed ? "Fabushi semantic UI assertion passed." : `Fabushi semantic UI assertion failed: ${(result?.failures || []).join("; ")}`;
  return "Fabushi App MCP operation completed.";
}

function success(name, result) {
  return {
    content: [{ type: "text", text: textSummary(name, result) }],
    structuredContent: result,
  };
}

function failure(error) {
  const message = error instanceof Error ? error.message : String(error);
  return {
    isError: true,
    content: [{ type: "text", text: message.slice(0, 1000) }],
  };
}

async function auditedCall(options, client, name, operation, input, write, extra = {}) {
  if (write ? options.canWrite?.() === false : options.canRead?.() === false) return authError(options, write);
  const audit = {
    tool: name,
    operation,
    write,
    ...(input?.action ? { action: input.action } : {}),
    ...(input?.agentId ? { agentId: String(input.agentId).slice(0, 200) } : {}),
    ...(input?.ref ? { ref: String(input.ref).slice(0, 240) } : {}),
    ...extra,
  };
  try {
    const result = operation === "status" ? await client.status() : await client.call(operation, input);
    await options.audit?.({ ...audit, status: "success" });
    return success(name, result);
  } catch (error) {
    await options.audit?.({ ...audit, status: "error", error: error instanceof Error ? error.message.slice(0, 500) : "unknown" });
    return failure(error);
  }
}

export function registerAppAgentTools(server, options = {}) {
  const client = options.client ?? createAppAgentSurfaceClient(options.clientOptions);
  const readSecuritySchemes = options.readSecuritySchemes ?? [];
  const writeSecuritySchemes = options.writeSecuritySchemes ?? [];

  server.registerTool(APP_TOOL_NAMES.status, {
    title: "Fabushi App MCP status",
    description: "Check whether the running Fabushi desktop application exposes its structured App MCP semantic surface. Use before screenshots or coordinate control.",
    inputSchema: {},
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
    securitySchemes: readSecuritySchemes,
    _meta: toolMeta(options, "Checking Fabushi App MCP…", "Fabushi App MCP checked"),
  }, async () => auditedCall(options, client, APP_TOOL_NAMES.status, "status", {}, false));

  server.registerTool(APP_TOOL_NAMES.snapshot, {
    title: "Read Fabushi semantic UI",
    description: "Read route, screen, generation and redacted semantic elements from Fabushi. Prefer this over screenshots when controlling Fabushi itself.",
    inputSchema: {
      maxElements: z.number().int().min(1).max(500).optional(),
      includeText: z.boolean().optional(),
    },
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
    securitySchemes: readSecuritySchemes,
    _meta: toolMeta(options, "Reading Fabushi semantic UI…", "Fabushi semantic UI ready"),
  }, async (input) => auditedCall(options, client, APP_TOOL_NAMES.snapshot, "snapshot", input, false));

  server.registerTool(APP_TOOL_NAMES.find, {
    title: "Find Fabushi semantic elements",
    description: "Find Fabushi elements by stable agent id, generation-bound ref, role, accessible name or text.",
    inputSchema: {
      agentId: z.string().max(200).optional(),
      ref: z.string().max(240).optional(),
      role: z.string().max(80).optional(),
      name: z.string().max(240).optional(),
      text: z.string().max(400).optional(),
      limit: z.number().int().min(1).max(100).optional(),
    },
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
    securitySchemes: readSecuritySchemes,
    _meta: toolMeta(options, "Finding Fabushi UI elements…", "Fabushi UI elements found"),
  }, async (input) => auditedCall(options, client, APP_TOOL_NAMES.find, "find", input, false));

  server.registerTool(APP_TOOL_NAMES.action, {
    title: "Operate the Fabushi semantic UI",
    description: "Invoke, focus, set a non-sensitive value, press a key, scroll, select, or toggle one Fabushi element. Exact generation is required and stale references fail closed.",
    inputSchema: {
      generation: z.number().int().min(1),
      ref: z.string().max(240).optional(),
      agentId: z.string().max(200).optional(),
      action: z.enum(["invoke", "focus", "setValue", "pressKey", "scroll", "selectOption", "toggle"]),
      value: z.string().max(20_000).optional(),
    },
    annotations: { readOnlyHint: false, destructiveHint: true, openWorldHint: false, idempotentHint: false },
    securitySchemes: writeSecuritySchemes,
    _meta: toolMeta(options, "Operating Fabushi…", "Fabushi operation complete"),
  }, async (input) => {
    if (!input.ref && !input.agentId) return failure(new Error("fabushi.app.action requires ref or agentId."));
    return auditedCall(options, client, APP_TOOL_NAMES.action, "action", input, true);
  });

  server.registerTool(APP_TOOL_NAMES.wait, {
    title: "Wait for Fabushi semantic state",
    description: "Wait for a structured Fabushi route, screen or semantic element condition without polling screenshots.",
    inputSchema: {
      ...queryShape,
      timeoutMs: z.number().int().min(100).max(30_000).optional(),
    },
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
    securitySchemes: readSecuritySchemes,
    _meta: toolMeta(options, "Waiting for Fabushi UI…", "Fabushi UI wait complete"),
  }, async (input) => auditedCall(options, client, APP_TOOL_NAMES.wait, "wait", input, false));

  server.registerTool(APP_TOOL_NAMES.assert, {
    title: "Assert Fabushi semantic state",
    description: "Evaluate a deterministic assertion against Fabushi route, screen or semantic elements and return CI-ready observations.",
    inputSchema: queryShape,
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
    securitySchemes: readSecuritySchemes,
    _meta: toolMeta(options, "Checking Fabushi UI assertion…", "Fabushi UI assertion checked"),
  }, async (input) => auditedCall(options, client, APP_TOOL_NAMES.assert, "assert", input, false));

  server.registerTool("computer_control_route", {
    title: "Choose the best computer-control path",
    description: "Choose semantic App MCP, browser DOM/accessibility, native AX/UIA/AT-SPI, or screenshot-coordinate fallback. This preserves control of third-party apps that do not implement App MCP.",
    inputSchema: {
      targetApp: z.string().max(300).optional(),
      targetKind: z.enum(["fabushi", "browser", "native", "canvas", "unknown"]).optional(),
      goal: z.string().max(2_000).optional(),
    },
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
    securitySchemes: readSecuritySchemes,
    _meta: toolMeta(options, "Selecting a semantic control route…", "Control route selected"),
  }, async (input) => {
    if (options.canRead?.() === false) return authError(options, false);
    const status = await client.status();
    const target = String(input.targetApp || "").toLowerCase();
    const kind = input.targetKind || (target.includes("fabushi") ? "fabushi" : "unknown");
    const appMcpPreferred = kind === "fabushi" && status.available === true;
    const route = appMcpPreferred
      ? "app-mcp"
      : kind === "browser"
        ? "browser-semantic"
        : ["native", "unknown", "fabushi"].includes(kind)
          ? "native-semantic"
          : "coordinate-fallback";
    const result = {
      route,
      targetApp: input.targetApp || null,
      appMcp: status,
      priority: [
        { rank: 1, route: "app-mcp", tools: Object.values(APP_TOOL_NAMES), when: "The target is Fabushi and fabushi.app.status reports available." },
        { rank: 2, route: "browser-semantic", tools: ["computer_browser_snapshot", "computer_browser_locator", "computer_browser_cua"], when: "The target is a browser page or WebView with DOM/accessibility semantics." },
        { rank: 3, route: "native-semantic", tools: ["computer_applications", "computer_app_state", "computer_elements", "computer_element_action", "computer_element_secondary_action"], when: "The target is any native third-party application, including apps without App MCP." },
        { rank: 4, route: "coordinate-fallback", tools: ["computer_state", "computer_use", "computer_use_bridge"], when: "Only for canvas, game, inaccessible remote surface, or after semantic paths are proven unavailable." },
      ],
      screenshotIsFallback: true,
      guidance: appMcpPreferred
        ? "Use fabushi.app.snapshot/find/action/wait/assert. Keep computer_* available for OS dialogs and other applications."
        : "Do not assume App MCP is required. Use browser or native semantic tools first, then coordinate Computer Use only when semantics are unavailable.",
    };
    await options.audit?.({ tool: "computer_control_route", status: "success", route });
    return success("computer_control_route", result);
  });

  return { client, toolNames: [...Object.values(APP_TOOL_NAMES), "computer_control_route"] };
}

export { APP_TOOL_NAMES };
