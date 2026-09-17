#!/usr/bin/env node

import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { runAppAgentCiSmoke } from "../lib/app-agent-ci-smoke.js";

const reportPath = String(process.env.FABUSHI_APP_AGENT_SMOKE_REPORT || "").trim();

async function persist(payload) {
  if (!reportPath) return;
  const target = resolve(reportPath);
  await mkdir(dirname(target), { recursive: true });
  await writeFile(target, `${JSON.stringify(payload, null, 2)}\n`, { mode: 0o600 });
}

try {
  const result = await runAppAgentCiSmoke();
  await persist(result);
  process.stdout.write(`Fabushi Action-owned App Agent smoke passed: route=${result.route || "unknown"}, screen=${result.screen || "unknown"}, generation=${result.finalGeneration ?? "unknown"}.\n`);
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  await persist({
    schema: "fabushi.app-agent-ci-smoke.v1",
    ok: false,
    error: message.slice(0, 1000),
    completedAt: new Date().toISOString(),
  });
  process.stderr.write(`Fabushi Action-owned App Agent smoke failed: ${message}\n`);
  process.exitCode = 1;
}
