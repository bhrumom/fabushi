import { readFile } from "node:fs/promises";

const [utils, host] = await Promise.all([
  readFile(new URL("../src/lib/fabushi-runtime/agent-utils.ts", import.meta.url), "utf8"),
  readFile(new URL("../src/app/host/host-client.tsx", import.meta.url), "utf8"),
]);

const requiredPolicySignals = [
  "Prefer event-driven work over polling",
  "Prefer connected Connector/MCP/API tools over browser or computer UI automation",
  "report the blocker immediately",
  "preserve approval requirements for destructive",
];

for (const signal of requiredPolicySignals) {
  if (!utils.includes(signal)) throw new Error(`Missing efficient-run policy signal: ${signal}`);
}

if (!utils.includes("EFFICIENT_AGENT_RUN_POLICY")) {
  throw new Error("Efficient-run policy must be a named reusable product contract");
}
if (!utils.includes("${EFFICIENT_AGENT_RUN_POLICY}")) {
  throw new Error("Mode transition note must inject the efficient-run policy into every agent turn");
}
if (!host.includes("modeStatement: buildModeTransitionNote(")) {
  throw new Error("Host chat dispatch must continue routing the mode statement to Mahayana");
}
if (!host.includes('kind: "event" as const') || !host.includes('kind: "schedule" as const')) {
  throw new Error("Automation UI must retain both event and schedule triggers");
}
if (!host.includes('type: "connector.list"')) {
  throw new Error("Host must continue discovering connectors for connector-first execution");
}

console.log("efficient agent run policy contract: ok");
