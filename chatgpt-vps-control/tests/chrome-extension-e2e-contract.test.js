import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repositoryRoot = resolve(packageRoot, "..");
const workflowPath = resolve(repositoryRoot, ".github/workflows/chrome-extension-web-store.yml");
const postMainWorkflowPath = resolve(repositoryRoot, ".github/workflows/post-main-delivery.yml");
const journeyPath = resolve(packageRoot, "scripts/chrome-extension-e2e.mjs");

test("Chrome packaged journey retains canonical visual and trace evidence", async () => {
  const workflow = await readFile(workflowPath, "utf8");
  const postMainWorkflow = await readFile(postMainWorkflowPath, "utf8");
  const journey = await readFile(journeyPath, "utf8");
  assert.match(workflow, /Run packaged Chrome simulated-user journey/);
  assert.match(workflow, /xvfb-run -a npm run chrome:e2e/);
  assert.match(workflow, /if: always\(\)/);
  assert.match(workflow, /retention-days: 90/);
  for (const artifact of ["evidence/**", "*.content-manifest.json", "*.zip"]) assert.match(workflow, new RegExp(artifact.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  for (const checkpoint of [
    "01-startup-fixture.png",
    "02-fabushi-shell.png",
    "03-browser-view.png",
    "05-after-browser-control.png",
    "06-cdp-screenshot.png",
    "trace.zip",
    "journey-report.json",
    "playwright-report.html",
  ]) assert.match(journey, new RegExp(checkpoint.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  for (const event of ["stale-generation-rejected", "claim-tab", "cdp-evaluate", "cdp-screenshot", "tab-action", "detach", "complete"]) assert.match(journey, new RegExp(event));
  assert.match(journey, /sourceSha/);
  assert.match(journey, /runId/);
  assert.match(postMainWorkflow, /wait-chrome/);
  assert.match(postMainWorkflow, /chrome-extension-web-store\.yml\/runs\?head_sha=/);
  assert.match(postMainWorkflow, /fabushi-chrome-web-store-\$\{\{ needs\.gate\.outputs\.source_sha \}\}/);
  assert.match(postMainWorkflow, /fabushi-chrome-SHA256SUMS\.txt/);
  assert.match(postMainWorkflow, /jq -r '\.sourceSha'/);
});
