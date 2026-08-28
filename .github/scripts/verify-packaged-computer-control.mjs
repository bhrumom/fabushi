#!/usr/bin/env node

import { spawn, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { lstat, mkdtemp, readFile, readlink, realpath, readdir, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, dirname, join, relative, resolve, sep } from "node:path";
import { pathToFileURL } from "node:url";

const RUNTIME_ID = /^v1-[a-f0-9]{20}$/;
const SOURCE_HASH = /^[a-f0-9]{64}$/;
const MAX_POINTER_BYTES = 16 * 1024;
const MAX_MANIFEST_BYTES = 64 * 1024;
const MAX_DISCOVERY_ENTRIES = 100_000;
const MAX_STDOUT_BYTES = 4 * 1024 * 1024;
const MCP_TIMEOUT_MS = 20_000;
const HASH_ENTRIES = Object.freeze([
  "bin",
  "extension",
  "lib",
  "native",
  "scripts",
  "skills",
  "computer-use.js",
  "server.js",
  "package.json",
  "package-lock.json",
]);
const REQUIRED_RUNTIME_FILES = Object.freeze([
  "bin/chatgpt-computer-control.js",
  "bin/fabushi-computer-mcp.js",
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
]);
const EXPECTED_TOOLS = Object.freeze([
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
]);

function fail(message) {
  throw new Error(message);
}

function parseArguments(argv) {
  const options = { releaseRoot: "", platform: "", skipHandshake: false, expectedTeam: "" };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--release-root") options.releaseRoot = argv[++index] || "";
    else if (argument === "--platform") options.platform = argv[++index] || "";
    else if (argument === "--expected-mac-team") options.expectedTeam = argv[++index] || "";
    else if (argument === "--skip-handshake") options.skipHandshake = true;
    else fail(`Unknown argument: ${argument}`);
  }
  options.releaseRoot = resolve(options.releaseRoot || ".");
  if (!["mac", "win", "linux"].includes(options.platform)) {
    fail("--platform must be mac, win, or linux");
  }
  if (options.expectedTeam && !/^[A-Z0-9]{10}$/.test(options.expectedTeam)) {
    fail("--expected-mac-team must be a ten-character Apple Team ID");
  }
  return options;
}

async function readBoundedJson(path, maximumBytes, description) {
  const metadata = await stat(path);
  if (!metadata.isFile() || metadata.size <= 0 || metadata.size > maximumBytes) {
    fail(`${description} has an invalid size: ${path}`);
  }
  try {
    return JSON.parse(await readFile(path, "utf8"));
  } catch (error) {
    fail(`${description} is not valid JSON: ${path}: ${error.message}`);
  }
}

function isWithin(parent, candidate) {
  const child = relative(resolve(parent), resolve(candidate));
  return child === "" || (child !== ".." && !child.startsWith(`..${sep}`));
}

async function findFiles(root, expectedName) {
  const matches = [];
  let visited = 0;
  async function visit(directory) {
    const entries = await readdir(directory, { withFileTypes: true });
    for (const entry of entries) {
      visited += 1;
      if (visited > MAX_DISCOVERY_ENTRIES) fail(`Package discovery exceeded ${MAX_DISCOVERY_ENTRIES} entries`);
      const path = join(directory, entry.name);
      if (entry.isSymbolicLink()) continue;
      if (entry.isDirectory()) await visit(path);
      else if (entry.isFile() && entry.name === expectedName) matches.push(path);
    }
  }
  await visit(root);
  return matches;
}

async function hashRuntimeEntry(hash, root, relativePath, counter) {
  counter.count += 1;
  if (counter.count > MAX_DISCOVERY_ENTRIES) fail(`Runtime hash exceeded ${MAX_DISCOVERY_ENTRIES} entries`);
  const absolutePath = join(root, relativePath);
  const metadata = await lstat(absolutePath);
  if (metadata.isSymbolicLink()) {
    hash.update(`L\0${relativePath}\0${await readlink(absolutePath)}\0`);
    return;
  }
  if (metadata.isDirectory()) {
    hash.update(`D\0${relativePath}\0`);
    const entries = await readdir(absolutePath, { withFileTypes: true });
    for (const entry of entries.sort((left, right) => left.name.localeCompare(right.name))) {
      if (entry.name === ".DS_Store") continue;
      await hashRuntimeEntry(hash, root, join(relativePath, entry.name), counter);
    }
    return;
  }
  if (!metadata.isFile()) return;
  // Permission bits are normalized by staging, packaging, and platform filesystems.
  // Verify the runtime contents and layout, not transport-specific file modes.
  hash.update(`F\0${relativePath}\0`);
  hash.update(await readFile(absolutePath));
  hash.update("\0");
}

async function recomputeRuntimeSourceHash(runtimeRoot) {
  const hash = createHash("sha256");
  hash.update("chatgpt-computer-control-runtime-v1\0");
  const counter = { count: 0 };
  for (const entry of HASH_ENTRIES) await hashRuntimeEntry(hash, runtimeRoot, entry, counter);
  return hash.digest("hex");
}

async function requireRegularFile(root, relativePath) {
  const path = resolve(root, relativePath);
  if (!isWithin(root, path)) fail(`Runtime path escapes its root: ${relativePath}`);
  const canonicalRoot = await realpath(root);
  const canonical = await realpath(path);
  if (!isWithin(canonicalRoot, canonical)) fail(`Runtime file resolves outside its root: ${relativePath}`);
  const metadata = await stat(canonical);
  if (!metadata.isFile() || metadata.size <= 0) fail(`Missing or empty packaged runtime file: ${relativePath}`);
  return canonical;
}

async function locateOuterExecutable(resourcesRoot, platform) {
  if (platform === "mac") {
    const contents = dirname(resourcesRoot);
    const macOS = join(contents, "MacOS");
    const candidates = [];
    for (const entry of await readdir(macOS, { withFileTypes: true })) {
      if (entry.isFile() && !entry.name.startsWith(".")) candidates.push(join(macOS, entry.name));
    }
    if (candidates.length !== 1) fail(`Expected one outer macOS executable, found ${candidates.length}`);
    return candidates[0];
  }
  const path = join(dirname(resourcesRoot), platform === "win" ? "fabushi.exe" : "fabushi");
  const metadata = await stat(path);
  if (!metadata.isFile()) fail(`Missing packaged Electron executable: ${path}`);
  return path;
}

function codeSignatureDetails(path) {
  const result = spawnSync("codesign", ["-dv", "--verbose=4", path], { encoding: "utf8" });
  if (result.status !== 0) fail(`Unable to inspect code signature for ${path}: ${result.stderr || result.stdout}`);
  const output = `${result.stdout || ""}\n${result.stderr || ""}`;
  const team = output.match(/^TeamIdentifier=(.+)$/m)?.[1]?.trim() || "";
  const identifier = output.match(/^Identifier=(.+)$/m)?.[1]?.trim() || "";
  return { team, identifier };
}

function verifyMacSignatures({ appRoot, helperApp, helper, requestService, expectedTeam }) {
  for (const path of [appRoot, helperApp, requestService]) {
    const result = spawnSync("codesign", ["--verify", "--deep", "--strict", "--verbose=2", path], { encoding: "utf8" });
    if (result.status !== 0) fail(`Invalid packaged macOS signature for ${path}: ${result.stderr || result.stdout}`);
  }
  const app = codeSignatureDetails(appRoot);
  const helperDetails = codeSignatureDetails(helper);
  const requestDetails = codeSignatureDetails(requestService);
  if (!app.team || app.team === "not set") fail("Outer macOS app has no stable TeamIdentifier");
  if (helperDetails.team !== app.team || requestDetails.team !== app.team) {
    fail(`Computer Use helper TeamIdentifier does not match outer app (${app.team})`);
  }
  if (expectedTeam && app.team !== expectedTeam) fail(`Outer app TeamIdentifier ${app.team} does not match ${expectedTeam}`);
  if (helperDetails.identifier !== "com.ombhrum.fabushi.computer-control") {
    fail(`Unexpected Computer Use helper identifier: ${helperDetails.identifier}`);
  }
  if (requestDetails.identifier !== "com.ombhrum.fabushi.computer-control.request-service") {
    fail(`Unexpected Computer Use request-service identifier: ${requestDetails.identifier}`);
  }
}

async function inspectPackage({ releaseRoot, platform, expectedTeam }) {
  const pointerMatches = (await findFiles(releaseRoot, "active-runtime.json"))
    .filter((path) => basename(dirname(path)) === "computer-control");
  if (pointerMatches.length !== 1) {
    fail(`Expected exactly one packaged Computer Use active pointer, found ${pointerMatches.length}`);
  }
  const pointerPath = pointerMatches[0];
  const bundleHome = dirname(pointerPath);
  const resourcesRoot = dirname(bundleHome);
  const pointer = await readBoundedJson(pointerPath, MAX_POINTER_BYTES, "Computer Use active pointer");
  const runtimeId = String(pointer?.runtimeId || "");
  if (!RUNTIME_ID.test(runtimeId)) fail(`Invalid packaged Computer Use runtime ID: ${runtimeId}`);
  const runtimeBase = resolve(bundleHome, "runtime");
  const runtimeRoot = resolve(runtimeBase, runtimeId);
  if (!isWithin(runtimeBase, runtimeRoot) || basename(runtimeRoot) !== runtimeId) fail("Packaged runtime path is unsafe");
  const manifest = await readBoundedJson(join(runtimeRoot, "runtime-manifest.json"), MAX_MANIFEST_BYTES, "Computer Use runtime manifest");
  const sourceHash = String(manifest?.sourceHash || "");
  if (manifest?.layoutVersion !== 1
    || manifest?.runtimeId !== runtimeId
    || !SOURCE_HASH.test(sourceHash)
    || runtimeId !== `v1-${sourceHash.slice(0, 20)}`) {
    fail("Packaged Computer Use runtime manifest does not match the active content ID");
  }
  for (const relativePath of REQUIRED_RUNTIME_FILES) await requireRegularFile(runtimeRoot, relativePath);
  const actualSourceHash = await recomputeRuntimeSourceHash(runtimeRoot);
  if (actualSourceHash !== sourceHash) {
    fail(`Packaged Computer Use runtime hash mismatch: expected ${sourceHash}, got ${actualSourceHash}`);
  }

  let nativeHelper = "";
  if (platform === "mac") {
    const helperApp = join(bundleHome, "Applications", "Fabushi Computer Control.app");
    const helper = await requireRegularFile(helperApp, "Contents/MacOS/FabushiComputerControl");
    const requestService = await requireRegularFile(
      helperApp,
      "Contents/XPCServices/com.ombhrum.fabushi.computer-control.request-service.xpc/Contents/MacOS/FabushiComputerRequestService",
    );
    const appRoot = dirname(dirname(resourcesRoot));
    verifyMacSignatures({ appRoot, helperApp, helper, requestService, expectedTeam });
    nativeHelper = helper;
  } else if (platform === "win") {
    nativeHelper = await requireRegularFile(bundleHome, "native/computer-helper.ps1");
  } else {
    nativeHelper = await requireRegularFile(runtimeRoot, "native/linux/accessibility-helper.py");
  }

  const executable = await locateOuterExecutable(resourcesRoot, platform);
  return {
    releaseRoot,
    platform,
    resourcesRoot,
    bundleHome,
    runtimeRoot,
    runtimeId,
    sourceHash,
    executable,
    mcpEntry: join(runtimeRoot, "bin", "fabushi-computer-mcp.js"),
    nativeHelper,
  };
}

async function verifyMcpHandshake(packageState) {
  const privateHome = await mkdtemp(join(tmpdir(), "fabushi-packaged-computer-control-"));
  let child;
  try {
    child = spawn(packageState.executable, [packageState.mcpEntry], {
      cwd: packageState.runtimeRoot,
      env: {
        ...process.env,
        ELECTRON_RUN_AS_NODE: "1",
        CHATGPT_COMPUTER_HOME: privateHome,
        CHATGPT_COMPUTER_NATIVE_HELPER: packageState.nativeHelper,
        FABUSHI_COMPUTER_POLICY_FILE: join(privateHome, "missing-policy.json"),
      },
      stdio: ["pipe", "pipe", "pipe"],
      windowsHide: true,
    });
    let stdout = "";
    let stderr = "";
    let initialized = false;
    let settled = false;
    let timer;
    const finish = (resolvePromise, rejectPromise, error, value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (child && !child.killed) child.kill();
      if (error) rejectPromise(error);
      else resolvePromise(value);
    };
    const result = await new Promise((resolvePromise, rejectPromise) => {
      timer = setTimeout(() => {
        finish(resolvePromise, rejectPromise, new Error(`Packaged MCP handshake timed out. stderr=${stderr.slice(-4000)}`));
      }, MCP_TIMEOUT_MS);
      const consume = () => {
        while (stdout.includes("\n")) {
          const newline = stdout.indexOf("\n");
          const line = stdout.slice(0, newline).trim();
          stdout = stdout.slice(newline + 1);
          if (!line.startsWith("{")) continue;
          let message;
          try { message = JSON.parse(line); }
          catch { continue; }
          if (message.id === 1) {
            if (message.error) return finish(resolvePromise, rejectPromise, new Error(`MCP initialize failed: ${JSON.stringify(message.error)}`));
            if (initialized) continue;
            initialized = true;
            child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" })}\n`);
            child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id: 2, method: "tools/list", params: {} })}\n`);
          } else if (message.id === 2) {
            if (message.error) return finish(resolvePromise, rejectPromise, new Error(`MCP tools/list failed: ${JSON.stringify(message.error)}`));
            const names = Array.isArray(message.result?.tools)
              ? message.result.tools.map((tool) => String(tool?.name || "")).filter(Boolean)
              : [];
            const missing = EXPECTED_TOOLS.filter((name) => !names.includes(name));
            if (missing.length) return finish(resolvePromise, rejectPromise, new Error(`Packaged MCP is missing tools: ${missing.join(", ")}`));
            return finish(resolvePromise, rejectPromise, null, names);
          }
        }
      };
      child.stdout.setEncoding("utf8");
      child.stderr.setEncoding("utf8");
      child.stdout.on("data", (chunk) => {
        stdout += chunk;
        if (Buffer.byteLength(stdout) > MAX_STDOUT_BYTES) {
          finish(resolvePromise, rejectPromise, new Error("Packaged MCP produced excessive stdout"));
          return;
        }
        consume();
      });
      child.stderr.on("data", (chunk) => { stderr = `${stderr}${chunk}`.slice(-16_384); });
      child.stdin.on("error", (error) => finish(resolvePromise, rejectPromise, error));
      child.on("error", (error) => finish(resolvePromise, rejectPromise, error));
      child.on("exit", (code, signal) => {
        if (!settled) finish(resolvePromise, rejectPromise, new Error(`Packaged MCP exited before tools/list (code=${code}, signal=${signal}). stderr=${stderr}`));
      });
      child.stdin.write(`${JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: "2024-11-05",
          capabilities: {},
          clientInfo: { name: "fabushi-package-verifier", version: "1.0.0" },
        },
      })}\n`);
    });
    return result;
  } finally {
    if (child && !child.killed) child.kill();
    await rm(privateHome, { recursive: true, force: true }).catch(() => {});
  }
}

export async function verifyPackagedComputerControl(options) {
  const state = await inspectPackage(options);
  if (options.executableOverride) {
    const executable = resolve(options.executableOverride);
    const metadata = await stat(executable);
    if (!metadata.isFile()) fail(`Executable override is not a file: ${executable}`);
    state.executable = executable;
  }
  const toolNames = options.skipHandshake ? [] : await verifyMcpHandshake(state);
  return { ...state, toolNames };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const options = parseArguments(process.argv.slice(2));
    const result = await verifyPackagedComputerControl(options);
    process.stdout.write(`${JSON.stringify({
      platform: result.platform,
      runtimeId: result.runtimeId,
      sourceHash: result.sourceHash,
      executable: result.executable,
      nativeHelper: result.nativeHelper,
      toolCount: result.toolNames.length,
    })}\n`);
  } catch (error) {
    process.stderr.write(`${error?.stack || error}\n`);
    process.exitCode = 1;
  }
}
