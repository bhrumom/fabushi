"use client";

import React, { useEffect, useMemo, useRef, useState } from "react";
import { CircleStop, Globe, Link2, RefreshCw, Send, Sparkles } from "lucide-react";
import * as THREE from "three";
import {
  createEntitlementCache,
  EntitlementState,
  isHostErrorCode,
  isHostReady,
  miniAppHost,
  onMiniAppReady,
} from "./miniapp-sdk";
import "./miniapps.css";

type RegionPreset = {
  id: string;
  label: string;
  global?: boolean;
  countryCodes?: string[];
  fieldEnergy?: boolean;
  localLoopback?: boolean;
};

type TransferMaterial = {
  kind: string;
  title: string;
  previewText: string;
  payloadText: string;
  sourceUrl?: string;
};

type PreparedTransferContent = {
  kind: string;
  title: string;
  text: string;
  previewText: string;
  sourceUrl?: string;
};

type GlobalDharmaTransferStatus = {
  isPreparingSend: boolean;
  isTransferring: boolean;
  message: string;
  sentCount: number;
  sentMB: number;
  hasFiles: boolean;
  selectedContent: PreparedTransferContent | TransferMaterial | null;
  options: {
    regionMode: string;
    global: boolean;
    countryCodes: string[];
    loop: boolean;
    fieldEnergy: boolean;
    localLoopback: boolean;
  };
  hotspot?: Record<string, any> | null;
  lastError?: string | null;
};

type TransferStartOptions = {
  text: string;
  title: string;
  region: RegionPreset;
  loop: boolean;
  selectedMaterial?: TransferMaterial | null;
};

type TransferTarget = {
  host: string;
  port: number;
  label: string;
};

const regionPresets: RegionPreset[] = [
  { id: "global", label: "全球", global: true, countryCodes: ["ALL"] },
  { id: "eastAsia", label: "东亚", global: true, countryCodes: ["CN", "JP", "KR", "MN", "TW", "HK", "MO"] },
  { id: "americas", label: "美洲", global: true, countryCodes: ["US", "CA", "MX", "BR", "AR", "CL", "PE"] },
  { id: "europe", label: "欧洲", global: true, countryCodes: ["GB", "FR", "DE", "IT", "ES", "NL", "SE"] },
  { id: "field", label: "本地场能", global: false, countryCodes: [], fieldEnergy: true },
  { id: "loopback", label: "本地转经轮", global: false, countryCodes: [], localLoopback: true },
];

const HIGH_ENERGY_PRODUCT = {
  productId: "zen_buddha_asset",
  title: "3D佛像素材",
  priceLabel: "¥33.00",
  amount: 33,
  fudeGoldPrice: 33,
  fudeGoldPriceLabel: "33 福德金",
};
const HIGH_ENERGY_PURCHASE_KEY = "fabushi.official.global-dharma.purchase.zen_buddha_asset";
const highEnergyPurchaseCache = createEntitlementCache(
  HIGH_ENERGY_PURCHASE_KEY,
  HIGH_ENERGY_PRODUCT,
);
const GLOBAL_DHARMA_LOGS_KEY = "fabushi.official.global-dharma.session.logs";
const GLOBAL_DHARMA_UDP_PORT = 38488;
const DEFAULT_PACKET_CHARS = 820;

const highEnergyMaterial: TransferMaterial = {
  kind: "zen_buddha_asset",
  title: HIGH_ENERGY_PRODUCT.title,
  previewText: "3D佛像素材已加入本轮全球法布施任务。",
  payloadText:
    "全球法布施高能素材：3D佛像观想与供养数据包。愿见闻者离苦得乐，增长善根，发菩提心。",
};

function readStoredGlobalDharmaLogs() {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(GLOBAL_DHARMA_LOGS_KEY);
    const parsed = raw ? JSON.parse(raw) : [];
    return Array.isArray(parsed) ? parsed.slice(-120).map(String) : [];
  } catch {
    return [];
  }
}

function storeGlobalDharmaLogs(logs: string[]) {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(GLOBAL_DHARMA_LOGS_KEY, JSON.stringify(logs.slice(-120)));
  } catch {
    // 忽略私密模式或存储配额错误；内存态日志仍然可用。
  }
}

function isLikelyUrl(value: string) {
  return /^https?:\/\/\S+$/i.test(value.trim());
}

function stripHtmlToText(html: string) {
  if (typeof DOMParser === "undefined") return html;
  const doc = new DOMParser().parseFromString(html, "text/html");
  doc.querySelectorAll("script,style,noscript,svg").forEach((node) => node.remove());
  return (doc.body?.innerText || html).replace(/\n{3,}/g, "\n\n").trim();
}

function titleFromHtml(html: string, fallback: string) {
  if (typeof DOMParser === "undefined") return fallback;
  const doc = new DOMParser().parseFromString(html, "text/html");
  return doc.querySelector("title")?.textContent?.trim() || fallback;
}

function previewText(value: string) {
  return value.replace(/\s+/g, " ").trim().slice(0, 120);
}

function encodeBase64Utf8(value: string) {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte);
  });
  return btoa(binary);
}

function utf8ByteLength(value: string) {
  return new TextEncoder().encode(value).byteLength;
}

function sleep(ms: number) {
  return new Promise((resolve) => window.setTimeout(resolve, ms));
}

class GlobalDharmaTransferModel {
  private socketId: string | null = null;
  private stopRequested = false;
  private status: GlobalDharmaTransferStatus = {
    isPreparingSend: false,
    isTransferring: false,
    message: "等待发送",
    sentCount: 0,
    sentMB: 0,
    hasFiles: false,
    selectedContent: null,
    options: {
      regionMode: "global",
      global: true,
      countryCodes: ["ALL"],
      loop: false,
      fieldEnergy: false,
      localLoopback: false,
    },
    hotspot: null,
    lastError: null,
  };

  constructor(
    private readonly onStatus: (status: GlobalDharmaTransferStatus) => void,
    private readonly onLog: (message: string) => void,
  ) {}

  snapshot() {
    return {
      ...this.status,
      options: { ...this.status.options },
      selectedContent: this.status.selectedContent ? { ...this.status.selectedContent } : null,
    };
  }

  configure(region: RegionPreset, loop: boolean) {
    this.patchStatus({
      options: {
        regionMode: region.id,
        global: region.global === true,
        countryCodes: region.countryCodes || [],
        loop,
        fieldEnergy: region.fieldEnergy === true,
        localLoopback: region.localLoopback === true,
      },
    });
  }

  setSelectedMaterial(material: TransferMaterial | null) {
    this.patchStatus({
      hasFiles: Boolean(material),
      selectedContent: material,
    });
  }

  async start(options: TransferStartOptions) {
    if (this.status.isPreparingSend || this.status.isTransferring) return this.snapshot();
    this.stopRequested = false;
    this.configure(options.region, options.loop);
    this.patchStatus({
      isPreparingSend: true,
      message: "正在准备内容",
      lastError: null,
    });

    await this.ensureCapabilities(options.region);
    const content = await this.prepareContent(options);
    const packets = this.chunkContent(content, options.region);
    const targets = await this.selectTargets(options.region);

    if (packets.length === 0) {
      throw new Error("没有可发送的数据包");
    }
    if (targets.length === 0) {
      throw new Error("没有可用 UDP 目标");
    }

    if (options.region.fieldEnergy) {
      const hotspot = await miniAppHost.hotspot.openSettings({ reason: "field-energy" });
      this.patchStatus({ hotspot });
      if (hotspot?.message) this.onLog(hotspot.message);
    }

    const socket = await miniAppHost.network.udp.open({
      port: 0,
      broadcast: true,
      reuseAddress: true,
    });
    this.socketId = socket?.socketId;

    this.patchStatus({
      isPreparingSend: false,
      isTransferring: true,
      message: `正在发送 ${packets.length} 个分包`,
      hasFiles: true,
      selectedContent: content,
      sentCount: 0,
      sentMB: 0,
    });
    await miniAppHost.system.keepAwake({
      enabled: true,
      reason: "global-dharma-transfer",
    }).catch(() => {});

    try {
      let round = 0;
      do {
        round += 1;
        await this.sendRound({ packets, targets, region: options.region, round });
        if (!options.loop || this.stopRequested) break;
        this.patchStatus({ message: `第 ${round} 轮完成，等待下一轮` });
        await sleep(1200);
      } while (!this.stopRequested);

      this.patchStatus({
        isTransferring: false,
        message: this.stopRequested ? "传输已停止" : "传输完成",
      });
      return this.snapshot();
    } catch (error: any) {
      this.patchStatus({
        isPreparingSend: false,
        isTransferring: false,
        message: "传输失败",
        lastError: error?.message || String(error),
      });
      throw error;
    } finally {
      await this.closeSocket();
      await miniAppHost.system.keepAwake({ enabled: false }).catch(() => {});
    }
  }

  async stop() {
    this.stopRequested = true;
    await this.closeSocket();
    this.patchStatus({
      isPreparingSend: false,
      isTransferring: false,
      message: "传输已停止",
    });
    await miniAppHost.system.keepAwake({ enabled: false }).catch(() => {});
    return this.snapshot();
  }

  private async ensureCapabilities(region: RegionPreset) {
    const required = [
      { id: "network.udp", reason: "发送 UDP 数据包" },
      { id: "network.interfaces", reason: "选择广播目标" },
      { id: "system.keepAwake", reason: "发送期间保持唤醒" },
      ...(region.fieldEnergy ? [{ id: "hotspot.settings", reason: "打开热点设置" }] : []),
    ];
    try {
      const result = await miniAppHost.app.requestCapabilities(required);
      const blocked = (result?.capabilities || []).filter((item: any) => item.status !== "granted");
      if (blocked.length > 0) {
        throw new Error(`宿主未开放能力：${blocked.map((item: any) => item.id).join(", ")}`);
      }
    } catch (error: any) {
      if (!isHostErrorCode(error, "unknown_method")) throw error;
      const fallback = await miniAppHost.app.getCapabilities();
      const available = new Set(fallback?.capabilities || []);
      const missing = required.filter((item) => !available.has(item.id));
      if (missing.length > 0) {
        throw new Error(`宿主未开放能力：${missing.map((item) => item.id).join(", ")}`);
      }
    }
  }

  private async prepareContent(options: TransferStartOptions): Promise<PreparedTransferContent> {
    const rawText = options.text.trim();
    let title = options.title || "小程序全球法布施";
    let text = rawText;
    let sourceUrl: string | undefined;

    if (isLikelyUrl(rawText)) {
      sourceUrl = rawText;
      try {
        this.onLog("正在由小程序读取链接正文...");
        const response = await fetch(rawText, { credentials: "omit" });
        const body = await response.text();
        const contentType = response.headers.get("content-type") || "";
        title = contentType.includes("html") ? titleFromHtml(body, title) : title;
        text = contentType.includes("html") ? stripHtmlToText(body) : body.trim();
      } catch {
        this.onLog("链接正文无法直接读取，将发送链接本身。");
        text = rawText;
      }
    }

    if (options.selectedMaterial) {
      text = text ? `${text}\n\n${options.selectedMaterial.payloadText}` : options.selectedMaterial.payloadText;
      title = options.selectedMaterial.title || title;
    }

    if (!text.trim()) throw new Error("请输入链接、正文，或选择素材");
    return {
      kind: sourceUrl ? "url" : options.selectedMaterial ? options.selectedMaterial.kind : "text",
      title,
      text: text.trim(),
      previewText: previewText(text),
      sourceUrl,
    };
  }

  private chunkContent(content: PreparedTransferContent, region: RegionPreset) {
    const chars = Array.from(content.text);
    const chunks: string[] = [];
    for (let index = 0; index < chars.length; index += DEFAULT_PACKET_CHARS) {
      chunks.push(chars.slice(index, index + DEFAULT_PACKET_CHARS).join(""));
    }
    const taskId = `gdt_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    return chunks.map((chunk, index) => ({
      protocol: "fabushi.global-dharma.v1",
      taskId,
      packetId: `${taskId}_${index + 1}`,
      sequence: index + 1,
      total: chunks.length,
      title: content.title,
      sourceUrl: content.sourceUrl || null,
      regionMode: region.id,
      countryCodes: region.countryCodes || [],
      createdAt: new Date().toISOString(),
      payload: chunk,
    }));
  }

  private async selectTargets(region: RegionPreset): Promise<TransferTarget[]> {
    if (region.localLoopback) {
      return [{ host: "127.0.0.1", port: GLOBAL_DHARMA_UDP_PORT, label: "本地转经轮" }];
    }

    const targets = new Map<string, TransferTarget>();
    targets.set("255.255.255.255", {
      host: "255.255.255.255",
      port: GLOBAL_DHARMA_UDP_PORT,
      label: region.fieldEnergy ? "热点广播" : "全局广播",
    });

    try {
      const data = await miniAppHost.network.interfaces.list({ includeLoopback: false });
      for (const item of data?.interfaces || []) {
        for (const address of item.addresses || []) {
          if (address.suggestedBroadcast && !targets.has(address.suggestedBroadcast)) {
            targets.set(address.suggestedBroadcast, {
              host: address.suggestedBroadcast,
              port: GLOBAL_DHARMA_UDP_PORT,
              label: item.name || "局域网广播",
            });
          }
        }
      }
    } catch (error: any) {
      this.onLog(error?.message || "网卡列表读取失败，将使用默认广播地址。");
    }

    return Array.from(targets.values());
  }

  private async sendRound({
    packets,
    targets,
    region,
    round,
  }: {
    packets: Array<Record<string, any>>;
    targets: TransferTarget[];
    region: RegionPreset;
    round: number;
  }) {
    if (!this.socketId) throw new Error("UDP socket 尚未打开");
    for (const packet of packets) {
      for (const target of targets) {
        if (this.stopRequested) return;
        const payload = {
          ...packet,
          round,
          target: {
            label: target.label,
            regionMode: region.id,
            countryCodes: region.countryCodes || [],
          },
          sentAt: new Date().toISOString(),
        };
        const data = encodeBase64Utf8(JSON.stringify(payload));
        await this.sendWithRetry(target, data);
        const sentMB = this.status.sentMB + utf8ByteLength(JSON.stringify(payload)) / (1024 * 1024);
        this.patchStatus({
          sentCount: this.status.sentCount + 1,
          sentMB,
          message: `第 ${round} 轮：${packet.sequence}/${packet.total} -> ${target.label}`,
        });
        await sleep(50);
      }
    }
  }

  private async sendWithRetry(target: TransferTarget, data: string) {
    let lastError: unknown;
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      try {
        await miniAppHost.network.udp.send({
          socketId: this.socketId,
          host: target.host,
          port: target.port,
          data,
        });
        return;
      } catch (error) {
        lastError = error;
        await sleep(120 * attempt);
      }
    }
    throw lastError;
  }

  private async closeSocket() {
    if (!this.socketId) return;
    const socketId = this.socketId;
    this.socketId = null;
    await miniAppHost.network.udp.close({ socketId }).catch(() => {});
  }

  private patchStatus(patch: Partial<GlobalDharmaTransferStatus>) {
    this.status = {
      ...this.status,
      ...patch,
      options: patch.options ? { ...patch.options } : this.status.options,
    };
    this.onStatus(this.snapshot());
  }
}

export default function GlobalDharmaApp() {
  const [text, setText] = useState("");
  const [status, setStatus] = useState<GlobalDharmaTransferStatus | null>(null);
  const [regionId, setRegionId] = useState("global");
  const [loopEnabled, setLoopEnabled] = useState(false);
  const [highEnergyUnlocked, setHighEnergyUnlocked] = useState(false);
  const [selectedMaterial, setSelectedMaterial] = useState<TransferMaterial | null>(null);
  const [logs, setLogs] = useState<string[]>(readStoredGlobalDharmaLogs);
  const [busy, setBusy] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const earthRef = useRef<THREE.Mesh | null>(null);
  const particlesRef = useRef<THREE.Points | null>(null);
  const transferringRef = useRef(false);
  const transferModelRef = useRef<GlobalDharmaTransferModel | null>(null);
  const handleStartRef = useRef<((overrideText?: string, commandId?: string) => Promise<void>) | null>(null);
  const selectedRegion = useMemo(
    () => regionPresets.find((item) => item.id === regionId) || regionPresets[0],
    [regionId],
  );

  const log = (msg: string) => {
    const line = `[${new Date().toLocaleTimeString()}] ${msg}`;
    setLogs((prev) => {
      const next = [...prev, line].slice(-120);
      storeGlobalDharmaLogs(next);
      return next;
    });
  };

  if (!transferModelRef.current) {
    transferModelRef.current = new GlobalDharmaTransferModel(setStatus, log);
  }

  const saveHighEnergyPurchase = (payment: any) => {
    highEnergyPurchaseCache.save(payment);
    setHighEnergyUnlocked(true);
  };

  const clearHighEnergyPurchase = () => {
    highEnergyPurchaseCache.clear();
    setHighEnergyUnlocked(false);
  };

  const isPaidPayment = (payment: any) => {
    const paymentStatus = String(payment?.status || payment?.order?.status || payment?.resultStatus || "").toUpperCase();
    return payment?.paid === true || paymentStatus === "PAID" || paymentStatus === "SUCCESS" || paymentStatus === "9000";
  };

  const checkHighEnergyEntitlement = async (
    options: { silent?: boolean } = {},
  ): Promise<EntitlementState> => {
    try {
      const entitlement = await miniAppHost.payments.checkEntitlement(HIGH_ENERGY_PRODUCT.productId);
      if (entitlement === "unlocked") {
        saveHighEnergyPurchase({
          provider: "host",
          source: "entitlement",
          productId: HIGH_ENERGY_PRODUCT.productId,
        });
        return "unlocked";
      }
      if (entitlement === "unavailable") return "unavailable";
      clearHighEnergyPurchase();
      return "locked";
    } catch (error: any) {
      if (!options.silent) {
        log(error.message || "购买权益查询失败");
      }
      return "unavailable";
    }
  };

  useEffect(() => {
    transferringRef.current = Boolean(status?.isTransferring);
  }, [status?.isTransferring]);

  useEffect(() => {
    setHighEnergyUnlocked(highEnergyPurchaseCache.read());
    setStatus(transferModelRef.current?.snapshot() || null);
    const refresh = () => {
      if (!isHostReady()) return;
      checkHighEnergyEntitlement({ silent: true });
      miniAppHost.app.requestCapabilities([
        { id: "network.udp", reason: "发送 UDP 数据包" },
        { id: "network.interfaces", reason: "选择广播目标" },
        { id: "system.keepAwake", reason: "发送期间保持唤醒" },
        { id: "hotspot.settings", reason: "本地场能热点" },
      ]).catch((error) => log(error.message));
    };
    const unsubscribeReady = onMiniAppReady(refresh);
    const unsubscribeMessage = miniAppHost.bot.onMessage?.((msg) => {
      setText(msg);
      log(`已收到内容: ${msg}`);
      if (isLikelyUrl(msg)) {
        handleStartRef.current?.(msg);
      }
    });
    const unsubscribeCommand = (
      miniAppHost.bot.exposeCommand?.(
        "/start",
        (args, event) => {
          log("收到 /start 命令");
          if (args) setText(args);
          handleStartRef.current?.(args || undefined, event?.commandId);
        },
        { description: "启动全球法布施" },
      ) ||
      miniAppHost.bot.onCommand?.("/start", (args, event) => {
        log("收到 /start 命令");
        if (args) setText(args);
        handleStartRef.current?.(args || undefined, event?.commandId);
      })
    );

    const { startParam } = miniAppHost.bot.getInitData?.() || {};
    if (startParam) {
      setText(startParam);
      log(`收到启动参数: ${startParam}`);
      if (isLikelyUrl(startParam)) {
        setTimeout(() => handleStartRef.current?.(startParam), 100);
      }
    }

    return () => {
      unsubscribeReady();
      unsubscribeMessage?.();
      unsubscribeCommand?.();
    };
  }, []);

  const waitForPaymentConfirmation = async (orderId: string) => {
    for (let i = 0; i < 8; i += 1) {
      await new Promise((resolve) => window.setTimeout(resolve, i === 0 ? 600 : 2500));
      const queried = await miniAppHost.payments.alipay.queryOrder(orderId);
      if (isPaidPayment(queried)) return queried;
    }
    return null;
  };

  const ensureHighEnergyPurchase = async () => {
    const localUnlocked = highEnergyUnlocked || highEnergyPurchaseCache.read();
    if (localUnlocked) {
      const entitlement = await checkHighEnergyEntitlement({ silent: true });
      if (entitlement !== "locked") {
        if (entitlement === "unavailable") setHighEnergyUnlocked(true);
        return true;
      }
      log("本地购买记录未在宿主后端确认，将重新发起支付。");
    }
    log(`${HIGH_ENERGY_PRODUCT.title}需要购买，正在请求宿主支付能力。`);
    try {
      await miniAppHost.auth.requireLogin();
    } catch (error: any) {
      if (isHostErrorCode(error, "unknown_method", "permission_denied")) {
        log("宿主没有提供登录确认接口，将继续尝试支付。");
      } else {
        throw error;
      }
    }
    const entitlement = await checkHighEnergyEntitlement();
    if (entitlement === "unlocked") {
      log(`${HIGH_ENERGY_PRODUCT.title}已同步购买权益。`);
      return true;
    }

    try {
      const tokenPayment = await miniAppHost.payments.requestPayment({
        productId: HIGH_ENERGY_PRODUCT.productId,
        title: HIGH_ENERGY_PRODUCT.title,
        amount: HIGH_ENERGY_PRODUCT.fudeGoldPrice,
        currency: "FUDE_GOLD",
        idempotencyKey: `${HIGH_ENERGY_PRODUCT.productId}:${Date.now()}`,
      });
      if (isPaidPayment(tokenPayment)) {
        saveHighEnergyPurchase(tokenPayment);
        log(`福德金支付成功，剩余 ${tokenPayment?.balance ?? 0} 福德金。`);
        return true;
      }
    } catch (error: any) {
      if (isHostErrorCode(error, "payment_cancelled")) {
        log("已取消福德金支付。");
        return false;
      }
      if (isHostErrorCode(error, "wallet_insufficient_funds")) {
        log("福德金余额不足，将尝试支付宝支付。");
      } else if (isHostErrorCode(error, "unknown_method", "permission_denied", "unsupported_currency")) {
        log("宿主暂未提供福德金支付，将尝试支付宝支付。");
      } else {
        throw error;
      }
    }

    const order = await miniAppHost.payments.alipay.createOrder({
      productId: HIGH_ENERGY_PRODUCT.productId,
      title: HIGH_ENERGY_PRODUCT.title,
      subject: HIGH_ENERGY_PRODUCT.title,
      amount: HIGH_ENERGY_PRODUCT.amount,
      priceLabel: HIGH_ENERGY_PRODUCT.priceLabel,
    });
    const payment = await miniAppHost.payments.alipay.pay({
      ...order,
      productId: HIGH_ENERGY_PRODUCT.productId,
      title: HIGH_ENERGY_PRODUCT.title,
    });
    if (isPaidPayment(payment)) {
      saveHighEnergyPurchase(payment);
      log("支付成功，购买记录已由小程序保存。");
      return true;
    }
    const confirmed = order?.orderId ? await waitForPaymentConfirmation(order.orderId) : null;
    if (confirmed && isPaidPayment(confirmed)) {
      saveHighEnergyPurchase(confirmed);
      log("支付成功，购买记录已由小程序保存。");
      return true;
    }
    log(payment?.message || "支付已发起，尚未确认成功。");
    return false;
  };

  useEffect(() => {
    if (!containerRef.current) return;

    const width = containerRef.current.clientWidth;
    const height = 280;
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
    camera.position.z = 2.7;

    const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
    renderer.setSize(width, height);
    renderer.setPixelRatio(window.devicePixelRatio);
    containerRef.current.appendChild(renderer.domElement);
    rendererRef.current = renderer;

    const geometry = new THREE.SphereGeometry(1, 64, 64);
    const material = new THREE.MeshBasicMaterial({
      color: 0x4CAF7A,
      wireframe: true,
      transparent: true,
      opacity: 0.3,
    });

    const earth = new THREE.Mesh(geometry, material);
    scene.add(earth);
    earthRef.current = earth;

    const particleGeo = new THREE.BufferGeometry();
    const particleCount = 1000;
    const posArray = new Float32Array(particleCount * 3);
    for (let i = 0; i < particleCount * 3; i += 1) {
      posArray[i] = (Math.random() - 0.5) * 2;
    }
    particleGeo.setAttribute("position", new THREE.BufferAttribute(posArray, 3));
    const particleMat = new THREE.PointsMaterial({
      size: 0.02,
      color: 0x88FFB4,
      transparent: true,
      opacity: 0,
    });
    const particles = new THREE.Points(particleGeo, particleMat);
    scene.add(particles);
    particlesRef.current = particles;

    let animationId: number;
    const animate = () => {
      animationId = requestAnimationFrame(animate);
      if (earthRef.current) {
        earthRef.current.rotation.y += 0.005;
        earthRef.current.rotation.x += 0.002;
      }
      if (particlesRef.current && transferringRef.current) {
        particlesRef.current.rotation.y -= 0.01;
        (particlesRef.current.material as THREE.PointsMaterial).opacity = 0.5 + Math.sin(Date.now() * 0.005) * 0.5;
      } else if (particlesRef.current) {
        (particlesRef.current.material as THREE.PointsMaterial).opacity = 0;
      }
      renderer.render(scene, camera);
    };
    animate();

    return () => {
      cancelAnimationFrame(animationId);
      if (containerRef.current && rendererRef.current) {
        containerRef.current.removeChild(rendererRef.current.domElement);
      }
      geometry.dispose();
      material.dispose();
      particleGeo.dispose();
      particleMat.dispose();
      renderer.dispose();
    };
  }, []);

  const syncModelOptions = (preset = selectedRegion, loop = loopEnabled) => {
    transferModelRef.current?.configure(preset, loop);
    setStatus(transferModelRef.current?.snapshot() || null);
  };

  const handleStart = async (overrideText?: string, commandId?: string) => {
    const t = overrideText ?? text;
    if (!t.trim() && !selectedMaterial) {
      log("请先输入链接、正文，或选择高能素材");
      return;
    }
    setBusy(true);
    try {
      log("正在由小程序创建传输任务...");
      const data = await transferModelRef.current!.start({
        title: selectedMaterial?.title || "小程序全球法布施",
        text: t.trim(),
        region: selectedRegion,
        loop: loopEnabled,
        selectedMaterial,
      });
      setStatus(data);
      log(data.message || "传输任务已更新。");
      if (commandId) {
        await miniAppHost.bot.reportCommandResult?.({
          commandId,
          status: "completed",
          message: `全球法布施已启动：${data?.selectedContent?.title || "小程序内容"}`,
          data,
        });
      }
    } catch (error: any) {
      log(error.message || "启动失败");
      if (commandId) {
        await miniAppHost.bot.reportCommandResult?.({
          commandId,
          status: "failed",
          message: error.message || "全球法布施启动失败",
        }).catch(() => {});
      }
    } finally {
      setBusy(false);
    }
  };
  handleStartRef.current = handleStart;

  const handleStop = async () => {
    try {
      log("正在停止全球传输...");
      const data = await transferModelRef.current!.stop();
      setStatus(data);
      log("传输已停止。");
    } catch (error: any) {
      log(error.message || "停止失败");
    }
  };

  const handleRegionChange = async (preset: RegionPreset) => {
    setRegionId(preset.id);
    syncModelOptions(preset);
    log(`地区模式已切换：${preset.label}`);
    if (preset.fieldEnergy) {
      try {
        const hotspot = await miniAppHost.hotspot.openSettings({ reason: "field-energy-preview" });
        log(hotspot?.message || "请按系统提示开启热点。");
      } catch (error: any) {
        log(error.message || "热点设置打开失败");
      }
    }
  };

  const handleMaterial = async () => {
    setBusy(true);
    try {
      log("正在准备高能素材...");
      const unlocked = await ensureHighEnergyPurchase();
      if (!unlocked) return;
      setSelectedMaterial(highEnergyMaterial);
      transferModelRef.current?.setSelectedMaterial(highEnergyMaterial);
      setStatus(transferModelRef.current?.snapshot() || null);
      log("已选择高能素材。");
    } catch (error: any) {
      if (isHostErrorCode(error, "login_required")) {
        log("需要先登录，正在请求宿主打开登录。");
        try {
          await miniAppHost.auth.requireLogin();
          const unlocked = await ensureHighEnergyPurchase();
          if (!unlocked) return;
          setSelectedMaterial(highEnergyMaterial);
          transferModelRef.current?.setSelectedMaterial(highEnergyMaterial);
          setStatus(transferModelRef.current?.snapshot() || null);
          log("已选择高能素材。");
        } catch (nextError: any) {
          log(nextError.message || "素材选择失败");
        }
      } else {
        log(error.message || "素材选择失败");
      }
    } finally {
      setBusy(false);
    }
  };

  const handleLoopChange = (checked: boolean) => {
    setLoopEnabled(checked);
    syncModelOptions(selectedRegion, checked);
    log(checked ? "循环发送已开启" : "循环发送已关闭");
  };

  const refreshStatus = () => {
    setStatus(transferModelRef.current?.snapshot() || null);
  };

  return (
    <div className="ma-panel ma-global ma-fade-in" style={{ "--accent-start": "#4CAF7A", "--accent-end": "#2E7D32", "--accent-rgb": "76, 175, 122" } as any}>
      <div className="ma-title-row">
        <div>
          <h1 className="ma-header-title">全球法布施</h1>
          <p className="ma-header-subtitle">已发送 {status?.sentCount || 0} 个节点 · {(status?.sentMB || 0).toFixed(2)} MB</p>
        </div>
        <button className="ma-icon-btn" onClick={refreshStatus} aria-label="刷新状态">
          <RefreshCw size={18} />
        </button>
      </div>

      <div
        ref={containerRef}
        className="ma-earth"
      />

      <label className="ma-label">地区模式</label>
      <div className="ma-segment-grid">
        {regionPresets.map((preset) => (
          <button
            key={preset.id}
            className={`ma-chip-btn ${regionId === preset.id ? "active" : ""}`}
            onClick={() => handleRegionChange(preset)}
          >
            <Globe size={15} />
            {preset.label}
          </button>
        ))}
      </div>

      <div className="ma-toggle-row ma-compact-toggle">
        <div className="ma-toggle-info">
          <span className="ma-toggle-title">循环发送</span>
          <span className="ma-toggle-desc">{loopEnabled ? "持续循环" : "单轮发送"}</span>
        </div>
        <label className="ma-switch">
          <input type="checkbox" checked={loopEnabled} onChange={(event) => handleLoopChange(event.target.checked)} />
          <span className="ma-slider"></span>
        </label>
      </div>

      <label className="ma-label">高能素材</label>
      <button className={`ma-material-button ${selectedMaterial ? "selected" : ""}`} onClick={handleMaterial} disabled={busy}>
        <Sparkles size={18} />
        <span>{selectedMaterial?.title || `${HIGH_ENERGY_PRODUCT.title}${highEnergyUnlocked ? " · 已购买" : ` · ${HIGH_ENERGY_PRODUCT.fudeGoldPriceLabel}`}`}</span>
      </button>

      <label className="ma-label">链接或正文</label>
      <textarea
        className="ma-textarea"
        placeholder="输入链接后发送，会自动提取正文。"
        value={text}
        onChange={(e) => setText(e.target.value)}
      />

      {selectedMaterial?.previewText && (
        <div className="ma-selected-content">
          <Link2 size={15} />
          <span>{selectedMaterial.previewText}</span>
        </div>
      )}

      <div className="ma-action-row">
        <button className="ma-btn" onClick={() => handleStart()} disabled={busy || status?.isPreparingSend}>
          <Send size={19} />
          {busy || status?.isPreparingSend ? "准备中" : "发送"}
        </button>
        {status?.isTransferring && (
          <button className="ma-btn ma-btn-secondary" onClick={handleStop}>
            <CircleStop size={19} />
            停止
          </button>
        )}
      </div>

      {logs.length > 0 && (
        <div className="ma-log-box">
          {logs.map((item, index) => <div key={index}>{item}</div>)}
        </div>
      )}
    </div>
  );
}
