import { execFile } from "node:child_process";
import { createHash, generateKeyPairSync, randomBytes } from "node:crypto";
import { chmod, cp, mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir, platform } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { NATIVE_HOST_NAME, browserExtensionPaths } from "./browser-extension-paths.js";
import { installLocalRuntime } from "./local-install.js";

const execFileAsync = promisify(execFile);
const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
export const CHROME_PLATFORM_NATIVE_HOST_NAME = "com.fabushi.chrome_platform";

function extensionIdFromPublicKey(publicKey) {
  const digest = createHash("sha256").update(Buffer.from(publicKey, "base64")).digest().subarray(0, 16);
  return [...digest].flatMap((byte) => [byte >> 4, byte & 15]).map((nibble) => String.fromCharCode(97 + nibble)).join("");
}

function shellQuote(value) {
  return `'${String(value).replaceAll("'", `'"'"'`)}'`;
}

export function nativeManifestDestinations(currentPlatform = platform()) {
  const home = homedir();
  if (process.env.COMPUTER_BROWSER_NATIVE_MANIFEST_DIR) {
    return [{ browser: "custom", directory: resolve(process.env.COMPUTER_BROWSER_NATIVE_MANIFEST_DIR) }];
  }
  if (currentPlatform === "darwin") return [
    { browser: "chrome", directory: join(home, "Library/Application Support/Google/Chrome/NativeMessagingHosts") },
    { browser: "chromium", directory: join(home, "Library/Application Support/Chromium/NativeMessagingHosts") },
    { browser: "edge", directory: join(home, "Library/Application Support/Microsoft Edge/NativeMessagingHosts") },
  ];
  if (currentPlatform === "linux") return [
    { browser: "chrome", directory: join(home, ".config/google-chrome/NativeMessagingHosts") },
    { browser: "chromium", directory: join(home, ".config/chromium/NativeMessagingHosts") },
    { browser: "edge", directory: join(home, ".config/microsoft-edge/NativeMessagingHosts") },
  ];
  return [{ browser: "windows", directory: browserExtensionPaths().home }];
}

async function readJson(path) {
  try { return JSON.parse(await readFile(path, "utf8")); } catch { return null; }
}

async function ensureSecret(path) {
  try {
    const current = (await readFile(path, "utf8")).trim();
    if (current.length >= 32) return current;
  } catch {}
  const secret = randomBytes(32).toString("base64url");
  await writeFile(path, `${secret}\n`, { mode: 0o600 });
  return secret;
}

async function installWindowsRegistry(manifests) {
  for (const manifest of manifests) {
    for (const product of ["Google\\Chrome", "Microsoft\\Edge"]) {
      const key = `HKCU\\Software\\${product}\\NativeMessagingHosts\\${manifest.name}`;
      await execFileAsync("reg.exe", ["ADD", key, "/ve", "/t", "REG_SZ", "/d", manifest.path, "/f"]);
    }
  }
}

async function writeLauncher(currentPlatform, launcherPath, hostScript, home) {
  if (currentPlatform === "win32") {
    await writeFile(launcherPath, `@echo off\r\nset "COMPUTER_BROWSER_EXTENSION_HOME=${home}"\r\n"${process.execPath}" "${hostScript}"\r\n`, { mode: 0o700 });
    return;
  }
  await writeFile(launcherPath, `#!/bin/sh\nexport COMPUTER_BROWSER_EXTENSION_HOME=${shellQuote(home)}\nexec ${shellQuote(process.execPath)} ${shellQuote(hostScript)}\n`, { mode: 0o700 });
  await chmod(launcherPath, 0o700);
}

export async function installBrowserExtension({ currentPlatform = platform(), manifestDestinations, runtimeInstaller = installLocalRuntime } = {}) {
  const paths = browserExtensionPaths();
  const runtime = await runtimeInstaller();
  await mkdir(paths.home, { recursive: true, mode: 0o700 });
  await ensureSecret(paths.secret);
  let metadata = await readJson(paths.metadata);
  if (!metadata?.publicKey) {
    const { publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
    metadata = { publicKey: publicKey.export({ type: "spki", format: "der" }).toString("base64") };
  }
  metadata.extensionId = extensionIdFromPublicKey(metadata.publicKey);
  metadata.installedAt = new Date().toISOString();

  // Chrome is a first-class Fabushi platform. Keep the legacy extension source
  // in the repository for migration/history, but install the independent
  // chrome-platform application package.
  const runtimeRoot = runtime.root || packageRoot;
  await cp(join(runtimeRoot, "chrome-platform", "extension"), paths.extension, { recursive: true, force: true });
  const extensionManifestPath = join(paths.extension, "manifest.json");
  const extensionManifest = JSON.parse(await readFile(extensionManifestPath, "utf8"));
  extensionManifest.key = metadata.publicKey;
  await writeFile(extensionManifestPath, `${JSON.stringify(extensionManifest, null, 2)}\n`, { mode: 0o600 });

  const browserLauncher = paths.launcher;
  const platformLauncher = join(paths.home, currentPlatform === "win32" ? "chrome-platform-host.cmd" : "chrome-platform-host");
  const browserHostScript = runtime.browserHostPath || join(runtimeRoot, "scripts", "browser-extension-host.mjs");
  const platformHostScript = join(runtimeRoot, "scripts", "chrome-platform-host.mjs");
  await writeLauncher(currentPlatform, browserLauncher, browserHostScript, paths.home);
  await writeLauncher(currentPlatform, platformLauncher, platformHostScript, paths.home);

  const allowedOrigins = [`chrome-extension://${metadata.extensionId}/`];
  const nativeHosts = [
    {
      name: NATIVE_HOST_NAME,
      description: "Fabushi bridge for controlling the Chrome browser the user already has open",
      path: browserLauncher,
      type: "stdio",
      allowed_origins: allowedOrigins,
    },
    {
      name: CHROME_PLATFORM_NATIVE_HOST_NAME,
      description: "Fabushi Chrome platform bridge to the signed-in desktop Host",
      path: platformLauncher,
      type: "stdio",
      allowed_origins: allowedOrigins,
    },
  ];

  const destinations = manifestDestinations || nativeManifestDestinations(currentPlatform);
  const installedManifests = [];
  for (const destination of destinations) {
    await mkdir(destination.directory, { recursive: true, mode: 0o700 });
    for (const nativeHost of nativeHosts) {
      const target = join(destination.directory, `${nativeHost.name}.json`);
      await writeFile(target, `${JSON.stringify(nativeHost, null, 2)}\n`, { mode: 0o600 });
      installedManifests.push({ browser: destination.browser, name: nativeHost.name, path: target });
    }
  }

  if (currentPlatform === "win32" && !manifestDestinations && !process.env.COMPUTER_BROWSER_NATIVE_MANIFEST_DIR) {
    await installWindowsRegistry(nativeHosts.map((host) => ({ name: host.name, path: join(paths.home, `${host.name}.json`) })));
  }

  await writeFile(paths.metadata, `${JSON.stringify({
    ...metadata,
    platform: "chrome-extension",
    platformVersion: extensionManifest.version,
    manifests: installedManifests,
  }, null, 2)}\n`, { mode: 0o600 });
  return {
    ...paths,
    extensionId: metadata.extensionId,
    manifests: installedManifests,
    platformLauncher,
    runtime: runtime.root ?? null,
  };
}

export async function browserExtensionStatus() {
  const paths = browserExtensionPaths();
  const metadata = await readJson(paths.metadata);
  const manifest = await readJson(join(paths.extension, "manifest.json"));
  return {
    installed: Boolean(metadata?.extensionId && manifest?.key),
    platform: metadata?.platform ?? null,
    version: manifest?.version ?? null,
    extensionId: metadata?.extensionId ?? null,
    extensionPath: paths.extension,
    manifests: metadata?.manifests ?? [],
  };
}
