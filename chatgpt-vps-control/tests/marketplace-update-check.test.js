import test from "node:test";
import assert from "node:assert/strict";
import { normalizeUserScript } from "../chrome-platform/extension/userscript-core.js";
import { marketplaceUpdateCandidates, userscriptUpdateCandidate } from "../chrome-platform/extension/marketplace-update-check.js";

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

test("userscript update URL wins over a stale Marketplace catalog version", () => {
  const source = (version) => `// ==UserScript==\n// @name       Demo\n// @namespace  https://example.test/demo\n// @version    ${version}\n// @match      https://chatgpt.com/*\n// @grant      none\n// ==/UserScript==\n(() => {})();`;
  const current = normalizeUserScript(source("2.9.35"), { sourcePluginId: "chatgpt-auto-confirm" });
  const remote = normalizeUserScript(source("2.9.37"), { sourcePluginId: "chatgpt-auto-confirm" });
  const candidate = userscriptUpdateCandidate({ pluginId: "chatgpt-auto-confirm", latestVersion: "2.9.35" }, current, remote, {
    updateURL: "https://raw.githubusercontent.com/example/demo/main/demo.user.js",
    downloadURL: "https://raw.githubusercontent.com/example/demo/main/demo.user.js",
    source: remote.source,
  });
  assert.equal(candidate.installedVersion, "2.9.35");
  assert.equal(candidate.latestVersion, "2.9.37");
  assert.equal(candidate.reason, "update-url");
});

test("userscript metadata accepts Tampermonkey-style update and download URLs", () => {
  const record = normalizeUserScript(`// ==UserScript==\n// @name       Demo\n// @namespace  https://example.test/demo\n// @version    1.0.0\n// @updateURL  https://raw.githubusercontent.com/example/demo/main/demo.user.js\n// @downloadURL https://raw.githubusercontent.com/example/demo/main/demo.user.js\n// @match      https://chatgpt.com/*\n// @grant      none\n// ==/UserScript==\n(() => {})();`);
  assert.equal(record.updateURL, "https://raw.githubusercontent.com/example/demo/main/demo.user.js");
  assert.equal(record.downloadURL, "https://raw.githubusercontent.com/example/demo/main/demo.user.js");
  assert.throws(() => normalizeUserScript(record.source.replace("https://raw.githubusercontent.com", "http://raw.githubusercontent.com")), /HTTPS URL/);
});
