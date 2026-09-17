import test from "node:test";
import assert from "node:assert/strict";
import { marketplaceUpdateCandidates } from "../chrome-platform/extension/marketplace-update-check.js";

const item = (version, digest = "remote-digest") => ({
  pluginId: "chatgpt-auto-confirm",
  displayName: "ChatGPT 自动确认",
  latestVersion: version,
  install: {
    source: { sourceRef: "a".repeat(40) },
    artifacts: [{ runtime: "userscript", format: "user-js", sha256: digest }],
  },
});

test("background Marketplace checker reports a newer installed userscript", () => {
  const updates = marketplaceUpdateCandidates([item("2.9.30")], [{
    sourcePluginId: "chatgpt-auto-confirm",
    sourcePluginVersion: "2.9.28",
    sourceArtifactSha256: "old-digest",
  }]);
  assert.deepEqual(updates.map(({ pluginId, installedVersion, latestVersion, reason }) => ({ pluginId, installedVersion, latestVersion, reason })), [{
    pluginId: "chatgpt-auto-confirm",
    installedVersion: "2.9.28",
    latestVersion: "2.9.30",
    reason: "version",
  }]);
});

test("background Marketplace checker notices a same-version artifact replacement but not a downgrade", () => {
  const digestUpdate = marketplaceUpdateCandidates([item("2.9.30", "new-digest")], [{
    sourcePluginId: "chatgpt-auto-confirm",
    sourcePluginVersion: "2.9.30",
    sourceArtifactSha256: "old-digest",
  }]);
  assert.equal(digestUpdate[0]?.reason, "artifact-digest");
  assert.deepEqual(marketplaceUpdateCandidates([item("2.9.29")], [{
    sourcePluginId: "chatgpt-auto-confirm",
    sourcePluginVersion: "2.9.30",
  }]), []);
});
