import assert from "node:assert/strict";
import test from "node:test";

import {
  compareMarketplaceVersions,
  marketplaceInstallAction,
  marketplaceInstallContract,
  marketplaceItemKind,
  marketplaceItemInstallable,
  marketplacePackageArtifact,
  marketplaceUpdateAvailable,
  marketplaceUserscriptArtifact,
} from "../chrome-platform/extension/marketplace-install.js";

const packageItem = {
  pluginId: "github-miniapp",
  latestVersion: "1.2.0",
  installMode: "package",
  releaseManifest: {
    artifacts: [{
      id: "universal",
      format: "tar-gz",
      sha256: "a".repeat(64),
    }],
  },
};

test("marketplace version comparison treats stable releases as newer than prereleases", () => {
  assert.equal(compareMarketplaceVersions("1.2.0", "1.1.9"), 1);
  assert.equal(compareMarketplaceVersions("1.2.0", "1.2.0-beta"), 1);
  assert.equal(compareMarketplaceVersions("v1.2.0", "1.2.0"), 0);
});

test("package marketplace items expose one install/update state machine", () => {
  assert.equal(marketplaceItemKind(packageItem), "package");
  assert.equal(marketplacePackageArtifact(packageItem).id, "universal");
  assert.equal(marketplaceInstallAction(packageItem, null, null), "install");
  assert.equal(marketplaceInstallAction(packageItem, { version: "1.1.0", artifactSha256: "b".repeat(64) }, null), "update");
  assert.equal(marketplaceUpdateAvailable(packageItem, { version: "1.2.0", artifactSha256: "b".repeat(64) }, null), true);
  assert.equal(marketplaceInstallAction(packageItem, { version: "1.3.0", artifactSha256: "c".repeat(64) }, null), "blocked");
  assert.equal(marketplaceInstallAction(packageItem, { version: "1.2.0", artifactSha256: "b".repeat(64) }, null), "reinstall");
});

test("package marketplace items require the shared GitHub install contract", () => {
  assert.equal(marketplaceItemInstallable(packageItem), false);
  const item = {
    ...packageItem,
    install: {
      protocol: "fabushi.marketplace.install.v1",
      strategy: "github-immutable",
      pluginId: "github-miniapp",
      version: "1.2.0",
      source: {
        repository: "https://github.com/example/example-tool",
        sourceRef: "a".repeat(40),
        marketplaceHostsPackage: false,
      },
      artifacts: [{ id: "universal", sha256: "a".repeat(64), size: 10, source: { type: "https", url: "https://raw.githubusercontent.com/example/example-tool/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/app.tar.gz" } }],
      update: { allowDowngrade: false },
    },
  };
  assert.equal(marketplaceItemInstallable(item), true);
  assert.equal(marketplaceInstallContract(item).strategy, "github-immutable");
});

test("userscript surfaces take precedence over package fallback state", () => {
  const item = {
    ...packageItem,
    surfaces: [{ id: "userscript", kind: "userscript", entry: "script.user.js" }],
  };
  assert.equal(marketplaceItemKind(item), "userscript");
  assert.equal(marketplaceInstallAction(item, null, null), "install");
  assert.equal(marketplaceInstallAction(item, null, { version: "1.2.0" }), "current");
});

test("userscript marketplace artifacts participate in digest-aware updates", () => {
  const item = {
    pluginId: "github-userscript",
    latestVersion: "2.0.0",
    surfaces: [{ id: "userscript", kind: "userscript", entry: "script.user.js" }],
    install: {
      protocol: "fabushi.marketplace.install.v1",
      strategy: "github-immutable",
      pluginId: "github-userscript",
      version: "2.0.0",
      source: {
        repository: "https://github.com/example/userscript",
        sourceRef: "a".repeat(40),
        marketplaceHostsPackage: false,
      },
      artifacts: [{
        runtime: "userscript",
        format: "user-js",
        sha256: "c".repeat(64),
        size: 10,
        source: { type: "https", url: `https://raw.githubusercontent.com/example/userscript/${"a".repeat(40)}/script.user.js` },
      }],
      update: { allowDowngrade: false },
    },
  };
  assert.equal(marketplaceUserscriptArtifact(item).format, "user-js");
  assert.equal(marketplaceItemInstallable(item), true);
  assert.equal(
    marketplaceInstallAction(item, null, { version: "2.0.0", sourceArtifactSha256: "b".repeat(64) }),
    "reinstall",
  );
});
