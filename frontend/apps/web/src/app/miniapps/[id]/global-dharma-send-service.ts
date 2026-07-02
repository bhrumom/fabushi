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
  channel: "udp" | "browser-http" | "rust-http";
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

const DEFAULT_GLOBAL_DHARMA_SEND_URL =
  "https://api.ombhrum.com/api/global-dharma/send";
const DEFAULT_UDP_PORT = 9999;
const RUST_DELIVERY_RECEIPT_TIMEOUT_MS = 45000;
const RUST_DELIVERY_RECEIPT_POLL_MS = 650;

function endpointUrl() {
  const configured =
    process.env.NEXT_PUBLIC_GLOBAL_DHARMA_SEND_URL ||
    process.env.NEXT_PUBLIC_FABUSHI_GLOBAL_DHARMA_SEND_URL ||
    "";
  return configured.trim() || DEFAULT_GLOBAL_DHARMA_SEND_URL;
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

function regionMatchesTarget(region: RegionPreset, target: UdpTarget) {
  const countries = targetCountries(region);
  if (countries.length === 0 || countries.includes("ALL")) return true;
  if (!target.countryCode) return true;
  return countries.includes(target.countryCode);
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

export class GlobalDharmaSendService {
  async send(options: SendOptions): Promise<DharmaSendResult> {
    if (fbApp.isHostEnv()) {
      return this.sendViaRustDelivery(options);
    }
    return this.sendViaHttp(options);
  }

  async sendViaHttp({
    content,
    region,
    loop,
    commandId,
  }: SendOptions): Promise<DharmaSendResult> {
    if (fbApp.isHostEnv()) {
      throw new Error(
        "App 端全球发送必须通过 Rust delivery/UDP；只有 Web 端使用 HTTP。",
      );
    }
    const contentHash = await sha256Hex(content.text);
    const bytesSent = textBytes(content.text).byteLength;
    const payload = {
      title: content.title,
      text: content.text,
      previewText: content.previewText,
      sourceUrl: content.sourceUrl || null,
      contentHash,
      bytes: bytesSent,
      targetCountries: targetCountries(region),
      region: region.id,
      loop,
      commandId,
      createdAt: new Date().toISOString(),
      client: {
        surface: "web-miniapp",
        miniAppId: "official.global-dharma",
      },
    };

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

  async sendViaRustDelivery({
    content,
    region,
    loop,
    commandId,
  }: SendOptions): Promise<DharmaSendResult> {
    if (!fbApp.isHostEnv()) {
      throw new Error(
        "当前 Web 浏览器不会使用 UDP；请在桌面端或移动端 App 内使用 Rust 系统级发送。",
      );
    }
    const targets = udpTargetsForRegion(region);
    if (targets.length === 0) {
      throw new Error(
        "未配置真实 UDP 节点：请设置 NEXT_PUBLIC_GLOBAL_DHARMA_UDP_TARGETS，不能使用模拟目标计数。",
      );
    }

    const contentHash = await sha256Hex(content.text);
    const packet = {
      type: "global_dharma_delivery",
      contentHash,
      title: content.title,
      text: content.text,
      sourceUrl: content.sourceUrl || null,
      region: region.id,
      targetCountries: targetCountries(region),
      loop,
      commandId,
      createdAt: new Date().toISOString(),
      client: {
        surface: "host-miniapp",
        transport: "rust-delivery-udp",
        miniAppId: "official.global-dharma",
      },
    };
    const packetBody = JSON.stringify(packet);
    const packetBytes = textBytes(packetBody).byteLength;
    const jobIds: string[] = [];
    const receipts: DharmaDeliveryReceipt[] = [];

    for (const target of targets) {
      const endpointId = target.nodeId || `${target.host}:${target.port}`;
      const response = await fbApp.invoke<any>(
        "globalDharma.delivery.enqueue",
        {
          packet,
          endpoints: {
            transport: "udp",
            endpointId,
            host: target.host,
            port: target.port,
            data: bytesToBase64(textBytes(packetBody)),
          },
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
    target: UdpTarget,
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
          `Rust delivery 失败：${target.nodeId || target.host}:${target.port}${lastError ? `，${lastError}` : ""}`,
        );
      }
      await sleep(RUST_DELIVERY_RECEIPT_POLL_MS);
    }

    throw new Error(
      `等待 Rust delivery 回执超时：${target.nodeId || target.host}:${target.port}${lastStatus ? `，状态 ${lastStatus}` : ""}`,
    );
  }

  private normalizeRustReceipt(
    receipt: any,
    target: UdpTarget,
    fallbackBytes: number,
  ): DharmaDeliveryReceipt {
    const payload = receipt?.payload || {};
    const response = payload?.response || {};
    const sentBytes = readNumber(response?.sentBytes, fallbackBytes);
    return {
      countryCode: target.countryCode,
      nodeId:
        target.nodeId ||
        String(receipt?.endpointId || `${target.host}:${target.port}`),
      channel:
        payload?.transport === "http" || payload?.transport === "https"
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
    channel: "rust-http" | "browser-http",
  ): DharmaSendResult {
    const receipts = Array.isArray(response?.receipts)
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
      : [];

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
