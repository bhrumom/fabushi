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
  channel: "http" | "udp" | "browser-http";
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

function bodyTextFromHostResponse(response: any) {
  if (typeof response?.body === "string" && response.body.length > 0) {
    return response.body;
  }
  if (typeof response?.bodyBase64 === "string" && response.bodyBase64.length > 0) {
    return window.atob(response.bodyBase64);
  }
  return "";
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

function parseJsonBody(text: string) {
  if (!text.trim()) return {};
  try {
    return JSON.parse(text);
  } catch {
    return { rawBody: text };
  }
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

export class GlobalDharmaSendService {
  async send(options: SendOptions): Promise<DharmaSendResult> {
    if (options.region.fieldEnergy || options.region.localLoopback) {
      return this.sendViaUdp(options);
    }
    return this.sendViaHttp(options);
  }

  async sendViaHttp({ content, region, loop, commandId }: SendOptions): Promise<DharmaSendResult> {
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
        surface: fbApp.isHostEnv() ? "host-miniapp" : "web-miniapp",
        miniAppId: "official.global-dharma",
      },
    };

    if (fbApp.isHostEnv()) {
      const response = await fbApp.invoke<any>("network.http.fetch", {
        url: endpointUrl(),
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "User-Agent": "FabushiMiniApp/GlobalDharma",
        },
        bodyBase64: bytesToBase64(textBytes(JSON.stringify(payload))),
        timeoutMs: 30000,
        maxBodyBytes: 2 * 1024 * 1024,
        responseEncoding: "base64+text",
      });
      const statusCode = Number(response?.statusCode || 0);
      if (statusCode < 200 || statusCode >= 300) {
        throw new Error(`全球法布施 HTTP 发送失败: HTTP ${statusCode}`);
      }
      return this.normalizeHttpResult(contentHash, bytesSent, parseJsonBody(bodyTextFromHostResponse(response)), "http");
    }

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
    return this.normalizeHttpResult(contentHash, bytesSent, await response.json().catch(() => ({})), "browser-http");
  }

  async sendViaUdp({ content, region, loop, commandId }: SendOptions): Promise<DharmaSendResult> {
    if (!fbApp.isHostEnv()) {
      throw new Error("当前浏览器没有宿主 UDP 系统能力；请在 App 内打开或切换全球 HTTP 发送。");
    }
    const targets = readUdpTargets();
    if (targets.length === 0) {
      throw new Error("未配置真实 UDP 节点：请设置 NEXT_PUBLIC_GLOBAL_DHARMA_UDP_TARGETS，不能使用模拟目标。");
    }

    const contentHash = await sha256Hex(content.text);
    const bytes = textBytes(
      JSON.stringify({
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
      }),
    );
    const socket = await fbApp.invoke<any>("network.udp.open", {
      port: 0,
      broadcast: region.fieldEnergy === true,
    });
    const socketId = String(socket?.socketId || "");
    if (!socketId) throw new Error("宿主没有返回 UDP socketId");

    const receipts: DharmaDeliveryReceipt[] = [];
    try {
      for (const target of targets) {
        const result = await fbApp.invoke<any>("network.udp.send", {
          socketId,
          host: target.host,
          port: target.port,
          data: bytesToBase64(bytes),
        });
        const sentBytes = Number(result?.sentBytes || 0);
        if (sentBytes <= 0) {
          throw new Error(`UDP 节点 ${target.host}:${target.port} 未发送任何字节`);
        }
        receipts.push({
          countryCode: target.countryCode,
          nodeId: target.nodeId || `${target.host}:${target.port}`,
          channel: "udp",
          status: "sent",
          bytesSent: sentBytes,
          deliveredAt: new Date().toISOString(),
          raw: result,
        });
      }
    } finally {
      await fbApp.invoke("network.udp.close", { socketId }).catch(() => null);
    }

    return {
      contentHash,
      bytesSent: receipts.reduce((sum, item) => sum + item.bytesSent, 0),
      receipts,
      status: "sent",
    };
  }

  private normalizeHttpResult(
    contentHash: string,
    bytesSent: number,
    response: any,
    channel: "http" | "browser-http",
  ): DharmaSendResult {
    const receipts = Array.isArray(response?.receipts)
      ? response.receipts.map((item: any) => ({
          countryCode: item?.country || item?.countryCode,
          nodeId: item?.node || item?.nodeId,
          channel,
          status: item?.status === "delivered" ? "delivered" : "queued",
          bytesSent: Number(item?.bytes || bytesSent),
          deliveredAt: item?.deliveredAt || item?.createdAt || new Date().toISOString(),
          raw: item,
        }))
      : [
          {
            channel,
            status: response?.status === "delivered" ? "delivered" : "queued",
            bytesSent,
            deliveredAt: new Date().toISOString(),
            raw: response,
          },
        ];

    return {
      contentHash: response?.contentHash || contentHash,
      bytesSent: receipts.reduce((sum: number, item: DharmaDeliveryReceipt) => sum + item.bytesSent, 0),
      receipts,
      jobId: response?.jobId || response?.id,
      status: response?.status === "delivered" ? "delivered" : "queued",
    };
  }
}
