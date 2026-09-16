#!/usr/bin/env node

import { createHash, randomUUID } from "node:crypto";
import { cp, mkdir, open, readFile, readdir, rm, stat } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const SERVICE_NAME = "fabushi-marketplace-security-gate";
const SIGNER_KEY_ID = "fabushi-marketplace-security-2026-09";
const REQUIRED_CHECKS = ["malware", "dynamicSandbox", "secrets", "dependencies"];
const DEFAULT_API_BASE_URL = "https://api.ombhrum.com";
const DEFAULT_POLL_INTERVAL_MS = 60_000;
const DEFAULT_COMMAND_TIMEOUT_MS = 15 * 60_000;
const MAX_REPORT_BYTES = 128 * 1024;
const MAX_BUNDLE_BYTES = 64 * 1024;
const MAX_PACKAGE_BYTES = 100 * 1024 * 1024;
const ALLOWED_INITIAL_ARTIFACT_HOSTS = new Set([
  "github.com",
  "raw.githubusercontent.com",
  "codeload.github.com",
]);
const ALLOWED_REDIRECT_ARTIFACT_HOSTS = new Set([
  "release-assets.githubusercontent.com",
  "objects.githubusercontent.com",
]);
const SAFE_ENV_PATH = "/usr/local/bin:/usr/bin:/bin";
const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROBE_PATH = resolve(SCRIPT_DIR, "../../scripts/marketplace-sandbox-probe.mjs");
const EXTRACTOR_PATH = resolve(SCRIPT_DIR, "safe-extract.py");

function fail(message) {
  throw new Error(message);
}

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) fail(`missing required configuration: ${name}`);
  return value;
}

function safeServerId(value) {
  if (!value || value.length > 128 || !/^[A-Za-z0-9._-]+$/.test(value)) {
    fail("MARKETPLACE_SECURITY_SERVER_ID must contain only safe identifier characters");
  }
  return value;
}

function gitObjectId(value) {
  return /^[0-9a-f]{40}$/i.test(value);
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function parsePositiveInteger(value, name, max) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isSafeInteger(parsed) || parsed <= 0 || parsed > max) {
    fail(`${name} is outside the permitted range`);
  }
  return parsed;
}

function imageConfig(name, fallback) {
  const value = process.env[name]?.trim() || fallback;
  if (!value.includes("@sha256:") || !/^.+@sha256:[0-9a-f]{64}$/i.test(value)) {
    fail(`${name} must use an immutable image digest`);
  }
  return value;
}

function versionConfig(name, fallback) {
  const value = process.env[name]?.trim() || fallback;
  if (!value || value.length > 80 || /[\u0000-\u001f\u007f]/.test(value)) {
    fail(`${name} is invalid`);
  }
  return value;
}

function buildConfig() {
  const apiBaseUrl = new URL(process.env.MARKETPLACE_SECURITY_API_BASE_URL?.trim() || DEFAULT_API_BASE_URL);
  if (apiBaseUrl.protocol !== "https:" || apiBaseUrl.username || apiBaseUrl.password || apiBaseUrl.port) {
    fail("MARKETPLACE_SECURITY_API_BASE_URL must be an HTTPS origin without credentials or a port");
  }
  const token = requiredEnv("MARKETPLACE_SECURITY_TOKEN");
  const serverId = safeServerId(requiredEnv("MARKETPLACE_SECURITY_SERVER_ID"));
  const sourceSha = requiredEnv("MARKETPLACE_SECURITY_SOURCE_SHA");
  if (!gitObjectId(sourceSha)) fail("MARKETPLACE_SECURITY_SOURCE_SHA must be a 40-character commit SHA");
  const workRoot = resolve(requiredEnv("MARKETPLACE_SECURITY_WORK_ROOT"));
  if (workRoot === "/" || workRoot.split("/").length < 4) {
    fail("MARKETPLACE_SECURITY_WORK_ROOT is too broad");
  }
  const privateKeyFile = resolve(requiredEnv("MARKETPLACE_COSIGN_PRIVATE_KEY_FILE"));
  const publicKeyFile = resolve(requiredEnv("MARKETPLACE_COSIGN_PUBLIC_KEY_FILE"));
  const passwordFile = process.env.MARKETPLACE_COSIGN_PASSWORD_FILE?.trim()
    ? resolve(process.env.MARKETPLACE_COSIGN_PASSWORD_FILE.trim())
    : null;
  const maxPackageBytes = parsePositiveInteger(
    process.env.MARKETPLACE_MAX_PACKAGE_BYTES || String(MAX_PACKAGE_BYTES),
    "MARKETPLACE_MAX_PACKAGE_BYTES",
    MAX_PACKAGE_BYTES,
  );
  const pollIntervalMs = parsePositiveInteger(
    process.env.MARKETPLACE_SECURITY_POLL_INTERVAL_MS || String(DEFAULT_POLL_INTERVAL_MS),
    "MARKETPLACE_SECURITY_POLL_INTERVAL_MS",
    15 * 60_000,
  );
  return {
    apiBaseUrl,
    token,
    serverId,
    sourceSha,
    workRoot,
    privateKeyFile,
    publicKeyFile,
    passwordFile,
    maxPackageBytes,
    pollIntervalMs,
    pythonCommand: process.env.MARKETPLACE_PYTHON_COMMAND?.trim() || "/usr/bin/python3",
    clamScanCommand: process.env.MARKETPLACE_CLAMSCAN_COMMAND?.trim() || "clamscan",
    freshClamCommand: process.env.MARKETPLACE_FRESHCLAM_COMMAND?.trim() || "freshclam",
    clamDatabaseDir: process.env.MARKETPLACE_CLAM_DATABASE_DIR?.trim() || null,
    dockerCommand: process.env.MARKETPLACE_DOCKER_COMMAND?.trim() || "docker",
    gitleaksImage: imageConfig(
      "MARKETPLACE_GITLEAKS_IMAGE",
      "zricethezav/gitleaks:v8.28.0@sha256:REPLACE_WITH_VERIFIED_DIGEST",
    ),
    syftImage: imageConfig(
      "MARKETPLACE_SYFT_IMAGE",
      "anchore/syft:v1.31.0@sha256:REPLACE_WITH_VERIFIED_DIGEST",
    ),
    osvImage: imageConfig(
      "MARKETPLACE_OSV_IMAGE",
      "ghcr.io/google/osv-scanner:v2.0.2@sha256:REPLACE_WITH_VERIFIED_DIGEST",
    ),
    nodeImage: imageConfig(
      "MARKETPLACE_NODE_IMAGE",
      "node:22-bookworm-slim@sha256:REPLACE_WITH_VERIFIED_DIGEST",
    ),
    gitleaksVersion: versionConfig("MARKETPLACE_GITLEAKS_VERSION", "8.28.0"),
    syftVersion: versionConfig("MARKETPLACE_SYFT_VERSION", "1.31.0"),
    osvVersion: versionConfig("MARKETPLACE_OSV_VERSION", "2.0.2"),
    nodeVersion: versionConfig("MARKETPLACE_NODE_VERSION", "22-bookworm-slim"),
  };
}

function apiUrl(config, path) {
  return new URL(path.replace(/^\//, ""), `${config.apiBaseUrl.toString().replace(/\/$/, "")}/`).toString();
}

async function readResponseTextLimited(response, maxBytes) {
  const chunks = [];
  let size = 0;
  for await (const chunk of response.body ?? []) {
    size += chunk.length;
    if (size > maxBytes) fail("response exceeds the service limit");
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString("utf8");
}

async function apiRequest(config, path, options = {}) {
  const headers = new Headers(options.headers || {});
  headers.set("Authorization", `Bearer ${config.token}`);
  headers.set("Accept", "application/json");
  if (options.body !== undefined) headers.set("Content-Type", "application/json");
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30_000);
  let response;
  try {
    response = await fetch(apiUrl(config, path), {
      ...options,
      headers,
      signal: controller.signal,
    });
  } catch (error) {
    throw new Error(`security API request failed: ${error instanceof Error ? error.name : "network"}`);
  } finally {
    clearTimeout(timeout);
  }
  const body = await readResponseTextLimited(response, 512 * 1024);
  if (!response.ok) {
    throw new Error(`security API returned HTTP ${response.status}`);
  }
  try {
    return body ? JSON.parse(body) : {};
  } catch {
    throw new Error("security API returned invalid JSON");
  }
}

function validateArtifactUrl(raw, { redirect = false } = {}) {
  let url;
  try {
    url = new URL(raw);
  } catch {
    fail("artifact URL is invalid");
  }
  if (url.protocol !== "https:" || url.username || url.password || url.port || url.hash) {
    fail("artifact URL must be HTTPS without credentials, ports, or fragments");
  }
  const host = url.hostname.toLowerCase();
  if (!ALLOWED_INITIAL_ARTIFACT_HOSTS.has(host) && !ALLOWED_REDIRECT_ARTIFACT_HOSTS.has(host)) {
    fail("artifact URL host is outside the GitHub allowlist");
  }
  if (url.search && !redirect) fail("initial artifact URL must not contain a query string");
  if (url.search && !ALLOWED_REDIRECT_ARTIFACT_HOSTS.has(host)) {
    fail("only GitHub signed redirect hosts may use query strings");
  }
  return url;
}

async function fetchArtifactResponse(rawUrl) {
  let current = validateArtifactUrl(rawUrl);
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60_000);
    let response;
    try {
      response = await fetch(current, {
        redirect: "manual",
        signal: controller.signal,
        headers: { Accept: "application/octet-stream" },
      });
    } catch (error) {
      throw new Error(`artifact download failed: ${error instanceof Error ? error.name : "network"}`);
    } finally {
      clearTimeout(timeout);
    }
    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get("location");
      if (!location) fail("GitHub artifact redirect has no location");
      current = validateArtifactUrl(new URL(location, current).toString(), { redirect: true });
      continue;
    }
    if (response.status < 200 || response.status >= 300) {
      throw new Error(`artifact origin returned HTTP ${response.status}`);
    }
    return response;
  }
  fail("artifact redirect chain is too long");
}

async function writeArtifact(response, destination, expectedSize, expectedSha256, maxPackageBytes) {
  const declaredSize = Number.parseInt(response.headers.get("content-length") || "", 10);
  if (Number.isSafeInteger(declaredSize) && declaredSize !== expectedSize) {
    fail("artifact Content-Length does not match the immutable release metadata");
  }
  if (expectedSize <= 0 || expectedSize > maxPackageBytes) fail("artifact size is outside the service limit");
  const output = await open(destination, "wx", 0o600);
  const digest = createHash("sha256");
  let size = 0;
  try {
    for await (const chunk of response.body ?? []) {
      size += chunk.length;
      if (size > maxPackageBytes || size > expectedSize) fail("artifact exceeded its immutable size");
      digest.update(chunk);
      await output.write(chunk);
    }
  } finally {
    await output.close();
  }
  const actualSha256 = digest.digest("hex");
  if (size !== expectedSize || actualSha256 !== expectedSha256.toLowerCase()) {
    fail("artifact digest or size does not match the immutable release metadata");
  }
  return { size, sha256: actualSha256 };
}

function validIdentifier(value) {
  return typeof value === "string" && value.length > 0 && value.length <= 128 && /^[A-Za-z0-9._-]+$/.test(value);
}

function validVersion(value) {
  return typeof value === "string" && value.length > 0 && value.length <= 128 && /^[A-Za-z0-9._+\-]+$/.test(value);
}

function validDigest(value) {
  return typeof value === "string" && /^[0-9a-f]{64}$/i.test(value);
}

function validSize(value, max) {
  return Number.isSafeInteger(value) && value > 0 && value <= max;
}

function githubReleaseArtifactUrl(source) {
  if (source?.type === "https" && typeof source.url === "string") return source.url;
  if (source?.type !== "github-release") return null;
  if (typeof source.repository !== "string" || !/^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+$/.test(source.repository)) {
    return null;
  }
  if (typeof source.tag !== "string" || typeof source.asset !== "string") return null;
  if (!source.tag || !source.asset || /[\\/\r\n]/.test(source.tag) || /[\\/\r\n]/.test(source.asset)) return null;
  return `https://github.com/${source.repository}/releases/download/${encodeURIComponent(source.tag)}/${encodeURIComponent(source.asset)}`;
}

function releaseArtifacts(item, config) {
  let manifest;
  try {
    manifest = typeof item.releaseManifest === "object"
      ? item.releaseManifest
      : JSON.parse(item.releaseManifest || "{}");
  } catch {
    fail("release manifest is invalid JSON");
  }
  if (manifest?.pluginId !== item.pluginId || manifest?.version !== item.version) {
    fail("release manifest identity does not match the queued release");
  }
  const artifacts = Array.isArray(manifest?.artifacts) ? manifest.artifacts : [];
  const candidates = [];
  for (const artifact of artifacts) {
    const expectedSha256 = typeof artifact?.sha256 === "string" ? artifact.sha256.toLowerCase() : "";
    const expectedSize = artifact?.size;
    const url = githubReleaseArtifactUrl(artifact?.source);
    if (validDigest(expectedSha256) && validSize(expectedSize, config.maxPackageBytes) && url) {
      candidates.push({
        id: typeof artifact.id === "string" ? artifact.id : `artifact-${candidates.length + 1}`,
        url,
        expectedSha256,
        expectedSize,
      });
    }
  }
  if (validDigest(item.packageSha256) && validSize(item.packageSize, config.maxPackageBytes)) {
    const primaryUrl = typeof item.artifactUrl === "string" ? item.artifactUrl : "";
    if (!candidates.some((candidate) => candidate.expectedSha256 === item.packageSha256.toLowerCase())) {
      candidates.unshift({
        id: "primary",
        url: primaryUrl,
        expectedSha256: item.packageSha256.toLowerCase(),
        expectedSize: item.packageSize,
      });
    }
  }
  const unique = new Map();
  for (const candidate of candidates) unique.set(`${candidate.url}|${candidate.expectedSha256}`, candidate);
  const result = [...unique.values()];
  if (!result.some((candidate) => candidate.expectedSha256 === item.packageSha256.toLowerCase())) {
    fail("release manifest does not contain the primary immutable artifact");
  }
  return result;
}

function commandEnvironment(extra = {}) {
  return {
    PATH: SAFE_ENV_PATH,
    HOME: "/var/empty",
    TMPDIR: "/tmp",
    NODE_OPTIONS: "",
    ...extra,
  };
}

async function runCommand(command, args, {
  cwd,
  env = {},
  timeoutMs = DEFAULT_COMMAND_TIMEOUT_MS,
} = {}) {
  return new Promise((resolveResult) => {
    const child = spawn(command, args, {
      cwd,
      env: commandEnvironment(env),
      shell: false,
      stdio: ["ignore", "ignore", "ignore"],
      detached: true,
    });
    let settled = false;
    const finish = (result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolveResult(result);
    };
    const timer = setTimeout(() => {
      try {
        process.kill(-child.pid, "SIGKILL");
      } catch {}
      finish({ ok: false, timedOut: true, exitCode: null });
    }, timeoutMs);
    child.once("error", () => finish({ ok: false, timedOut: false, exitCode: null }));
    child.once("exit", (code, signal) => finish({
      ok: code === 0 && !signal,
      timedOut: false,
      exitCode: code,
    }));
  });
}

function mountArgs(hostPath, containerPath, readOnly = true) {
  return ["--mount", `type=bind,src=${hostPath},dst=${containerPath}${readOnly ? ",readonly" : ""}`];
}

function containerSecurityArgs(config, network) {
  const uid = typeof process.getuid === "function" ? process.getuid() : 65532;
  const gid = typeof process.getgid === "function" ? process.getgid() : uid;
  return [
    "run",
    "--rm",
    "--pull=missing",
    "--network",
    network,
    "--read-only",
    "--cap-drop=ALL",
    "--security-opt=no-new-privileges:true",
    "--pids-limit",
    "128",
    "--memory",
    "768m",
    "--cpus",
    "1",
    "--user",
    `${uid}:${gid}`,
    "--tmpfs",
    "/tmp:rw,noexec,nosuid,nodev,size=64m",
  ];
}

async function runContainer(config, image, commandArgs, mounts, network, cwd) {
  const args = [...containerSecurityArgs(config, network)];
  for (const mount of mounts) args.push(...mountArgs(mount.host, mount.container, mount.readOnly));
  args.push(image, ...commandArgs);
  return runCommand(config.dockerCommand, args, { cwd, timeoutMs: DEFAULT_COMMAND_TIMEOUT_MS });
}

function check(status, tool, version) {
  return { status, tool, version };
}

function emptyChecks() {
  return {
    malware: check("blocked", "ClamAV", "host-managed"),
    dynamicSandbox: check("blocked", "Fabushi isolated probe", "1"),
    secrets: check("blocked", "Gitleaks", "unknown"),
    dependencies: check("blocked", "Syft + OSV-Scanner", "unknown"),
  };
}

async function refreshClam(config, state) {
  const now = Date.now();
  if (state.nextRefreshAt > now) return true;
  const result = await runCommand(config.freshClamCommand, [], { timeoutMs: 10 * 60_000 });
  if (!result.ok) return false;
  state.nextRefreshAt = now + 6 * 60 * 60_000;
  return true;
}

async function runClam(config, combinedDir, state) {
  if (!(await refreshClam(config, state))) return check("error", "ClamAV", "host-managed");
  const args = ["--no-summary", "--infected", "--recursive"];
  if (config.clamDatabaseDir) args.push(`--database=${config.clamDatabaseDir}`);
  args.push(combinedDir);
  const result = await runCommand(config.clamScanCommand, args);
  return check(result.ok ? "passed" : result.exitCode === 1 ? "failed" : "error", "ClamAV", "host-managed");
}

async function runGitleaks(config, combinedDir, cwd) {
  const result = await runContainer(
    config,
    config.gitleaksImage,
    ["detect", "--source=/src", "--no-banner", "--redact", "--exit-code=1"],
    [{ host: combinedDir, container: "/src", readOnly: true }],
    "none",
    cwd,
  );
  return check(result.ok ? "passed" : result.exitCode === 1 ? "failed" : "error", "Gitleaks", config.gitleaksVersion);
}

async function readJsonFile(path, maxBytes) {
  const content = await readFile(path);
  if (content.length > maxBytes) fail("scanner report exceeds the service limit");
  try {
    return JSON.parse(content.toString("utf8"));
  } catch {
    fail("scanner report is not valid JSON");
  }
}

function vulnerabilityCount(report) {
  let count = 0;
  for (const result of Array.isArray(report?.results) ? report.results : []) {
    if (Array.isArray(result?.vulnerabilities)) count += result.vulnerabilities.length;
    for (const pkg of Array.isArray(result?.packages) ? result.packages : []) {
      if (Array.isArray(pkg?.vulnerabilities)) count += pkg.vulnerabilities.length;
    }
  }
  return count;
}

async function runDependencies(config, combinedDir, reportDir, cwd) {
  const sbomPath = join(reportDir, "sbom.json");
  const syft = await runContainer(
    config,
    config.syftImage,
    ["/src", "-o", "cyclonedx-json=/out/sbom.json"],
    [
      { host: combinedDir, container: "/src", readOnly: true },
      { host: reportDir, container: "/out", readOnly: false },
    ],
    "none",
    cwd,
  );
  if (!syft.ok) return check(syft.timedOut ? "error" : "failed", "Syft + OSV-Scanner", `${config.syftVersion}+${config.osvVersion}`);
  try {
    const sbomStats = await stat(sbomPath);
    if (!sbomStats.isFile() || sbomStats.size === 0) return check("error", "Syft + OSV-Scanner", `${config.syftVersion}+${config.osvVersion}`);
  } catch {
    return check("error", "Syft + OSV-Scanner", `${config.syftVersion}+${config.osvVersion}`);
  }
  const osv = await runContainer(
    config,
    config.osvImage,
    ["scan", "source", "-r", "/src", "--format=json", "--output-file=/out/osv.json"],
    [
      { host: combinedDir, container: "/src", readOnly: true },
      { host: reportDir, container: "/out", readOnly: false },
    ],
    "bridge",
    cwd,
  );
  let report;
  try {
    report = await readJsonFile(join(reportDir, "osv.json"), 4 * 1024 * 1024);
  } catch {
    return check("error", "Syft + OSV-Scanner", `${config.syftVersion}+${config.osvVersion}`);
  }
  const vulnerabilities = vulnerabilityCount(report);
  if (vulnerabilities > 0) return check("failed", "Syft + OSV-Scanner", `${config.syftVersion}+${config.osvVersion}`);
  return check(osv.ok ? "passed" : "error", "Syft + OSV-Scanner", `${config.syftVersion}+${config.osvVersion}`);
}

async function runDynamic(config, extractedDirs, cwd) {
  for (const extractedDir of extractedDirs) {
    const result = await runContainer(
      config,
      config.nodeImage,
      ["node", "/probe.mjs", "/plugin"],
      [
        { host: extractedDir, container: "/plugin", readOnly: true },
        { host: PROBE_PATH, container: "/probe.mjs", readOnly: true },
      ],
      "none",
      cwd,
    );
    if (!result.ok) return check(result.timedOut ? "error" : "failed", "Fabushi isolated probe", "1");
  }
  return check("passed", "Fabushi isolated probe", "1");
}

async function extractArtifact(config, packagePath, destination, cwd) {
  const result = await runCommand(
    config.pythonCommand,
    [EXTRACTOR_PATH, packagePath, destination],
    { cwd, timeoutMs: 10 * 60_000 },
  );
  return result.ok;
}

async function scanArtifacts(config, item, workDir, clamState) {
  const checks = emptyChecks();
  const artifacts = releaseArtifacts(item, config);
  const combinedDir = join(workDir, "combined");
  const reportDir = join(workDir, "reports");
  const extractedDirs = [];
  await mkdir(combinedDir, { recursive: true, mode: 0o700 });
  await mkdir(reportDir, { recursive: true, mode: 0o700 });
  let primaryPackagePath = null;
  for (let index = 0; index < artifacts.length; index += 1) {
    const artifact = artifacts[index];
    const artifactDir = join(workDir, `artifact-${index}`);
    const packagePath = join(workDir, `package-${index}.bin`);
    const extractedDir = join(artifactDir, "files");
    await mkdir(artifactDir, { recursive: true, mode: 0o700 });
    try {
      const response = await fetchArtifactResponse(artifact.url);
      await writeArtifact(response, packagePath, artifact.expectedSize, artifact.expectedSha256, config.maxPackageBytes);
      if (artifact.expectedSha256 === item.packageSha256.toLowerCase()) primaryPackagePath = packagePath;
      if (!(await extractArtifact(config, packagePath, extractedDir, workDir))) {
        return { checks, primaryPackagePath: null, failure: "safe extraction failed" };
      }
      const combinedArtifactDir = join(combinedDir, `artifact-${index}`);
      await mkdir(combinedArtifactDir, { recursive: true, mode: 0o700 });
      const entries = await readdir(extractedDir, { withFileTypes: true });
      for (const entry of entries) {
        if (entry.isSymbolicLink()) return { checks, primaryPackagePath: null, failure: "extraction produced a symbolic link" };
        const source = join(extractedDir, entry.name);
        const target = join(combinedArtifactDir, entry.name);
        await cp(source, target, { recursive: true, errorOnExist: true });
      }
      extractedDirs.push(extractedDir);
    } catch (error) {
      return {
        checks,
        primaryPackagePath: null,
        failure: error instanceof Error ? error.message : "artifact preparation failed",
      };
    }
  }
  if (!primaryPackagePath) return { checks, primaryPackagePath: null, failure: "primary artifact was not prepared" };
  checks.malware = await runClam(config, combinedDir, clamState);
  checks.secrets = await runGitleaks(config, combinedDir, workDir);
  checks.dependencies = await runDependencies(config, combinedDir, reportDir, workDir);
  checks.dynamicSandbox = checks.malware.status === "passed"
    ? await runDynamic(config, extractedDirs, workDir)
    : check("blocked", "Fabushi isolated probe", "1");
  return { checks, primaryPackagePath, failure: null };
}

function allChecksPassed(checks) {
  return REQUIRED_CHECKS.every((name) => checks[name]?.status === "passed");
}

function serviceReport(config, item, scanRunId, checks, verdict, signature = {}) {
  return {
    schemaVersion: 1,
    pluginId: item.pluginId,
    version: item.version,
    packageSha256: item.packageSha256.toLowerCase(),
    packageSize: item.packageSize,
    scanRunId,
    verdict,
    checks,
    service: {
      serviceName: SERVICE_NAME,
      serverId: config.serverId,
      sourceSha: config.sourceSha,
      version: "1",
      scannerRunAt: Math.floor(Date.now() / 1000),
    },
    signature,
  };
}

async function signAndVerify(config, packagePath, packageSha256, packageSize, workDir) {
  const bundlePath = join(workDir, "cosign.bundle.json");
  const password = config.passwordFile ? (await readFile(config.passwordFile, "utf8")).trim() : "";
  const cosignEnv = password ? { COSIGN_PASSWORD: password } : {};
  const sign = await runCommand(
    "cosign",
    ["sign-blob", "--yes", "--tlog-upload=false", "--key", config.privateKeyFile, "--bundle", bundlePath, packagePath],
    { cwd: workDir, env: cosignEnv, timeoutMs: 5 * 60_000 },
  );
  if (!sign.ok) fail("Cosign signing failed");
  const verify = await runCommand(
    "cosign",
    ["verify-blob", "--insecure-ignore-tlog", "--key", config.publicKeyFile, "--bundle", bundlePath, packagePath],
    { cwd: workDir, env: cosignEnv, timeoutMs: 5 * 60_000 },
  );
  if (!verify.ok) fail("Cosign verification failed");
  const bundleBytes = await readFile(bundlePath);
  if (bundleBytes.length > MAX_BUNDLE_BYTES) fail("Cosign bundle exceeds the result limit");
  let bundle;
  try {
    bundle = JSON.parse(bundleBytes.toString("utf8"));
  } catch {
    fail("Cosign bundle is not valid JSON");
  }
  if (!bundle || typeof bundle !== "object" || Array.isArray(bundle)) fail("Cosign bundle is not an object");
  const publicKey = await readFile(config.publicKeyFile);
  return {
    type: "cosign-bundle",
    signerKeyId: SIGNER_KEY_ID,
    publicKeySha256: sha256(publicKey),
    packageSha256,
    packageSize,
    verified: true,
    bundle,
  };
}

async function postResult(config, report) {
  const body = JSON.stringify(report);
  if (Buffer.byteLength(body, "utf8") > MAX_REPORT_BYTES) fail("security result exceeds the Worker limit");
  return apiRequest(config, "/v1/marketplace/security/result", { method: "POST", body });
}

async function claim(config, item, scanRunId) {
  if (!validIdentifier(item.pluginId) || !validVersion(item.version) || !validDigest(item.packageSha256)
    || !validSize(item.packageSize, config.maxPackageBytes)) return null;
  try {
    const result = await apiRequest(config, "/v1/marketplace/security/claim", {
      method: "POST",
      body: JSON.stringify({ pluginId: item.pluginId, version: item.version, scanRunId }),
    });
    if (result?.claimed !== true) return null;
    if (result.packageSha256 && result.packageSha256.toLowerCase() !== item.packageSha256.toLowerCase()) return null;
    if (result.packageSize && result.packageSize !== item.packageSize) return null;
    return result;
  } catch (error) {
    if (error instanceof Error && error.message.includes("HTTP 409")) return null;
    throw error;
  }
}

async function processItem(config, item, clamState) {
  const scanRunId = `${config.serverId}-${Date.now()}-${randomUUID()}`;
  const claimed = await claim(config, item, scanRunId);
  if (!claimed) return;
  const workDir = join(config.workRoot, `run-${randomUUID()}`);
  await mkdir(workDir, { recursive: true, mode: 0o700 });
  let report;
  try {
    const result = await scanArtifacts(config, item, workDir, clamState);
    report = serviceReport(
      config,
      item,
      scanRunId,
      result.checks,
      allChecksPassed(result.checks) && result.primaryPackagePath ? "passed" : "failed",
    );
    if (report.verdict === "passed") {
      try {
        report.signature = await signAndVerify(
          config,
          result.primaryPackagePath,
          item.packageSha256.toLowerCase(),
          item.packageSize,
          workDir,
        );
      } catch {
        report.verdict = "failed";
      }
    }
  } catch {
    report = serviceReport(config, item, scanRunId, emptyChecks(), "failed");
  }
  try {
    await postResult(config, report);
  } finally {
    await rm(workDir, { recursive: true, force: true });
  }
}

async function runLoop(config) {
  await mkdir(config.workRoot, { recursive: true, mode: 0o700 });
  const clamState = { nextRefreshAt: 0 };
  let stopping = false;
  const stop = () => { stopping = true; };
  process.once("SIGTERM", stop);
  process.once("SIGINT", stop);
  while (!stopping) {
    try {
      const queue = await apiRequest(config, "/v1/marketplace/security/queue?limit=20");
      const releases = Array.isArray(queue?.releases) ? queue.releases : [];
      for (const item of releases) {
        if (stopping) break;
        try {
          await processItem(config, item, clamState);
        } catch (error) {
          // Do not print URLs, report bodies, tokens, scanner output, or secret values.
          process.stderr.write(`marketplace security item failed: ${error instanceof Error ? error.message : "unknown"}\n`);
        }
      }
    } catch (error) {
      process.stderr.write(`marketplace security poll failed: ${error instanceof Error ? error.message : "unknown"}\n`);
    }
    if (!stopping) await new Promise((resolvePromise) => setTimeout(resolvePromise, config.pollIntervalMs));
  }
}

try {
  const config = buildConfig();
  await runLoop(config);
} catch (error) {
  process.stderr.write(`marketplace security service stopped: ${error instanceof Error ? error.message : "unknown"}\n`);
  process.exitCode = 1;
}
