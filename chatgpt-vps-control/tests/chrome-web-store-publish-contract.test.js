import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repositoryRoot = resolve(packageRoot, "..");
const workflowPath = resolve(repositoryRoot, ".github/workflows/chrome-extension-web-store-publish.yml");

test("Chrome Web Store publication is exact-source, redacted, and review-aware", async () => {
  const workflow = await readFile(workflowPath, "utf8");
  for (const needle of [
    "workflow_dispatch:",
    "source_sha:",
    "actions/download-artifact@v8",
    "fabushi-chrome-web-store-${{ inputs.source_sha }}",
    "https://chromewebstore.googleapis.com/upload/v2/",
    ":upload",
    ":fetchStatus",
    ":publish",
    '"skipReview":false',
    "CHROME_WEBSTORE_REFRESH_TOKEN",
    "CHROME_WEBSTORE_CLIENT_SECRET",
    "if: always()",
    "retention-days: 90",
  ]) assert.match(workflow, new RegExp(needle.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")), needle);
  assert.doesNotMatch(workflow, /echo\s+.*(?:access_token|refresh_token|client_secret)/i);
  assert.match(workflow, /publishedItemRevisionStatus\.state/);
  assert.match(workflow, /PENDING_REVIEW/);
});
