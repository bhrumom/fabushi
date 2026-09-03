#!/usr/bin/env node

import { mkdir, rm, writeFile } from "node:fs/promises";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { installLocalRuntime, stageFabushiNativeHelper } from "../lib/local-install.js";

if (!process.env.CHATGPT_COMPUTER_HOME) {
  throw new Error("CHATGPT_COMPUTER_HOME must name the disposable Fabushi packaging directory.");
}

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const expectedBundleHome = join(repositoryRoot, "desktop", "resources", "computer-control");
const bundleHome = resolve(process.env.CHATGPT_COMPUTER_HOME);
if (relative(expectedBundleHome, bundleHome) !== "") {
  throw new Error(`CHATGPT_COMPUTER_HOME must be exactly ${expectedBundleHome}; refusing destructive cleanup of ${bundleHome}.`);
}
await rm(bundleHome, { recursive: true, force: true });
await mkdir(bundleHome, { recursive: true });

const runtime = await installLocalRuntime();
await writeFile(join(bundleHome, "active-runtime.json"), `${JSON.stringify({ runtimeId: runtime.runtimeId })}\n`, { mode: 0o600 });
const native = await stageFabushiNativeHelper({
  codesignIdentity: process.env.CHATGPT_COMPUTER_CODESIGN_IDENTITY || "",
  teamIdentifier: process.env.CHATGPT_COMPUTER_TEAM_ID || "",
});

process.stdout.write(`${JSON.stringify({ runtime: runtime.root, runtimeId: runtime.runtimeId, native })}\n`);
