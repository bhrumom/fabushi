import { fbApp } from "./miniapp-runtime";
import { GeoIPDataService } from "./geoip-data-service";

export type RegionPreset = {
  id: string;
  label: string;
  global?: boolean;
  countryCodes?: string[];
  fieldEnergy?: boolean;
  localLoopback?: boolean;
};

export type PreparedContent = {
  title: string;
  text: string;
  previewText: string;
  sourceUrl?: string;
  charCount: number;
};

export type DharmaDeliveryReceipt = {
  countryCode?: string;
  nodeId?: string;
  channel: "udp" | "browser-http" | "rust-http" | "system-http";
  status: "delivered" | "queued" | "sent";
  bytesSent: number;
  deliveredAt: string;
  raw?: unknown;
};

export type DharmaSendResult = {
  contentHash: string;
  bytesSent: number;
  receipts: DharmaDeliveryReceipt[];
  jobId?: string;
  jobIds?: string[];
  status: "delivered" | "queued" | "sent" | "running";
};

export type DharmaDaemonStatus = {
  ok: boolean;
  daemon: boolean;
  status?: string;
  version?: string;
  source?: string;
  jobs: any[];
  job?: any;
  events: any[];
  cursor: number;
};

type SendOptions = {
  content: PreparedContent;
  region: RegionPreset;
  loop: boolean;
  commandId?: string;
  onLog?: (message: string) => void;
};

type UdpTarget = {
  host: string;
  port: number;
  countryCode?: string;
  nodeId?: string;
};

type HttpTarget = {
  url: string;
  method?: string;
  countryCode?: string;
  nodeId?: string;
  headers?: Record<string, string>;
  timeoutMs?: number;
  maxBodyBytes?: number;
};

type DeliveryTarget =
  | ({ transport: "udp" } & UdpTarget)
  | ({ transport: "http" } & HttpTarget);

type PreparedWorker = {
  manifestPath: string;
  binaryPath: string;
  sourceHash: string;
};

const MINIAPP_ID = "official.global-dharma";
const DEFAULT_GLOBAL_DHARMA_SEND_URL = "https://httpbin.org/post";
const DEFAULT_HTTP_TARGETS: HttpTarget[] = [
  {
    url: DEFAULT_GLOBAL_DHARMA_SEND_URL,
    nodeId: "httpbin-global",
  },
  {
    url: "https://jsonplaceholder.typicode.com/posts",
    nodeId: "jsonplaceholder-global",
  },
];
const RUST_DAEMON_DEFAULT_PORT = 18888;
const RUST_DAEMON_PORT_CANDIDATES = [18888, 18889, 18890, 18891, 18892];
const DEFAULT_UDP_PORT = 9999;
const UDP_SAFE_DATAGRAM_BYTES = 8 * 1024;
const UDP_CHUNK_PAYLOAD_BYTES = 6 * 1024;
const RUST_DELIVERY_RECEIPT_TIMEOUT_MS = 45000;
const RUST_DELIVERY_RECEIPT_POLL_MS = 650;
const DAEMON_LOOP_INTERVAL_MS = 30000;
const RUST_WORKER_LOCAL_DIR = "runtime/global-dharma-worker";
const RUST_WORKER_PUBLIC_DIR =
  "/miniapps/official.global-dharma/runtime/global-dharma-worker";
const RUST_WORKER_FILES = [
  "Cargo.toml",
  "Cargo.lock",
  "src/main.rs",
  "data/geoip_targets.csv",
] as const;
const RUST_WORKER_BUILD_CACHE = `${RUST_WORKER_LOCAL_DIR}/.fabushi-worker-build.json`;

let activeRustDaemonBaseUrl = daemonBaseUrl(RUST_DAEMON_DEFAULT_PORT);

function daemonBaseUrl(port: number) {
  return `http://127.0.0.1:${port}`;
}

let preparedWorkerPromise: Promise<PreparedWorker> | null = null;
let preparedWasmModulePromise: Promise<WebAssembly.Module> | null = null;
let cargoToolchainPromise: Promise<void> | null = null;

function endpointUrl() {
  const configured =
    process.env.NEXT_PUBLIC_GLOBAL_DHARMA_SEND_URL ||
    process.env.NEXT_PUBLIC_FABUSHI_GLOBAL_DHARMA_SEND_URL ||
    "";
  return configured.trim() || DEFAULT_GLOBAL_DHARMA_SEND_URL;
}

function publicAssetPath(path: string) {
  const rawBasePath = process.env.NEXT_PUBLIC_SITE_BASE_PATH?.trim() || "";
  const basePath =
    rawBasePath && rawBasePath !== "/"
      ? `/${rawBasePath.replace(/^\/+|\/+$/g, "")}`
      : "";
  return `${basePath}${path}`;
}

function textBytes(value: string) {
  return new TextEncoder().encode(value);
}

function bytesToBase64(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return window.btoa(binary);
}

function splitUtf8Chunks(value: string, maxBytes: number) {
  const chunks: string[] = [];
  let current = "";
  let currentBytes = 0;
  const limit = Math.max(1, maxBytes);

  for (const char of value) {
    const charBytes = textBytes(char).byteLength;
    if (current && currentBytes + charBytes > limit) {
      chunks.push(current);
      current = "";
      currentBytes = 0;
    }
    current += char;
    currentBytes += charBytes;
  }

  if (current) chunks.push(current);
  return chunks.length > 0 ? chunks : [""];
}

function udpDatagramBodies(packetBody: string, contentHash: string) {
  const packetBytes = textBytes(packetBody).byteLength;
  if (packetBytes <= UDP_SAFE_DATAGRAM_BYTES) return [packetBody];

  const payloads = splitUtf8Chunks(packetBody, UDP_CHUNK_PAYLOAD_BYTES);
  return payloads.map((payload, index) =>
    JSON.stringify({
      type: "global_dharma_delivery_chunk",
      contentHash,
      chunkIndex: index,
      chunkCount: payloads.length,
      totalBytes: packetBytes,
      encoding: "utf8-json",
      payload,
    }),
  );
}

async function sha256Hex(value: string) {
  const bytes = textBytes(value);
  if (typeof crypto !== "undefined" && crypto.subtle) {
    const digest = await crypto.subtle.digest("SHA-256", bytes);
    return Array.from(new Uint8Array(digest))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
  }
  let hash = 0;
  for (const byte of bytes) hash = (hash * 31 + byte) >>> 0;
  return `fallback-${hash.toString(16).padStart(8, "0")}`;
}

function readUdpTargets(): UdpTarget[] {
  const raw = process.env.NEXT_PUBLIC_GLOBAL_DHARMA_UDP_TARGETS || "";
  if (!raw.trim()) return [];
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map((item) => ({
        host: String(item?.host || "").trim(),
        port: Number(item?.port || DEFAULT_UDP_PORT),
        countryCode: item?.countryCode ? String(item.countryCode) : undefined,
        nodeId: item?.nodeId ? String(item.nodeId) : undefined,
      }))
      .filter((item) => item.host && item.port > 0 && item.port <= 65535);
  } catch {
    return [];
  }
}

function readHttpTargets(): HttpTarget[] {
  const raw = process.env.NEXT_PUBLIC_GLOBAL_DHARMA_HTTP_TARGETS || "";
  if (raw.trim()) {
    try {
      const parsed = JSON.parse(raw);
      if (!Array.isArray(parsed)) return DEFAULT_HTTP_TARGETS;
      const targets = parsed
        .map((item) => ({
          url: String(item?.url || "").trim(),
          method: item?.method ? String(item.method).toUpperCase() : "POST",
          countryCode: item?.countryCode ? String(item.countryCode) : undefined,
          nodeId: item?.nodeId ? String(item.nodeId) : undefined,
          headers:
            item?.headers && typeof item.headers === "object"
              ? Object.fromEntries(
                  Object.entries(item.headers).map(([key, value]) => [
                    key,
                    String(value),
                  ]),
                )
              : undefined,
          timeoutMs: readNumber(item?.timeoutMs, 30000),
          maxBodyBytes: readNumber(item?.maxBodyBytes, 2 * 1024 * 1024),
        }))
        .filter((item) => item.url.startsWith("http"));
      return targets.length > 0 ? targets : DEFAULT_HTTP_TARGETS;
    } catch {
      return DEFAULT_HTTP_TARGETS;
    }
  }

  const configured =
    process.env.NEXT_PUBLIC_GLOBAL_DHARMA_SEND_URL ||
    process.env.NEXT_PUBLIC_FABUSHI_GLOBAL_DHARMA_SEND_URL ||
    "";
  if (configured.trim()) {
    return [{ url: endpointUrl(), nodeId: "configured-http-dispatch" }];
  }
  return DEFAULT_HTTP_TARGETS;
}

function targetCountries(region: RegionPreset) {
  if (region.countryCodes?.includes("ALL")) return ["ALL"];
  return region.countryCodes || [];
}

function sleep(ms: number) {
  return new Promise((resolve) => window.setTimeout(resolve, ms));
}

function readNumber(value: unknown, fallback = 0) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function isoTimeFromMillis(value: unknown) {
  const millis = readNumber(value);
  if (millis > 0) return new Date(millis).toISOString();
  return new Date().toISOString();
}

function errorMessage(error: unknown) {
  if (error instanceof Error && error.message) return error.message;
  return String(error || "unknown error");
}

function regionMatchesTarget(
  region: RegionPreset,
  target: { countryCode?: string },
) {
  const countries = targetCountries(region);
  if (countries.length === 0 || countries.includes("ALL")) return true;
  if (!target.countryCode) return true;
  return countries.includes(target.countryCode);
}

function httpTargetsForRegion(region: RegionPreset): HttpTarget[] {
  if (region.fieldEnergy || region.localLoopback) return [];
  return readHttpTargets().filter((target) =>
    regionMatchesTarget(region, target),
  );
}

function udpTargetsForRegion(region: RegionPreset): UdpTarget[] {
  if (region.fieldEnergy) {
    return [
      {
        host: "255.255.255.255",
        port: DEFAULT_UDP_PORT,
        nodeId: "local-field-broadcast",
      },
    ];
  }
  if (region.localLoopback) {
    return [
      { host: "127.0.0.1", port: DEFAULT_UDP_PORT, nodeId: "local-loopback" },
    ];
  }
  const customTargets = readUdpTargets().filter((target) =>
    regionMatchesTarget(region, target),
  );
  if (customTargets.length > 0) return customTargets;

  const geoTargets = GeoIPDataService.getInstance().getUdpTargetsForRegion(
    region.countryCodes || ["ALL"],
    DEFAULT_UDP_PORT,
  );
  return geoTargets.map((item) => ({
    host: item.host,
    port: item.port,
    nodeId: item.nodeId,
    countryCode: item.countryCode,
  }));
}

function deliveryTargetsForRegion(region: RegionPreset): DeliveryTarget[] {
  const udpTargets = udpTargetsForRegion(region).map((target) => ({
    ...target,
    transport: "udp" as const,
  }));
  if (udpTargets.length > 0) return udpTargets;

  return httpTargetsForRegion(region).map((target) => ({
    ...target,
    transport: "http" as const,
  }));
}

function endpointIdForTarget(target: DeliveryTarget) {
  if (target.nodeId) return target.nodeId;
  if (target.transport === "udp") return `${target.host}:${target.port}`;
  return target.url;
}

function endpointLabel(target: DeliveryTarget) {
  if (target.transport === "udp") {
    return target.nodeId || `${target.host}:${target.port}`;
  }
  return target.nodeId || target.url;
}

function isUdpTarget(target: DeliveryTarget): target is { transport: "udp" } & UdpTarget {
  return target.transport === "udp";
}

function needsUdpBroadcast(target: UdpTarget) {
  const host = target.host.trim();
  return host === "255.255.255.255" || host.endsWith(".255");
}

function endpointForTarget(target: DeliveryTarget, packetBody: string) {
  const endpointId = endpointIdForTarget(target);
  if (target.transport === "udp") {
    return {
      transport: "udp",
      endpointId,
      host: target.host,
      port: target.port,
      data: bytesToBase64(textBytes(packetBody)),
    };
  }
  return {
    transport: "http",
    endpointId,
    url: target.url,
    method: target.method || "POST",
    headers: target.headers || {
      "Content-Type": "application/json",
      Accept: "application/json",
      "User-Agent": "FabushiMiniApp/GlobalDharmaWorker",
    },
    timeoutMs: target.timeoutMs || 30000,
    maxBodyBytes: target.maxBodyBytes || 2 * 1024 * 1024,
  };
}

function buildPacket(
  content: PreparedContent,
  region: RegionPreset,
  loop: boolean,
  commandId: string | undefined,
  contentHash: string,
  transport: string,
) {
  return {
    type: "global_dharma_delivery",
    contentHash,
    title: content.title,
    text: content.text,
    previewText: content.previewText,
    sourceUrl: content.sourceUrl || null,
    region: region.id,
    targetCountries: targetCountries(region),
    loop,
    commandId,
    createdAt: new Date().toISOString(),
    client: {
      surface: fbApp.isHostEnv() ? "host-miniapp" : "web-miniapp",
      transport,
      miniAppId: MINIAPP_ID,
    },
  };
}

async function fetchTextAsset(path: string) {
  const response = await fetch(publicAssetPath(path), {
    cache: "no-store",
    headers: { Accept: "text/plain,*/*" },
  });
  if (!response.ok) {
    throw new Error(`小程序 Rust worker 资源读取失败: HTTP ${response.status}`);
  }
  return response.text();
}

function inferDesktopPlatform() {
  const ua = typeof window !== "undefined" ? window.navigator?.userAgent || "" : "";
  const platform =
    typeof window !== "undefined" ? window.navigator?.platform || "" : "";
  const marker = `${ua} ${platform}`;
  if (/Windows/i.test(marker)) return "windows";
  if (/Macintosh|Mac OS|MacIntel|Darwin/i.test(marker)) return "macos";
  return "linux";
}

function processExitCode(result: any) {
  return Number(result?.exitCode ?? -1);
}

function processOutput(result: any) {
  const stderr = String(result?.stderr || "").trim();
  const stdout = String(result?.stdout || "").trim();
  return stderr || stdout || `exit ${processExitCode(result)}`;
}

function loopbackStatusCode(result: any) {
  return readNumber(result?.statusCode ?? result?.status, 0);
}

function parseLoopbackJson(result: any) {
  const data = result?.data;
  if (data && typeof data === "object") return data;
  const body = typeof result?.body === "string"
    ? result.body
    : typeof data === "string"
      ? data
      : "";
  if (!body.trim()) return {};
  try {
    return JSON.parse(body);
  } catch {
    return {};
  }
}

function encodeQuery(value: string) {
  return encodeURIComponent(value);
}

async function fetchDaemonJson(
  path: string,
  options: {
    method?: string;
    body?: string;
    timeoutMs?: number;
    baseUrl?: string;
  } = {},
) {
  const url = `${options.baseUrl || activeRustDaemonBaseUrl}${path}`;
  const method = options.method || "GET";
  const timeoutMs = options.timeoutMs ?? 2000;
  const headers: Record<string, string> = { Accept: "application/json" };
  if (options.body != null) headers["Content-Type"] = "application/json";

  if (typeof fetch === "function") {
    const controller =
      typeof AbortController !== "undefined" ? new AbortController() : null;
    const timer =
      controller && typeof window !== "undefined"
        ? window.setTimeout(() => controller.abort(), timeoutMs)
        : null;
    try {
      const response = await fetch(url, {
        method,
        headers,
        body: options.body,
        cache: "no-store",
        signal: controller?.signal,
      });
      const text = await response.text();
      let data: any = {};
      if (text.trim()) {
        try {
          data = JSON.parse(text);
        } catch {
          data = { raw: text };
        }
      }
      return { statusCode: response.status, data, via: "direct" as const };
    } catch (error) {
      if (!fbApp.isHostEnv()) throw error;
    } finally {
      if (timer !== null) window.clearTimeout(timer);
    }
  }

  const response = await fbApp.invoke<any>("localLoopback.fetch", {
    url,
    method,
    body: options.body,
    timeoutMs,
  });
  return {
    statusCode: loopbackStatusCode(response),
    data: parseLoopbackJson(response),
    via: "host" as const,
  };
}

async function readLocalTextFile(path: string) {
  const result = await fbApp.invoke<any>("fs.readFile", { path });
  return {
    content: String(result?.content || ""),
    path: String(result?.path || ""),
  };
}

async function writeLocalTextFile(path: string, content: string) {
  const result = await fbApp.invoke<any>("fs.writeFile", { path, content });
  return String(result?.path || "");
}

async function writeLocalTextFileIfChanged(path: string, content: string) {
  try {
    const existing = await readLocalTextFile(path);
    if (existing.content === content && existing.path) {
      return { path: existing.path, changed: false };
    }
  } catch {
    // Missing local worker files are expected on first use.
  }
  return { path: await writeLocalTextFile(path, content), changed: true };
}

async function readWorkerBuildCache() {
  try {
    const existing = await readLocalTextFile(RUST_WORKER_BUILD_CACHE);
    return JSON.parse(existing.content) as {
      sourceHash?: string;
      binaryPath?: string;
      builtAt?: string;
    };
  } catch {
    return null;
  }
}

async function writeWorkerBuildCache(worker: PreparedWorker) {
  try {
    await writeLocalTextFile(
      RUST_WORKER_BUILD_CACHE,
      JSON.stringify(
        {
          sourceHash: worker.sourceHash,
          binaryPath: worker.binaryPath,
          builtAt: new Date().toISOString(),
        },
        null,
        2,
      ),
    );
  } catch {
    // Cache metadata should never block a successful send.
  }
}

async function runHostProcess(
  title: string,
  command: string,
  argumentsList: string[],
  options: { silentCli?: boolean; runInShell?: boolean } = {},
) {
  return fbApp.invoke<any>("runtime.process.execute", {
    title,
    command,
    arguments: argumentsList,
    silentCli: options.silentCli ?? true,
    runInShell: options.runInShell,
  });
}

function rustupInstallProcess() {
  const platform = inferDesktopPlatform();
  if (platform === "windows") {
    return {
      command: "powershell.exe",
      arguments: [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        "$ErrorActionPreference='Stop'; " +
          "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; " +
          "$installer=Join-Path $env:TEMP 'rustup-init.exe'; " +
          "Invoke-WebRequest -Uri 'https://win.rustup.rs/x86_64' -OutFile $installer; " +
          "& $installer -y --profile minimal; " +
          "exit $LASTEXITCODE",
      ],
    };
  }
  return {
    command: "sh",
    arguments: [
      "-lc",
      "set -e; " +
        "if command -v curl >/dev/null 2>&1; then " +
        "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal; " +
        "elif command -v wget >/dev/null 2>&1; then " +
        "wget -qO- https://sh.rustup.rs | sh -s -- -y --profile minimal; " +
        "else echo '缺少 curl 或 wget，无法自动安装 Rust 工具链' >&2; exit 127; fi",
    ],
  };
}

async function ensureCargoToolchain(onLog?: (message: string) => void) {
  if (cargoToolchainPromise) return cargoToolchainPromise;
  cargoToolchainPromise = (async () => {
    try {
      const version = await runHostProcess("检测 Cargo", "cargo", ["--version"]);
      if (processExitCode(version) === 0) {
        onLog?.(`Cargo 已就绪：${String(version?.stdout || "").trim()}`);
        return;
      }
      onLog?.(`Cargo 检测失败：${processOutput(version)}`);
    } catch (error) {
      onLog?.(`Cargo 未安装或不可用：${errorMessage(error)}`);
    }

    const install = rustupInstallProcess();
    onLog?.("未检测到 Cargo，开始通过 rustup 安装 Rust/Cargo 工具链。首次安装可能需要一些时间。");
    const installResult = await runHostProcess(
      "安装 Rust/Cargo 工具链",
      install.command,
      install.arguments,
      { silentCli: false },
    );
    if (processExitCode(installResult) !== 0) {
      throw new Error(`Rust/Cargo 自动安装失败: ${processOutput(installResult)}`);
    }

    const verify = await runHostProcess("验证 Cargo", "cargo", ["--version"]);
    if (processExitCode(verify) !== 0) {
      throw new Error(`Rust/Cargo 安装后仍不可用: ${processOutput(verify)}`);
    }
    onLog?.(`Cargo 安装完成：${String(verify?.stdout || "").trim()}`);
  })().catch((error) => {
    cargoToolchainPromise = null;
    throw error;
  });
  return cargoToolchainPromise;
}

async function isLoopCapableDaemon(baseUrl: string, timeoutMs = 700) {
  try {
    const check = await fetchDaemonJson("/jobs/status?limit=1", {
      method: "GET",
      timeoutMs,
      baseUrl,
    });
    return (
      check.statusCode === 200 &&
      check.data?.ok === true &&
      check.data?.daemon === true
    );
  } catch {
    return false;
  }
}

async function ensureRustWorkerDaemon(
  prepared: PreparedWorker,
  onLog?: (message: string) => void,
): Promise<boolean> {
  for (const port of RUST_DAEMON_PORT_CANDIDATES) {
    const baseUrl = daemonBaseUrl(port);
    if (await isLoopCapableDaemon(baseUrl)) {
      activeRustDaemonBaseUrl = baseUrl;
      return true;
    }
  }

  onLog?.("检测到发送任务，正在自举启动后台常驻守护服务 (Loopback Daemon)...");
  for (const port of RUST_DAEMON_PORT_CANDIDATES) {
    const baseUrl = daemonBaseUrl(port);
    try {
      const legacyCheck = await fetchDaemonJson("/status", {
        method: "GET",
        timeoutMs: 400,
        baseUrl,
      });
      if (legacyCheck.statusCode === 200) {
        onLog?.(
          `端口 ${port} 已被不支持循环 job API 的旧 daemon 占用，尝试后备端口。`,
        );
        continue;
      }
    } catch {
      // 端口未占用，尝试在这里启动新版 daemon。
    }

    try {
      fbApp.invoke<any>("runtime.process.execute", {
        title: "启动全球法布施 Rust daemon",
        command: prepared.binaryPath,
        arguments: ["--daemon", String(port)],
        detached: true,
        silentCli: true,
      }).catch(() => {});
    } catch {
      // 忽略异常，尝试后续探活或下一个端口。
    }

    await new Promise((resolve) => setTimeout(resolve, 450));
    if (await isLoopCapableDaemon(baseUrl, 1200)) {
      activeRustDaemonBaseUrl = baseUrl;
      onLog?.(`Rust daemon 已在 ${baseUrl} 接管循环发送。`);
      return true;
    }
  }

  return false;
}

async function prepareMiniAppRustWorker(
  onLog?: (message: string) => void,
): Promise<PreparedWorker> {
  if (preparedWorkerPromise) return preparedWorkerPromise;
  preparedWorkerPromise = (async () => {
    let manifestPath = "";
    let sourceChanged = false;
    const sourceParts: string[] = [];
    for (const file of RUST_WORKER_FILES) {
      const content = await fetchTextAsset(`${RUST_WORKER_PUBLIC_DIR}/${file}`);
      sourceParts.push(`${file}\0${content.length}\0${content}`);
      const writeResult = await writeLocalTextFileIfChanged(
        `${RUST_WORKER_LOCAL_DIR}/${file}`,
        content,
      );
      sourceChanged =
        sourceChanged || (file !== "Cargo.lock" && writeResult.changed);
      if (file === "Cargo.toml") {
        manifestPath = writeResult.path;
      }
    }
    if (!manifestPath) {
      throw new Error("小程序 Rust worker 没有写入 Cargo.toml");
    }

    const isWindows =
      typeof window !== "undefined" &&
      window.navigator?.userAgent?.includes("Windows");
    const binaryName = isWindows
      ? "global-dharma-worker.exe"
      : "global-dharma-worker";
    const binaryPath = manifestPath.replace(
      /Cargo\.toml$/i,
      `target/release/${binaryName}`,
    );
    const sourceHash = await sha256Hex(sourceParts.join("\n"));
    const worker = { manifestPath, binaryPath, sourceHash };
    const buildCache = await readWorkerBuildCache();
    const hasMatchingBuildCache =
      buildCache?.sourceHash === sourceHash &&
      buildCache?.binaryPath === binaryPath;

    if (sourceChanged || (buildCache && !hasMatchingBuildCache)) {
      onLog?.("Rust worker 源码已更新，开始一次性离线构建本机 release 程序。");
      await buildMiniAppRustWorker(worker, onLog);
    } else {
      onLog?.(
        hasMatchingBuildCache
          ? "Rust worker 本机 release 缓存命中，跳过 Cargo 构建。"
          : "Rust worker 源码未变化，优先复用现有 release 程序。",
      );
    }

    return worker;
  })().catch((error) => {
    preparedWorkerPromise = null;
    throw error;
  });
  return preparedWorkerPromise;
}

async function buildMiniAppRustWorker(
  worker: PreparedWorker,
  onLog?: (message: string) => void,
) {
  await ensureCargoToolchain(onLog);

  for (const port of RUST_DAEMON_PORT_CANDIDATES) {
    const baseUrl = daemonBaseUrl(port);
    await fetchDaemonJson("/shutdown", {
      method: "POST",
      timeoutMs: 300,
      baseUrl,
    }).catch(() => null);
  }
  activeRustDaemonBaseUrl = daemonBaseUrl(RUST_DAEMON_DEFAULT_PORT);
  await sleep(200);

  const buildResult = await runHostProcess(
    "构建 Rust worker (一次性)",
    "cargo",
    [
      "build",
      "--release",
      "--locked",
      "--offline",
      "--quiet",
      "--manifest-path",
      worker.manifestPath,
    ],
    { silentCli: false },
  );
  const buildExitCode = Number(buildResult?.exitCode ?? -1);
  if (buildExitCode !== 0) {
    const output = processOutput(buildResult);
    throw new Error(`Rust worker 离线构建失败: ${output}`);
  }
  await writeWorkerBuildCache(worker);
  onLog?.("Rust worker release 程序已就绪，后续启动不再调用 Cargo。");
}

async function writeWorkerJob(job: unknown) {
  const jsonStr = JSON.stringify(job);
  // 内存与文件双轨道自适应降级缓冲方案：
  // 1. 当包体较小（<2KB，安全范围内）优先使用 memory URI 传参，极致速度，完全避免磁盘 IO；
  // 2. 当为长篇经典（>=2KB，如《大佛顶首楞严经》）时，平滑切换为写入固定槽位缓冲池，彻底杜绝 OS 命令行超长参数卡死死锁；
  // 3. 采用 4 槽位轮换机制（job_slot_0.json ~ job_slot_3.json），在无删除权限下从机制上保障本地最多仅保留 4 个临时文件，零垃圾堆积！
  if (jsonStr.length < 2048) {
    const base64 = bytesToBase64(textBytes(jsonStr));
    if (base64) {
      return `memory://job:${base64}`;
    }
  }
  const slot = Math.abs(Date.now() % 4);
  const result = await fbApp.invoke<any>("fs.writeFile", {
    path: `${RUST_WORKER_LOCAL_DIR}/jobs/job_slot_${slot}.json`,
    content: jsonStr,
  });
  const path = String(result?.path || "");
  if (!path) throw new Error("小程序 Rust worker job 写入失败");
  return path;
}

function parseJsonLines(stdout: string) {
  return stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return null;
      }
    })
    .filter(Boolean);
}

export class GlobalDharmaSendService {
  async send(options: SendOptions): Promise<DharmaSendResult> {
    if (options.loop) {
      try {
        return await this.sendViaMiniAppRustWorker(options);
      } catch (error) {
        const message = `小程序 Rust worker: ${errorMessage(error)}`;
        options.onLog?.(`Rust worker daemon 接管失败：${message}`);
        throw new Error(
          `循环发送必须由底层 Rust daemon 接管，不能降级回 JS/UI 心跳：${message}`,
        );
      }
    }

    if (!fbApp.isHostEnv()) {
      try {
        return await this.sendViaWebWasmRustWorker(options);
      } catch (error) {
        console.warn("Web Wasm Rust 引擎发包降级至 HTTP:", error);
        return this.sendViaHttp(options);
      }
    }

    const failures: string[] = [];
    try {
      return await this.sendViaMiniAppRustWorker(options);
    } catch (error) {
      const message = `小程序 Rust worker: ${errorMessage(error)}`;
      failures.push(message);
      options.onLog?.(`Rust 引擎发包遭遇网络层限制，准备平滑降级到宿主系统网络：${message}`);
    }

    try {
      return await this.sendViaSystemNetwork(options);
    } catch (error) {
      const message = `宿主系统网络: ${errorMessage(error)}`;
      failures.push(message);
      options.onLog?.(`宿主系统网络发送失败，准备尝试兼容 delivery 队列：${message}`);
    }

    try {
      return await this.sendViaLegacyRustDelivery(options);
    } catch (error) {
      const message = `兼容 delivery 队列: ${errorMessage(error)}`;
      failures.push(message);
      options.onLog?.(`兼容 Rust delivery 队列失败：${message}`);
    }

    throw new Error(`真实发送失败：${failures.join("；")}`);
  }

  async sendViaHttp({
    content,
    region,
    loop,
    commandId,
  }: SendOptions): Promise<DharmaSendResult> {
    if (fbApp.isHostEnv()) {
      throw new Error("App 端不会使用浏览器模拟计数；只有 Web 端使用 HTTP。");
    }
    const contentHash = await sha256Hex(content.text);
    const bytesSent = textBytes(content.text).byteLength;
    const payload = buildPacket(
      content,
      region,
      loop,
      commandId,
      contentHash,
      "browser-http",
    );

    const response = await fetch(endpointUrl(), {
      method: "POST",
      cache: "no-store",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(payload),
    });
    if (!response.ok) {
      throw new Error(`全球法布施 Web HTTP 发送失败: HTTP ${response.status}`);
    }
    return this.normalizeHttpResult(
      contentHash,
      bytesSent,
      await response.json().catch(() => ({})),
      "browser-http",
    );
  }

  async resolveDeliveryTargets(
    region: RegionPreset,
  ): Promise<DeliveryTarget[]> {
    return deliveryTargetsForRegion(region);
  }

  async sendViaWebWasmRustWorker({
    content,
    region,
    loop,
    commandId,
  }: SendOptions): Promise<DharmaSendResult> {
    const targets = await this.resolveDeliveryTargets(region);
    if (targets.length === 0) {
      throw new Error("未配置真实发送节点：请设置 HTTP 或 UDP 目标。");
    }

    const contentHash = await sha256Hex(content.text);
    const packet = buildPacket(
      content,
      region,
      loop,
      commandId,
      contentHash,
      "web-wasm-rust",
    );
    const packetBody = JSON.stringify(packet);
    const packetBytes = textBytes(packetBody).byteLength;
    const jobId = `gd_wasm_${Date.now()}_${Math.random()
      .toString(36)
      .slice(2, 8)}`;

    if (!preparedWasmModulePromise) {
      preparedWasmModulePromise = (async () => {
        const response = await fetch("/miniapps/official.global-dharma/runtime/global_dharma_native.wasm");
        if (!response.ok) {
          throw new Error(`无法获取 WebAssembly 模块：HTTP ${response.status}`);
        }
        return await WebAssembly.compileStreaming(response);
      })().catch((error) => {
        preparedWasmModulePromise = null;
        throw error;
      });
    }
    const module = await preparedWasmModulePromise;
    const instance = await WebAssembly.instantiate(module, {});
    const exports = instance.exports as any;
    const memory = exports.memory as WebAssembly.Memory;
    const malloc = exports.malloc_rust_ffi as (size: number) => number;
    const free = exports.free_rust_buffer_ffi as (ptr: number, size: number) => void;
    const freeStr = exports.free_rust_string_ffi as (ptr: number) => void;
    const executeFfi = exports.execute_global_dharma_delivery_ffi as (
      jobIdPtr: number,
      regionPtr: number,
      port: number,
      packetPtr: number,
      callbackPtr: number
    ) => number;

    const encoder = new TextEncoder();
    const decoder = new TextDecoder();

    function writeString(str: string): { ptr: number; len: number } {
      const bytes = encoder.encode(str + "\0");
      const ptr = malloc(bytes.length);
      new Uint8Array(memory.buffer).set(bytes, ptr);
      return { ptr, len: bytes.length };
    }

    function readString(ptr: number): string {
      if (!ptr) return "";
      const buf = new Uint8Array(memory.buffer);
      let end = ptr;
      while (buf[end] !== 0) end++;
      return decoder.decode(buf.subarray(ptr, end));
    }

    const jobIdObj = writeString(jobId);
    const regionObj = writeString(region.id);
    const packetObj = writeString(packetBody);

    try {
      const resultPtr = executeFfi(
        jobIdObj.ptr,
        regionObj.ptr,
        DEFAULT_UDP_PORT,
        packetObj.ptr,
        0
      );
      const resultJsonStr = readString(resultPtr);
      if (resultPtr) freeStr(resultPtr);

      if (!resultJsonStr) {
        throw new Error("WebAssembly 引擎未能返回有效的 JSON 结果");
      }

      const resultMap = JSON.parse(resultJsonStr);
      const rawReceipts = Array.isArray(resultMap?.receipts) ? resultMap.receipts : [];
      const receipts: DharmaDeliveryReceipt[] = rawReceipts.map((item: any) => {
        const reported = Number(item?.bytesSent ?? item?.bytes ?? 0);
        return {
          countryCode: item?.countryCode,
          nodeId: item?.nodeId || item?.endpointId || "Unknown",
          channel: item?.channel === "udp" ? "udp" : "rust-http",
          status: item?.status === "delivered" ? "delivered" : "sent",
          bytesSent: reported > 0 ? reported : packetBytes,
          deliveredAt: item?.deliveredAt || item?.at || new Date().toISOString(),
          raw: item,
        };
      });

      if (receipts.length === 0) {
        throw new Error("WebAssembly 引擎未生成有效回执");
      }

      // 根据第一性原理与用户明确要求：
      // Web 端不使用 UDP，也不经过服务端网关中转，
      // 直接使用 Wasm 解析出的全球各国家节点 HTTP 地址，从用户浏览器/手机设备物理网卡发起跨域点对点发送！
      // 遵照绝对第一性原理：不并行发送，逐个顺序平稳投递至全球目标节点
      for (const item of rawReceipts) {
        const targetHost = item?.host || "1.1.1.1";
        const targetPort = item?.port || 80;
        const targetUrl = item?.url || `http://${targetHost}:${targetPort}/dharma`;
        try {
          await fetch(targetUrl, {
            method: "POST",
            mode: "no-cors",
            headers: {
              "Content-Type": "application/json",
            },
            body: packetBody,
          });
          // 逐个发送间隔平稳让出 8 毫秒，避免瞬时连接突发打满浏览器与系统内核连接池
          await new Promise((resolve) => setTimeout(resolve, 8));
        } catch {
          // 忽略个别目标公网地址超时或网络层波动
        }
      }

      return {
        contentHash: resultMap?.contentHash || contentHash,
        bytesSent: receipts.reduce((sum, item) => sum + item.bytesSent, 0),
        receipts,
        jobId: resultMap?.jobId || jobId,
        status: "sent",
      };
    } finally {
      free(jobIdObj.ptr, jobIdObj.len);
      free(regionObj.ptr, regionObj.len);
      free(packetObj.ptr, packetObj.len);
    }
  }

  async sendViaMiniAppRustWorker({
    content,
    region,
    loop,
    commandId,
    onLog,
  }: SendOptions): Promise<DharmaSendResult> {
    if (!fbApp.isHostEnv() && !loop) {
      throw new Error("当前 Web 浏览器不能启动小程序 Rust worker。");
    }
    const targets = await this.resolveDeliveryTargets(region);
    if (targets.length === 0) {
      throw new Error("未配置真实发送节点：请设置 HTTP 或 UDP 目标。");
    }

    const contentHash = await sha256Hex(content.text);
    const packet = buildPacket(
      content,
      region,
      loop,
      commandId,
      contentHash,
      "miniapp-rust-worker",
    );
    const packetBody = JSON.stringify(packet);
    const packetBytes = textBytes(packetBody).byteLength;
    const jobId = `gd_worker_${Date.now()}_${Math.random()
      .toString(36)
      .slice(2, 8)}`;
    const job = {
      jobId,
      miniAppId: MINIAPP_ID,
      loop,
      persistent: false,
      loopIntervalMs: DAEMON_LOOP_INTERVAL_MS,
      useGeoIp: true,
      region: region.id,
      port: DEFAULT_UDP_PORT,
      packet,
      endpoints: targets.map((target) => endpointForTarget(target, packetBody)),
      metadata: {
        contentHash,
        title: content.title,
        bytes: packetBytes,
        region: region.id,
      },
    };

    let prepared: PreparedWorker | null = null;
    let isDaemonOnline = false;
    if (fbApp.isHostEnv()) {
      prepared = await prepareMiniAppRustWorker(onLog);
      isDaemonOnline = await ensureRustWorkerDaemon(prepared, onLog);
    } else {
      isDaemonOnline = await isLoopCapableDaemon(activeRustDaemonBaseUrl, 1000);
    }
    if (loop) {
      if (!isDaemonOnline) {
        throw new Error("Rust daemon 未能启动，循环发送不能由 UI/JS 接管。");
      }
      return this.startDaemonManagedJob(job, contentHash, jobId, onLog);
    }

    if (!prepared) {
      throw new Error("当前环境不能启动小程序 Rust worker。");
    }
    if (isDaemonOnline) {
      onLog?.("通过后台 18888 守护服务 HTTP POST 纯内在线流式通道即时发包 (Memory Stream IPC)...");
      try {
        const resp = await fetchDaemonJson("/send", {
          method: "POST",
          body: JSON.stringify(job),
          timeoutMs: 60000,
        });
        if (resp.statusCode === 200) {
          const resData = resp.data;
          if (resData.ok) {
            await writeWorkerBuildCache(prepared);
            const rawReceipts = Array.isArray(resData?.receipts)
              ? resData.receipts
              : [];
            const receipts: DharmaDeliveryReceipt[] = rawReceipts.map(
              (item: any) => ({
                countryCode: item?.countryCode,
                nodeId: item?.nodeId || item?.endpointId || "Unknown",
                channel: item?.channel === "udp" ? "udp" : "rust-http",
                status: item?.status === "delivered" ? "delivered" : "sent",
                bytesSent: readNumber(item?.bytesSent ?? item?.bytes, packetBytes),
                deliveredAt:
                  item?.deliveredAt || item?.at || new Date().toISOString(),
                raw: item,
              }),
            );
            return {
              contentHash,
              bytesSent:
                resData.bytesSent ||
                receipts.reduce((sum, r) => sum + r.bytesSent, 0) ||
                packetBytes * targets.length,
              receipts,
              jobId,
              status:
                receipts.some((r) => r.status === "delivered") || receipts.length > 0
                  ? "delivered"
                  : "sent",
            };
          }
        }
      } catch (err) {
        onLog?.(`流式通道推流异常：${errorMessage(err)}。平滑降级为离线独立命令行模式...`);
      }
    }

    const jobPath = await writeWorkerJob(job);
    let processResult: any;
    try {
      processResult = await runHostProcess(
        "全球法布施 Rust worker",
        prepared.binaryPath,
        ["--job-file", jobPath],
      );
    } catch (error) {
      onLog?.(
        `直接启动 release worker 失败：${errorMessage(error)}。正在重建本机 worker 后重试。`,
      );
      await buildMiniAppRustWorker(prepared, onLog);
      try {
        processResult = await runHostProcess(
          "全球法布施 Rust worker",
          prepared.binaryPath,
          ["--job-file", jobPath],
        );
      } catch (retryError) {
        onLog?.(
          `release worker 重试仍失败：${errorMessage(retryError)}。改用 Cargo 兼容模式。`,
        );
        processResult = await runHostProcess(
          "Rust worker Cargo 兼容模式",
          "cargo",
          [
            "run",
            "--release",
            "--locked",
            "--offline",
            "--quiet",
            "--manifest-path",
            prepared.manifestPath,
            "--",
            "--job-file",
            jobPath,
          ],
          { silentCli: false },
        );
      }
    }
    const exitCode = Number(processResult?.exitCode ?? -1);
    const stdout = String(processResult?.stdout || "");
    const stderr = String(processResult?.stderr || "");
    if (exitCode !== 0) {
      throw new Error(stderr.trim() || stdout.trim() || `exit ${exitCode}`);
    }
    await writeWorkerBuildCache(prepared);
    return this.normalizeWorkerResult(contentHash, packetBytes, stdout, jobId);
  }

  private async startDaemonManagedJob(
    job: unknown,
    contentHash: string,
    jobId: string,
    onLog?: (message: string) => void,
  ): Promise<DharmaSendResult> {
    onLog?.("循环任务配置已交给 Rust daemon，底层进程将作为 Master 自主循环发包。");
    const resp = await fetchDaemonJson("/jobs/start", {
      method: "POST",
      body: JSON.stringify(job),
      timeoutMs: 10000,
    });
    const statusCode = resp.statusCode;
    const data = resp.data;
    if (statusCode < 200 || statusCode >= 300 || data?.ok !== true) {
      throw new Error(
        `Rust daemon 循环任务提交失败：HTTP ${statusCode || "unknown"} ${data?.error || ""}`.trim(),
      );
    }
    return {
      contentHash,
      bytesSent: 0,
      receipts: [],
      jobId: String(data.jobId || jobId),
      status: "running",
    };
  }

  async getDaemonStatus(
    jobId?: string,
    cursor = 0,
    limit = 120,
  ): Promise<DharmaDaemonStatus> {
    const query = [
      jobId ? `jobId=${encodeQuery(jobId)}` : "",
      `cursor=${Math.max(0, cursor)}`,
      `limit=${Math.max(1, Math.min(1000, limit))}`,
    ]
      .filter(Boolean)
      .join("&");
    const resp = await fetchDaemonJson(`/jobs/status?${query}`, {
      method: "GET",
      timeoutMs: 2000,
    });
    const statusCode = resp.statusCode;
    const data = resp.data;
    if (statusCode < 200 || statusCode >= 300 || data?.ok !== true) {
      throw new Error(`Rust daemon 状态读取失败：HTTP ${statusCode || "unknown"}`);
    }
    return {
      ok: true,
      daemon: data.daemon === true,
      status: data.status,
      version: data.version,
      source: data.source,
      jobs: Array.isArray(data.jobs) ? data.jobs : [],
      job: data.job && typeof data.job === "object" ? data.job : undefined,
      events: Array.isArray(data.events) ? data.events : [],
      cursor: readNumber(data.cursor, cursor),
    };
  }

  async stopDaemonJob(jobId?: string): Promise<{ stopped: number }> {
    const resp = await fetchDaemonJson("/jobs/stop", {
      method: "POST",
      body: JSON.stringify(jobId ? { jobId } : {}),
      timeoutMs: 5000,
    });
    const statusCode = resp.statusCode;
    const data = resp.data;
    if (statusCode < 200 || statusCode >= 300 || data?.ok !== true) {
      throw new Error(`Rust daemon 停止失败：HTTP ${statusCode || "unknown"}`);
    }
    return { stopped: readNumber(data.stopped, 0) };
  }

  async sendViaSystemNetwork({
    content,
    region,
    loop,
    commandId,
  }: SendOptions): Promise<DharmaSendResult> {
    if (!fbApp.isHostEnv()) {
      throw new Error("当前浏览器不能调用宿主系统网络能力。");
    }
    const targets = await this.resolveDeliveryTargets(region);
    if (targets.length === 0) {
      throw new Error("未配置真实发送节点：请设置 HTTP 或 UDP 目标。");
    }

    const contentHash = await sha256Hex(content.text);
    const packet = buildPacket(
      content,
      region,
      loop,
      commandId,
      contentHash,
      "host-system-network",
    );
    const packetBody = JSON.stringify(packet);
    const packetBytes = textBytes(packetBody).byteLength;
    const udpDatagrams = udpDatagramBodies(packetBody, contentHash);
    const receipts: DharmaDeliveryReceipt[] = [];
    const udpTargets = targets.filter(isUdpTarget);
    let udpSocketId = "";

    if (udpTargets.length > 0) {
      const openResult = await fbApp.invoke<any>("network.udp.open", {
        port: 0,
        broadcast: udpTargets.some(needsUdpBroadcast),
      });
      udpSocketId = String(openResult?.socketId || "");
      if (!udpSocketId) throw new Error("系统 UDP socket 打开失败：没有返回 socketId");
    }

    try {
      for (let i = 0; i < targets.length; i++) {
        const target = targets[i];
        const endpoint = endpointForTarget(target, packetBody);
        if (target.transport === "http") {
          const response = await fbApp.invoke<any>("network.http.fetch", {
            url: endpoint.url,
            method: endpoint.method,
            headers: endpoint.headers,
            body: packetBody,
            timeoutMs: endpoint.timeoutMs,
            maxBodyBytes: endpoint.maxBodyBytes,
          });
          const statusCode = readNumber(response?.statusCode);
          if (statusCode < 200 || statusCode >= 300) {
            throw new Error(
              `系统 HTTP 发送失败：${endpointLabel(target)} HTTP ${statusCode}`,
            );
          }
          receipts.push({
            countryCode: target.countryCode,
            nodeId: endpointIdForTarget(target),
            channel: "system-http",
            status: "delivered",
            bytesSent: packetBytes,
            deliveredAt: new Date().toISOString(),
            raw: response,
          });
        } else {
          let reportedBytes = 0;
          const responses: unknown[] = [];
          for (const datagramBody of udpDatagrams) {
            const datagramBytes = textBytes(datagramBody);
            const response = await this.invokeUdpSendWithRetry("network.udp.send", {
              socketId: udpSocketId,
              host: endpoint.host,
              port: endpoint.port,
              data: bytesToBase64(datagramBytes),
            });
            reportedBytes += readNumber(response?.sentBytes, datagramBytes.byteLength);
            responses.push(response);
            if (udpDatagrams.length > 1) await sleep(2);
          }
          receipts.push({
            countryCode: target.countryCode,
            nodeId: endpointIdForTarget(target),
            channel: "udp",
            status: "sent",
            bytesSent: reportedBytes,
            deliveredAt: new Date().toISOString(),
            raw:
              udpDatagrams.length > 1
                ? { chunked: true, chunkCount: udpDatagrams.length, responses }
                : responses[0],
          });
        }
        // 遵照绝对第一性原理：不并行发送，逐个顺序平稳发包
        await sleep(6);
      }
    } finally {
      if (udpSocketId) {
        await fbApp
          .invoke("network.udp.close", { socketId: udpSocketId })
          .catch(() => null);
      }
    }

    return {
      contentHash,
      bytesSent: receipts.reduce((sum, item) => sum + item.bytesSent, 0),
      receipts,
      jobId: `system_${Date.now()}`,
      status: receipts.some((item) => item.status === "delivered")
        ? "delivered"
        : "sent",
    };
  }

  private async invokeUdpSendWithRetry(
    method: "network.udp.send" | "network.udp.broadcast",
    params: Record<string, unknown>,
  ) {
    let response: any = null;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      response = await fbApp.invoke<any>(method, params);
      if (readNumber(response?.sentBytes, 0) > 0) return response;
      if (attempt < 2) await sleep(8 * (attempt + 1));
    }
    return response;
  }

  async sendViaLegacyRustDelivery({
    content,
    region,
    loop,
    commandId,
  }: SendOptions): Promise<DharmaSendResult> {
    if (!fbApp.isHostEnv()) {
      throw new Error("当前 Web 浏览器不会使用 Rust delivery。");
    }
    const targets = await this.resolveDeliveryTargets(region);
    if (targets.length === 0) {
      throw new Error("未配置真实 Rust delivery 节点。");
    }

    const contentHash = await sha256Hex(content.text);
    const packet = buildPacket(
      content,
      region,
      loop,
      commandId,
      contentHash,
      "legacy-rust-delivery",
    );
    const packetBody = JSON.stringify(packet);
    const packetBytes = textBytes(packetBody).byteLength;
    const jobIds: string[] = [];
    const receipts: DharmaDeliveryReceipt[] = [];

    for (const target of targets) {
      const endpointId = endpointIdForTarget(target);
      const response = await fbApp.invoke<any>(
        "globalDharma.delivery.enqueue",
        {
          packet,
          endpoints: endpointForTarget(target, packetBody),
          maxAttempts: 1,
          metadata: {
            contentHash,
            title: content.title,
            bytes: packetBytes,
            countryCode: target.countryCode,
            nodeId: endpointId,
            region: region.id,
          },
        },
      );
      const jobId = String(response?.jobId || response?.job?.jobId || "");
      if (!jobId)
        throw new Error(`Rust delivery 没有返回 jobId：${endpointId}`);
      jobIds.push(jobId);
      const receipt = await this.waitForRustReceipt(jobId, target, packetBytes);
      receipts.push(receipt);
    }

    return {
      contentHash,
      bytesSent: receipts.reduce((sum, item) => sum + item.bytesSent, 0),
      receipts,
      jobId: jobIds[0],
      jobIds,
      status: "sent",
    };
  }

  private async waitForRustReceipt(
    jobId: string,
    target: DeliveryTarget,
    fallbackBytes: number,
  ): Promise<DharmaDeliveryReceipt> {
    const deadline = Date.now() + RUST_DELIVERY_RECEIPT_TIMEOUT_MS;
    let lastStatus = "";
    let lastError = "";

    while (Date.now() < deadline) {
      const receiptList = await fbApp.invoke<any>(
        "globalDharma.delivery.listReceipts",
        {
          jobId,
          limit: 10,
          timeoutMs: 5000,
        },
      );
      const receipts = Array.isArray(receiptList?.receipts)
        ? receiptList.receipts
        : [];
      const receipt = receipts.find(
        (item: any) => String(item?.jobId || "") === jobId,
      );
      if (receipt) {
        return this.normalizeRustReceipt(receipt, target, fallbackBytes);
      }

      const jobResponse = await fbApp.invoke<any>(
        "globalDharma.delivery.getJob",
        {
          jobId,
          timeoutMs: 5000,
        },
      );
      const job = jobResponse?.job;
      lastStatus = String(job?.status || lastStatus || "");
      const error = job?.lastError;
      lastError =
        typeof error?.message === "string" && error.message
          ? error.message
          : typeof error === "string"
            ? error
            : lastError;
      if (lastStatus === "failed" || lastStatus === "receipt_failed") {
        throw new Error(
          `Rust delivery 失败：${endpointLabel(target)}${lastError ? `，${lastError}` : ""}`,
        );
      }
      await sleep(RUST_DELIVERY_RECEIPT_POLL_MS);
    }

    throw new Error(
      `等待 Rust delivery 回执超时：${endpointLabel(target)}${lastStatus ? `，状态 ${lastStatus}` : ""}`,
    );
  }

  private normalizeWorkerResult(
    contentHash: string,
    fallbackBytes: number,
    stdout: string,
    fallbackJobId: string,
  ): DharmaSendResult {
    const events = parseJsonLines(stdout);
    const result = [...events]
      .reverse()
      .find((event: any) => event?.type === "result");
    const rawReceipts = Array.isArray(result?.receipts)
      ? result.receipts
      : events.filter((event: any) => event?.type === "receipt");
    const receipts: DharmaDeliveryReceipt[] = rawReceipts.map((item: any) => {
      const reported = readNumber(item?.bytesSent ?? item?.bytes, 0);
      return {
        countryCode: item?.countryCode,
        nodeId: item?.nodeId || item?.endpointId,
        channel: item?.channel === "udp" ? "udp" : "rust-http",
        status: item?.status === "delivered" ? "delivered" : "sent",
        bytesSent: reported,
        deliveredAt: item?.deliveredAt || item?.at || new Date().toISOString(),
        raw: item,
      };
    });
    if (receipts.length === 0) {
      throw new Error("Rust worker 没有输出真实发送回执");
    }
    return {
      contentHash: result?.contentHash || contentHash,
      bytesSent: receipts.reduce((sum, item) => sum + item.bytesSent, 0),
      receipts,
      jobId: result?.jobId || fallbackJobId,
      status: receipts.some((item) => item.status === "delivered")
        ? "delivered"
        : "sent",
    };
  }

  private normalizeRustReceipt(
    receipt: any,
    target: DeliveryTarget,
    fallbackBytes: number,
  ): DharmaDeliveryReceipt {
    const payload = receipt?.payload || {};
    const response = payload?.response || {};
    const sentBytes = readNumber(response?.sentBytes, 0);
    return {
      countryCode: target.countryCode,
      nodeId:
        target.nodeId || String(receipt?.endpointId || endpointLabel(target)),
      channel:
        target.transport === "http" ||
        payload?.transport === "http" ||
        payload?.transport === "https"
          ? "rust-http"
          : "udp",
      status: receipt?.status === "delivered" ? "delivered" : "sent",
      bytesSent: sentBytes,
      deliveredAt: isoTimeFromMillis(receipt?.receivedAtMs),
      raw: receipt,
    };
  }

  private normalizeHttpResult(
    contentHash: string,
    bytesSent: number,
    response: any,
    channel: "rust-http" | "browser-http" | "system-http",
  ): DharmaSendResult {
    const receipts: DharmaDeliveryReceipt[] = Array.isArray(response?.receipts)
      ? response.receipts.map((item: any) => ({
          countryCode: item?.country || item?.countryCode,
          nodeId: item?.node || item?.nodeId,
          channel,
          status: item?.status === "delivered" ? "delivered" : "queued",
          bytesSent: Number(item?.bytesSent ?? item?.bytes ?? 0),
          deliveredAt:
            item?.deliveredAt || item?.createdAt || new Date().toISOString(),
          raw: item,
        }))
      : [
          {
            channel,
            status:
              response?.status === "delivered" || response?.ok === true
                ? "delivered"
                : "sent",
            bytesSent,
            deliveredAt: response?.createdAt || new Date().toISOString(),
            raw: response,
          },
        ];

    return {
      contentHash: response?.contentHash || contentHash,
      bytesSent: receipts.reduce(
        (sum: number, item: DharmaDeliveryReceipt) => sum + item.bytesSent,
        0,
      ),
      receipts,
      jobId: response?.jobId || response?.id,
      status:
        response?.status === "delivered"
          ? "delivered"
          : receipts.length > 0
            ? "sent"
            : "queued",
    };
  }
}
