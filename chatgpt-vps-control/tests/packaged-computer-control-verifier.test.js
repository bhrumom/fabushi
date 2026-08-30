import test from "node:test";
import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { verifyPackagedComputerControl } from "../../.github/scripts/verify-packaged-computer-control.mjs";

const here = dirname(fileURLToPath(import.meta.url));
let runtimeId = "";
let sourceHash = "";
const required = [
  "bin/chatgpt-computer-control.js",
  "bin/fabushi-computer-mcp.js",
  "bin/fabushi-remote-mcp.js",
  "bin/fabushi-device-agent.js",
  "bin/fabushi-ci-account-login.js",
  "lib/fabushi-remote-mcp-server.js",
  "lib/fabushi-account-auth.js",
  "lib/device-agent.js",
  "lib/fabushi-account-session.js",
  "lib/ci-session-tools.js",
  "lib/app-agent-surface-client.js",
  "lib/app-agent-surface-client.d.ts",
  "lib/app-agent-tools.js",
  "extension/manifest.json",
  "lib/fabushi-computer-policy.js",
  "native/linux/accessibility-helper.py",
  "native/macos/ComputerHelper.swift",
  "native/macos/Info.plist",
  "native/macos/RequestService-Info.plist",
  "native/windows/computer-helper.ps1",
  "scripts/browser-extension-host.mjs",
  "node_modules/@modelcontextprotocol/sdk/package.json",
  "node_modules/ws/package.json",
  "node_modules/zod/package.json",
];
const tools = [
  "computer_environment",
  "computer_applications",
  "computer_app_state",
  "computer_browser_session",
  "computer_browser_utility",
  "computer_browser_snapshot",
  "computer_browser_locator",
  "computer_browser_cua",
  "computer_elements",
  "computer_element_action",
  "computer_element_secondary_action",
  "computer_state",
  "computer_window",
  "computer_use",
  "computer_use_bridge",
  "fabushi.app.status",
  "fabushi.app.snapshot",
  "fabushi.app.find",
  "fabushi.app.action",
  "fabushi.app.wait",
  "fabushi.app.assert",
  "computer_control_route",
];

async function hashEntry(hash, root, relativePath) {
  const { lstat, readFile, readlink, readdir } = await import("node:fs/promises");
  const path = join(root, relativePath);
  const metadata = await lstat(path);
  if (metadata.isSymbolicLink()) {
    hash.update(`L\0${relativePath}\0${await readlink(path)}\0`);
    return;
  }
  if (metadata.isDirectory()) {
    hash.update(`D\0${relativePath}\0`);
    const entries = await readdir(path, { withFileTypes: true });
    for (const entry of entries.sort((left, right) => left.name.localeCompare(right.name))) {
      await hashEntry(hash, root, join(relativePath, entry.name));
    }
    return;
  }
  hash.update(`F\0${relativePath}\0`);
  hash.update(await readFile(path));
  hash.update("\0");
}

async function fixtureSourceHash(root) {
  const hash = createHash("sha256");
  hash.update("chatgpt-computer-control-runtime-v1\0");
  for (const entry of ["bin", "extension", "lib", "native", "scripts", "skills", "computer-use.js", "server.js", "package.json", "package-lock.json"]) {
    await hashEntry(hash, root, entry);
  }
  return hash.digest("hex");
}

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), "fabushi-package-verifier-test-"));
  const releaseRoot = join(root, "release");
  const resources = join(releaseRoot, "linux-unpacked", "resources");
  const bundle = join(resources, "computer-control");
  const stagingRuntime = join(bundle, "runtime", "staging");
  await mkdir(stagingRuntime, { recursive: true });
  for (const relativePath of required) {
    const path = join(stagingRuntime, relativePath);
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, `fixture:${relativePath}\n`);
  }
  for (const relativePath of ["skills/.keep", "computer-use.js", "server.js"]) {
    const path = join(stagingRuntime, relativePath);
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, `fixture:${relativePath}\n`);
  }
  await writeFile(join(stagingRuntime, "package.json"), `${JSON.stringify({ type: "module" })}\n`);
  await writeFile(join(stagingRuntime, "package-lock.json"), `${JSON.stringify({ lockfileVersion: 3 })}\n`);
  const mcpEntry = join(stagingRuntime, "bin", "fabushi-computer-mcp.js");
  await writeFile(mcpEntry, `
let buffer = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  buffer += chunk;
  while (buffer.includes("\\n")) {
    const index = buffer.indexOf("\\n");
    const line = buffer.slice(0, index).trim();
    buffer = buffer.slice(index + 1);
    if (!line) continue;
    const message = JSON.parse(line);
    if (message.id === 1) {
      process.stdout.write(JSON.stringify({jsonrpc:"2.0",id:1,result:{protocolVersion:"2024-11-05",capabilities:{},serverInfo:{name:"fixture",version:"1"}}}) + "\\n");
    } else if (message.id === 2) {
      process.stdout.write(JSON.stringify({jsonrpc:"2.0",id:2,result:{tools:${JSON.stringify(tools)}.map((name) => ({name}))}}) + "\\n");
    }
  }
});
`);
  sourceHash = await fixtureSourceHash(stagingRuntime);
  runtimeId = `v1-${sourceHash.slice(0, 20)}`;
  const runtime = join(bundle, "runtime", runtimeId);
  const { rename } = await import("node:fs/promises");
  await rename(stagingRuntime, runtime);
  await writeFile(join(bundle, "active-runtime.json"), `${JSON.stringify({ runtimeId })}\n`);
  await writeFile(join(runtime, "runtime-manifest.json"), `${JSON.stringify({ layoutVersion: 1, runtimeId, sourceHash })}\n`);
  const packagedExecutable = join(releaseRoot, "linux-unpacked", "fabushi");
  await writeFile(packagedExecutable, "fixture executable\n");
  await chmod(packagedExecutable, 0o700);
  return { root, releaseRoot, bundle, runtime, mcpEntry };
}

async function cleanup(value) {
  await rm(value.root, { recursive: true, force: true });
}

test("packaged Computer Use verifier accepts a complete content-addressed runtime", async () => {
  const value = await fixture();
  try {
    const result = await verifyPackagedComputerControl({
      releaseRoot: value.releaseRoot,
      platform: "linux",
      skipHandshake: true,
    });
    assert.equal(result.runtimeId, runtimeId);
    assert.equal(result.sourceHash, sourceHash);
    assert.equal(result.toolNames.length, 0);
  } finally {
    await cleanup(value);
  }
});

test("packaged Computer Use verifier rejects a stale active pointer", async () => {
  const value = await fixture();
  try {
    await writeFile(join(value.bundle, "active-runtime.json"), `${JSON.stringify({ runtimeId: "v1-ffffffffffffffffffff" })}\n`);
    await assert.rejects(
      verifyPackagedComputerControl({ releaseRoot: value.releaseRoot, platform: "linux", skipHandshake: true }),
      /runtime manifest|ENOENT/,
    );
  } finally {
    await cleanup(value);
  }
});

test("packaged Computer Use verifier rejects runtime content tampering", async () => {
  const value = await fixture();
  try {
    await writeFile(join(value.runtime, "computer-use.js"), "tampered\n");
    await assert.rejects(
      verifyPackagedComputerControl({ releaseRoot: value.releaseRoot, platform: "linux", skipHandshake: true }),
      /runtime hash mismatch/,
    );
  } finally {
    await cleanup(value);
  }
});

test("packaged Computer Use verifier performs a private MCP tools handshake", async () => {
  const value = await fixture();
  try {
    const result = await verifyPackagedComputerControl({
      releaseRoot: value.releaseRoot,
      platform: "linux",
      executableOverride: process.execPath,
      skipHandshake: false,
    });
    assert.deepEqual([...result.toolNames].sort(), [...tools].sort());
  } finally {
    await cleanup(value);
  }
});
