import { appendFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { isAbsolute, join, resolve } from "node:path";
import { z } from "zod";

const MAX_STATUS_BYTES = 64 * 1024;
const MAX_NOTE_CHARS = 2_000;

export function normalizeCiSessionDirectory(value, env = process.env) {
  const raw = String(value || "").trim();
  if (!raw) return "";
  if (env.GITHUB_ACTIONS !== "true") throw new Error("Fabushi CI session tools require GITHUB_ACTIONS=true.");
  if (!isAbsolute(raw)) throw new Error("FABUSHI_CI_SESSION_DIR must be absolute.");
  const directory = resolve(raw);
  const runnerTemp = String(env.RUNNER_TEMP || "").trim();
  if (runnerTemp) {
    const allowed = resolve(runnerTemp);
    if (directory !== allowed && !directory.startsWith(`${allowed}/`)) {
      throw new Error("FABUSHI_CI_SESSION_DIR must be inside RUNNER_TEMP.");
    }
  }
  return directory;
}

export async function readCiSessionStatus(directory) {
  const path = join(directory, "status.json");
  try {
    const raw = await readFile(path);
    if (raw.length > MAX_STATUS_BYTES) throw new Error("status file is too large");
    const status = JSON.parse(raw.toString("utf8"));
    if (!status || typeof status !== "object" || Array.isArray(status)) throw new Error("invalid status object");
    return {
      phase: String(status.phase || "unknown").slice(0, 100),
      message: String(status.message || "").slice(0, 2_000),
      appReady: status.appReady === true,
      appExecutable: String(status.appExecutable || "").slice(0, 1_000),
      deviceId: String(status.deviceId || "").slice(0, 128),
      runUrl: String(status.runUrl || "").slice(0, 1_000),
      updatedAt: String(status.updatedAt || "").slice(0, 100),
    };
  } catch (error) {
    if (error?.code === "ENOENT") {
      return { phase: "starting", message: "GitHub Actions session is starting.", appReady: false, appExecutable: "", deviceId: "", runUrl: "", updatedAt: "" };
    }
    throw error;
  }
}

export async function requestCiSessionFinish(directory, reason = "Remote MCP test completed") {
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const payload = {
    requestedAt: new Date().toISOString(),
    reason: String(reason || "Remote MCP test completed").trim().slice(0, 1_000),
  };
  await writeFile(join(directory, "finish-requested.json"), `${JSON.stringify(payload)}\n`, { encoding: "utf8", mode: 0o600 });
  return payload;
}

export async function appendCiSessionNote(directory, note) {
  const normalized = String(note || "").trim();
  if (!normalized || normalized.length > MAX_NOTE_CHARS) throw new Error(`note must contain 1-${MAX_NOTE_CHARS} characters`);
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const payload = { at: new Date().toISOString(), note: normalized };
  await appendFile(join(directory, "remote-notes.jsonl"), `${JSON.stringify(payload)}\n`, { encoding: "utf8", mode: 0o600 });
  return payload;
}

export function registerCiSessionTools(server, options = {}) {
  const env = options.env ?? process.env;
  const directory = normalizeCiSessionDirectory(options.directory ?? env.FABUSHI_CI_SESSION_DIR, env);
  if (!directory) return false;
  const allowed = options.allowed ?? (() => true);
  const denied = () => ({ isError: true, content: [{ type: "text", text: "Fabushi CI session control is not authorized by the local computer-control policy." }] });

  server.registerTool("ci_session_status", {
    title: "GitHub Actions interactive session status",
    description: "Read the current build, package, launch, and application-ready state for this temporary Fabushi GitHub Actions Runner.",
    inputSchema: {},
    outputSchema: {
      phase: z.string(), message: z.string(), appReady: z.boolean(), appExecutable: z.string(),
      deviceId: z.string(), runUrl: z.string(), updatedAt: z.string(),
    },
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
    securitySchemes: [],
  }, async () => {
    if (!allowed()) return denied();
    const status = await readCiSessionStatus(directory);
    return { structuredContent: status, content: [{ type: "text", text: `${status.phase}: ${status.message}` }] };
  });

  server.registerTool("ci_session_note", {
    title: "Record a GitHub Actions test note",
    description: "Append a short observation from the live remote test to the workflow evidence artifact.",
    inputSchema: { note: z.string().min(1).max(MAX_NOTE_CHARS) },
    outputSchema: { at: z.string(), note: z.string() },
    annotations: { readOnlyHint: false, destructiveHint: false, openWorldHint: false },
    securitySchemes: [],
  }, async ({ note }) => {
    if (!allowed()) return denied();
    const result = await appendCiSessionNote(directory, note);
    return { structuredContent: result, content: [{ type: "text", text: "Test note recorded in the workflow evidence." }] };
  });

  server.registerTool("ci_session_finish", {
    title: "Finish the GitHub Actions interactive session",
    description: "Signal that live MCP testing is complete so the temporary Runner can stop its hold loop, upload evidence, revoke its device lease, and finish.",
    inputSchema: { reason: z.string().min(1).max(1_000).optional() },
    outputSchema: { requestedAt: z.string(), reason: z.string() },
    annotations: { readOnlyHint: false, destructiveHint: true, openWorldHint: false },
    securitySchemes: [],
  }, async ({ reason }) => {
    if (!allowed()) return denied();
    const result = await requestCiSessionFinish(directory, reason);
    return { structuredContent: result, content: [{ type: "text", text: "The workflow will finish after collecting its current evidence." }] };
  });
  return true;
}
