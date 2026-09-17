import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const read = (path) => readFile(new URL(path, root), "utf8");

test("iOS package-reuse bootstrap dispatches the exact existing package once from canonical main", async () => {
  const workflow = await read(".github/workflows/ios-interactive-package-reuse-bootstrap.yml");
  for (const required of [
    "branches: [main]",
    "'.github/workflows/ios-interactive-package-reuse-bootstrap.yml'",
    "actions: write",
    "contents: read",
    "gh workflow run ios-interactive-package-reuse-e2e.yml",
    "--ref main",
    "ORIGIN_RUN_ID: '34030851007'",
    "PACKAGE_SOURCE_SHA: '6872793daf727c118510e818e3cd689c09101594'",
    '-f "origin_run_id=$ORIGIN_RUN_ID"',
    '-f "package_source_sha=$PACKAGE_SOURCE_SHA"',
  ]) assert.ok(workflow.includes(required), `missing package-reuse bootstrap invariant: ${required}`);

  assert.equal(workflow.match(/\bgh\s+workflow\s+run\b/gu)?.length, 1,
    "bootstrap must dispatch exactly one workflow run");
  assert.doesNotMatch(workflow, /cargo\s+build|xcodebuild|xcodegen|fabushi-device-agent|\bKRIS\b/u,
    "bootstrap must only dispatch the canonical reuse workflow and never build/register a device itself");
});
