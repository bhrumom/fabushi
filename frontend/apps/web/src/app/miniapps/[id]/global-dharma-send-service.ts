import { fbApp } from "./miniapp-runtime";

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
  status: "delivered" | "queued" | "sent";
};

type SendOptions = {
  content: PreparedContent;
  region: RegionPreset;
  loop: boolean;
  commandId?: string;
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
const DEFAULT_UDP_PORT = 9999;
const RUST_DELIVERY_RECEIPT_TIMEOUT_MS = 45000;
const RUST_DELIVERY_RECEIPT_POLL_MS = 650;
const RUST_WORKER_LOCAL_DIR = "runtime/global-dharma-worker";
const RUST_WORKER_PUBLIC_DIR =
  "/miniapps/official.global-dharma/runtime/global-dharma-worker";
const RUST_WORKER_FILES = [
  "Cargo.toml",
  "src/main.rs",
] as const;

let preparedWorkerPromise: Promise<PreparedWorker> | null = null;

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
  return readUdpTargets().filter((target) =>
    regionMatchesTarget(region, target),
  );
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

async function prepareMiniAppRustWorker(): Promise<PreparedWorker> {
  if (preparedWorkerPromise) return preparedWorkerPromise;
  preparedWorkerPromise = (async () => {
    let manifestPath = "";
    for (const file of RUST_WORKER_FILES) {
      const content = await fetchTextAsset(`${RUST_WORKER_PUBLIC_DIR}/${file}`);
      const writeResult = await fbApp.invoke<any>("fs.writeFile", {
        path: `${RUST_WORKER_LOCAL_DIR}/${file}`,
        content,
      });
      if (file === "Cargo.toml") {
        manifestPath = String(writeResult?.path || "");
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

    const buildResult = await fbApp.invoke<any>("runtime.process.execute", {
      title: "构建全球法布施 Rust worker (一次性)",
      command: "cargo",
      arguments: [
        "build",
        "--release",
        "--quiet",
        "--manifest-path",
        manifestPath,
      ],
    });
    const buildExitCode = Number(buildResult?.exitCode ?? -1);
    if (buildExitCode !== 0) {
      const stderr = String(buildResult?.stderr || "");
      const stdout = String(buildResult?.stdout || "");
      throw new Error(
        `Rust worker 构建失败: ${stderr.trim() || stdout.trim() || `exit ${buildExitCode}`}`,
      );
    }

    return { manifestPath, binaryPath };
  })().catch((error) => {
    preparedWorkerPromise = null;
    throw error;
  });
  return preparedWorkerPromise;
}

async function writeWorkerJob(job: unknown) {
  const suffix = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const result = await fbApp.invoke<any>("fs.writeFile", {
    path: `${RUST_WORKER_LOCAL_DIR}/jobs/${suffix}.json`,
    content: JSON.stringify(job),
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
    if (!fbApp.isHostEnv()) return this.sendViaHttp(options);

    const failures: string[] = [];
    try {
      return await this.sendViaMiniAppRustWorker(options);
    } catch (error) {
      failures.push(`小程序 Rust worker: ${errorMessage(error)}`);
    }

    try {
      return await this.sendViaSystemNetwork(options);
    } catch (error) {
      failures.push(`宿主系统网络: ${errorMessage(error)}`);
    }

    try {
      return await this.sendViaLegacyRustDelivery(options);
    } catch (error) {
      failures.push(`兼容 delivery 队列: ${errorMessage(error)}`);
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

  async sendViaMiniAppRustWorker({
    content,
    region,
    loop,
    commandId,
  }: SendOptions): Promise<DharmaSendResult> {
    if (!fbApp.isHostEnv()) {
      throw new Error("当前 Web 浏览器不能启动小程序 Rust worker。");
    }
    const targets = deliveryTargetsForRegion(region);
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
      packet,
      endpoints: targets.map((target) => endpointForTarget(target, packetBody)),
      metadata: {
        contentHash,
        title: content.title,
        bytes: packetBytes,
        region: region.id,
      },
    };

    const [prepared, jobPath] = await Promise.all([
      prepareMiniAppRustWorker(),
      writeWorkerJob(job),
    ]);
    let processResult: any;
    try {
      processResult = await fbApp.invoke<any>("runtime.process.execute", {
        title: "全球法布施 Rust worker",
        command: prepared.binaryPath,
        arguments: ["--job-file", jobPath],
      });
    } catch {
      processResult = await fbApp.invoke<any>("runtime.process.execute", {
        title: "全球法布施 Rust worker (cargo)",
        command: "cargo",
        arguments: [
          "run",
          "--release",
          "--quiet",
          "--manifest-path",
          prepared.manifestPath,
          "--",
          "--job-file",
          jobPath,
        ],
      });
    }
    const exitCode = Number(processResult?.exitCode ?? -1);
    const stdout = String(processResult?.stdout || "");
    const stderr = String(processResult?.stderr || "");
    if (exitCode !== 0) {
      throw new Error(stderr.trim() || stdout.trim() || `exit ${exitCode}`);
    }
    return this.normalizeWorkerResult(contentHash, packetBytes, stdout, jobId);
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
    const targets = deliveryTargetsForRegion(region);
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
    const receipts: DharmaDeliveryReceipt[] = [];

    for (const target of targets) {
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
        continue;
      }

      const response = await fbApp.invoke<any>("network.udp.broadcast", {
        host: endpoint.host,
        port: endpoint.port,
        data: endpoint.data,
      });
      receipts.push({
        countryCode: target.countryCode,
        nodeId: endpointIdForTarget(target),
        channel: "udp",
        status: "sent",
        bytesSent: readNumber(response?.sentBytes, packetBytes),
        deliveredAt: new Date().toISOString(),
        raw: response,
      });
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

  async sendViaLegacyRustDelivery({
    content,
    region,
    loop,
    commandId,
  }: SendOptions): Promise<DharmaSendResult> {
    if (!fbApp.isHostEnv()) {
      throw new Error("当前 Web 浏览器不会使用 Rust delivery。");
    }
    const targets = deliveryTargetsForRegion(region);
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
    const receipts: DharmaDeliveryReceipt[] = rawReceipts.map((item: any) => ({
      countryCode: item?.countryCode,
      nodeId: item?.nodeId || item?.endpointId,
      channel: item?.channel === "udp" ? "udp" : "rust-http",
      status: item?.status === "delivered" ? "delivered" : "sent",
      bytesSent: readNumber(item?.bytesSent || item?.bytes, fallbackBytes),
      deliveredAt: item?.deliveredAt || item?.at || new Date().toISOString(),
      raw: item,
    }));
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
    const sentBytes = readNumber(response?.sentBytes, fallbackBytes);
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
      bytesSent: sentBytes > 0 ? sentBytes : fallbackBytes,
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
          bytesSent: Number(item?.bytes || bytesSent),
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
