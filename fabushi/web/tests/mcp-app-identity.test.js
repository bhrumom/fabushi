import assert from "node:assert/strict";
import test from "node:test";
import { createMcpAppIdentity, isDeployed, isSourceHosted } from "../src/domain/mcp-app-identity.js";

test("source hosted does not imply deployed", () => {
  const identity = createMcpAppIdentity({
    appId: "app-1",
    pluginId: "io.test.app",
    authorSubjectId: "author-1",
    sourceHost: "github",
    sourceCustody: "platform-managed",
    sourceProvider: "github",
    repositoryId: 123,
    officialStatus: "community",
    runtimeProfile: "local-web",
    lineageId: "lineage-1",
  });
  assert.equal(isSourceHosted(identity), true);
  assert.equal(isDeployed(identity), false);
});

test("deployment is independent from source identity", () => {
  const identity = createMcpAppIdentity({
    appId: "app-2",
    pluginId: "io.test.app",
    authorSubjectId: "author-2",
    sourceHost: "local",
    sourceCustody: "device",
    hostingProvider: "cloudflare-pages",
    deploymentTarget: "pages-project",
    runtimeProfile: "remote-edge",
    lineageId: "lineage-2",
  });
  assert.equal(isSourceHosted(identity), false);
  assert.equal(isDeployed(identity), true);
});
