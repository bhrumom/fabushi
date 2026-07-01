"use client";

import React, { useEffect, useMemo, useRef, useState } from "react";
import { CircleStop, Globe, Link2, RefreshCw, Send, Sparkles } from "lucide-react";
import * as THREE from "three";
import { bootMiniApp, fbApp, hostErrorMessage } from "./miniapp-runtime";
import "./miniapps.css";

type RegionPreset = {
  id: string;
  label: string;
  global?: boolean;
  countryCodes?: string[];
  fieldEnergy?: boolean;
  localLoopback?: boolean;
};

type PreparedContent = {
  title: string;
  text: string;
  previewText: string;
  sourceUrl?: string;
  charCount: number;
};

type DharmaStatus = {
  sentCount: number;
  sentMB: number;
  isTransferring: boolean;
  isPreparingSend: boolean;
  selectedContent?: PreparedContent | null;
  wifiHotspot?: { message: string };
  updatedAt?: string;
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
};
const HIGH_ENERGY_PURCHASE_KEY = "fabushi.official.global-dharma.purchase.zen_buddha_asset";
const HIGH_ENERGY_MATERIAL: PreparedContent = {
  title: "3D佛像素材",
  text: "3D佛像素材",
  previewText: "已选择本机素材：3D佛像素材",
  charCount: 6,
};
const INITIAL_STATUS: DharmaStatus = {
  sentCount: 0,
  sentMB: 0,
  isTransferring: false,
  isPreparingSend: false,
  selectedContent: null,
};

function isPaidPayment(payment: any) {
  const status = String(payment?.status || payment?.order?.status || payment?.resultStatus || "").toUpperCase();
  return payment?.paid === true || status === "PAID" || status === "SUCCESS" || status === "TRADE_SUCCESS" || status === "9000";
}

function extractFirstHttpUrl(value: string) {
  const match = value.trim().match(/https?:\/\/[^\s<>'"，。、《》【】]+/i);
  return match?.[0]?.replace(/[，。、,.)）\]】>》]+$/g, "").trim() || "";
}

function looksLikeHttpUrl(value: string) {
  const trimmed = value.trim();
  const url = extractFirstHttpUrl(trimmed);
  return Boolean(url && trimmed === url);
}

function decodeHtmlEntities(value: string) {
  if (typeof document === "undefined") {
    return value
      .replace(/&nbsp;/g, " ")
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'");
  }
  const textarea = document.createElement("textarea");
  textarea.innerHTML = value;
  return textarea.value;
}

function extractHtmlTitle(html: string, fallback: string) {
  const match = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  return decodeHtmlEntities(match?.[1] || fallback).replace(/\s+/g, " ").trim();
}

function htmlToText(html: string) {
  return decodeHtmlEntities(
    html
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<noscript[\s\S]*?<\/noscript>/gi, " ")
      .replace(/<\/(p|div|section|article|li|h\d|br)>/gi, "\n")
      .replace(/<[^>]+>/g, " "),
  )
    .replace(/[\t\f\v ]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function byteSize(textValue: string) {
  return new TextEncoder().encode(textValue).length;
}

function normalizeHeaderMap(headers: any): Record<string, string> {
  const normalized: Record<string, string> = {};
  if (!headers || typeof headers !== "object") return normalized;
  Object.entries(headers).forEach(([key, value]) => {
    normalized[key.toLowerCase()] = String(value ?? "");
  });
  return normalized;
}

function charsetFromHeaders(headers: any) {
  const contentType = normalizeHeaderMap(headers)["content-type"] || "";
  return contentType.match(/charset\s*=\s*["']?([^\s;"']+)/i)?.[1] || "";
}

function normalizeCharset(label: string) {
  const raw = label.trim().toLowerCase().replace(/^['"]|['"]$/g, "");
  if (!raw) return "";
  if (["utf8", "utf-8", "unicode-1-1-utf-8"].includes(raw)) return "utf-8";
  if (["gb2312", "gbk", "gb18030", "cp936", "hz-gb-2312"].includes(raw)) return "gb18030";
  if (["big5", "big-5", "big5-hkscs", "x-x-big5"].includes(raw)) return "big5";
  return raw;
}

function bytesFromBase64(base64Value: string) {
  const binary = window.atob(base64Value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function sniffCharsetFromBytes(bytes: Uint8Array) {
  const preview = Array.from(bytes.slice(0, Math.min(bytes.length, 4096)))
    .map((code) => String.fromCharCode(code))
    .join("");
  return preview.match(/charset\s*=\s*["']?([^\s;"'>]+)/i)?.[1] || "";
}

function textQualityScore(value: string) {
  const replacements = (value.match(/\uFFFD/g) || []).length;
  const controls = (value.match(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g) || []).length;
  const cjk = (value.match(/[\u3400-\u9FFF]/g) || []).length;
  return replacements * 1000 + controls * 20 - cjk;
}

function decodeHostHttpBody(response: any) {
  const bodyBase64 = typeof response?.bodyBase64 === "string" ? response.bodyBase64 : "";
  if (!bodyBase64 || typeof window === "undefined" || typeof TextDecoder === "undefined") {
    return String(response?.body || "");
  }

  const bytes = bytesFromBase64(bodyBase64);
  const candidates = [
    normalizeCharset(String(response?.bodyTextEncoding || "")),
    normalizeCharset(charsetFromHeaders(response?.headers)),
    normalizeCharset(sniffCharsetFromBytes(bytes)),
    "utf-8",
    "gb18030",
    "big5",
  ].filter(Boolean);
  const uniqueCandidates = Array.from(new Set(candidates));

  let best = String(response?.body || "");
  let bestScore = best ? textQualityScore(best) : Number.POSITIVE_INFINITY;
  for (const label of uniqueCandidates) {
    try {
      const decoded = new TextDecoder(label, { fatal: false }).decode(bytes);
      const score = textQualityScore(decoded);
      if (!best || score < bestScore) {
        best = decoded;
        bestScore = score;
      }
    } catch {
      // Some WebViews do not ship every legacy decoder. Keep trying.
    }
  }
  return best;
}

export default function GlobalDharmaApp() {
  const [text, setText] = useState("");
  const [status, setStatus] = useState<DharmaStatus>(INITIAL_STATUS);
  const [regionId, setRegionId] = useState("global");
  const [loopEnabled, setLoopEnabled] = useState(true);
  const [highEnergyUnlocked, setHighEnergyUnlocked] = useState(false);
  const [selectedMaterial, setSelectedMaterial] = useState<PreparedContent | null>(null);
  const [logs, setLogs] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const earthRef = useRef<THREE.Mesh | null>(null);
  const particlesRef = useRef<THREE.Points | null>(null);
  const transferringRef = useRef(false);
  const loopTimerRef = useRef<number | null>(null);
  const selectedRegion = useMemo(
    () => regionPresets.find((item) => item.id === regionId) || regionPresets[0],
    [regionId],
  );

  const log = (msg: string) => setLogs((prev) => [...prev, `[${new Date().toLocaleTimeString()}] ${msg}`]);

  const readHighEnergyPurchase = async () => {
    try {
      const raw = await fbApp.storage.deviceStorage.getItem(HIGH_ENERGY_PURCHASE_KEY);
      if (!raw) return false;
      const record = JSON.parse(raw);
      return record?.productId === HIGH_ENERGY_PRODUCT.productId && record?.paid === true;
    } catch {
      return false;
    }
  };

  const saveHighEnergyPurchase = async (payment: any) => {
    const record = {
      productId: HIGH_ENERGY_PRODUCT.productId,
      title: HIGH_ENERGY_PRODUCT.title,
      priceLabel: HIGH_ENERGY_PRODUCT.priceLabel,
      paid: true,
      paidAt: new Date().toISOString(),
      payment,
    };
    await fbApp.storage.deviceStorage.setItem(HIGH_ENERGY_PURCHASE_KEY, JSON.stringify(record));
    setHighEnergyUnlocked(true);
  };

  const stopLoopTimer = () => {
    if (loopTimerRef.current === null) return;
    window.clearInterval(loopTimerRef.current);
    loopTimerRef.current = null;
  };

  const updateStatus = (next: Partial<DharmaStatus>) => {
    setStatus((prev) => ({ ...prev, ...next, updatedAt: new Date().toISOString() }));
  };

  const postBotMessage = async (message: string, payload: any = {}) => {
    try {
      await fbApp.invoke("bot.postMessage", {
        level: "info",
        message,
        text: message,
        payload,
      });
    } catch (error) {
      log(hostErrorMessage(error, "聊天回写失败"));
    }
  };

  const fetchUrlContent = async (url: string): Promise<PreparedContent> => {
    const buildPrepared = (body: string) => {
      const title = extractHtmlTitle(body, new URL(url).hostname || "链接内容");
      const plainText = htmlToText(body) || body || url;
      return {
        title,
        text: plainText,
        previewText: plainText.slice(0, 180),
        sourceUrl: url,
        charCount: plainText.length,
      };
    };

    try {
      const response = await fbApp.invoke<any>("network.http.fetch", {
        url,
        method: "GET",
        timeoutMs: 15000,
        maxBodyBytes: 1024 * 1024,
        headers: {
          Accept: "text/html,text/plain,application/xhtml+xml,*/*",
          "User-Agent": "FabushiMiniApp/GlobalDharma",
        },
        responseEncoding: "base64+text",
      });
      const statusCode = Number(response?.statusCode || 0);
      if (statusCode && (statusCode < 200 || statusCode >= 300)) {
        throw new Error(`HTTP ${statusCode}`);
      }
      const body = decodeHostHttpBody(response);
      const prepared = buildPrepared(body);
      if (prepared.text.length < 20) throw new Error("网页正文过短");
      log(`已读取链接正文：${prepared.title}（${prepared.charCount} 字）`);
      return prepared;
    } catch (hostError) {
      log(hostErrorMessage(hostError, "宿主链接读取失败，尝试浏览器读取。"));
      try {
        const browserResponse = await fetch(url, {
          cache: "no-store",
          headers: { Accept: "text/html,text/plain,application/xhtml+xml,*/*" },
        });
        if (!browserResponse.ok) throw new Error(`HTTP ${browserResponse.status}`);
        const prepared = buildPrepared(await browserResponse.text());
        if (prepared.text.length < 20) throw new Error("网页正文过短");
        log(`已通过浏览器读取链接正文：${prepared.title}（${prepared.charCount} 字）`);
        return prepared;
      } catch (browserError) {
        log(hostErrorMessage(browserError, "链接正文无法直接读取，将发送链接本身。"));
        return {
          title: "链接内容",
          text: url,
          previewText: url,
          sourceUrl: url,
          charCount: url.length,
        };
      }
    }
  };

  const prepareTransferContent = async (inputOverride?: string): Promise<PreparedContent> => {
    const raw = (inputOverride ?? text).trim();
    const url = extractFirstHttpUrl(raw);
    if (raw && url && looksLikeHttpUrl(raw)) {
      log("正在通过宿主 network.http.fetch 读取链接正文...");
      const content = await fetchUrlContent(url);
      if (selectedMaterial) {
        return {
          ...content,
          text: `${content.text}\n\n${selectedMaterial.text}`,
          previewText: `${content.previewText}\n${selectedMaterial.previewText}`.slice(0, 220),
          charCount: content.charCount + selectedMaterial.charCount,
        };
      }
      return content;
    }
    if (raw) {
      const merged = selectedMaterial ? `${raw}\n\n${selectedMaterial.text}` : raw;
      return {
        title: selectedMaterial?.title || "小程序全球法布施",
        text: merged,
        previewText: merged.slice(0, 180),
        charCount: merged.length,
      };
    }
    if (selectedMaterial) return selectedMaterial;
    throw new Error("请先输入链接、正文，或选择高能素材");
  };

  const nodeCountFor = (preset: RegionPreset) => {
    if (preset.global && preset.countryCodes?.includes("ALL")) return 108;
    if (preset.countryCodes?.length) return preset.countryCodes.length;
    return 1;
  };

  const startLoopTimer = (content: PreparedContent, nodes: number) => {
    stopLoopTimer();
    loopTimerRef.current = window.setInterval(() => {
      setStatus((prev) => ({
        ...prev,
        isTransferring: true,
        sentCount: prev.sentCount + nodes,
        sentMB: prev.sentMB + (byteSize(content.text) * nodes) / (1024 * 1024),
        updatedAt: new Date().toISOString(),
      }));
    }, 2400);
  };

  useEffect(() => {
    transferringRef.current = Boolean(status?.isTransferring);
  }, [status?.isTransferring]);

  useEffect(() => {
    let active = true;
    const refresh = async () => {
      try {
        const unlocked = await readHighEnergyPurchase();
        if (active) setHighEnergyUnlocked(unlocked);
        await fbApp.getCapabilities();
        if (active) updateStatus({ isPreparingSend: false });
      } catch (error) {
        if (active) log(hostErrorMessage(error, "读取宿主能力失败"));
      }
    };

    void bootMiniApp("official.global-dharma", "全球法布施").then(() => refresh());
    const unsubscribeReady = fbApp.on("ready", () => {
      void refresh();
    });
    return () => {
      active = false;
      stopLoopTimer();
      unsubscribeReady();
    };
  }, []);

  const waitForPaymentConfirmation = async (invoice: any) => {
    for (let i = 0; i < 8; i += 1) {
      await new Promise((resolve) => window.setTimeout(resolve, i === 0 ? 600 : 2500));
      const queried = await fbApp.payments.queryInvoice(invoice);
      if (isPaidPayment(queried)) return queried;
    }
    return null;
  };

  const ensureHighEnergyPurchase = async () => {
    if (highEnergyUnlocked || await readHighEnergyPurchase()) {
      setHighEnergyUnlocked(true);
      return true;
    }
    log(`${HIGH_ENERGY_PRODUCT.title}需要购买，正在请求宿主支付能力。`);
    try {
      await fbApp.auth.requireLogin();
    } catch (error) {
      log(hostErrorMessage(error, "宿主登录能力不可用，将继续尝试支付。"));
    }

    const invoice = await fbApp.payments.createInvoice({
      sku: HIGH_ENERGY_PRODUCT.productId,
      productId: HIGH_ENERGY_PRODUCT.productId,
      title: HIGH_ENERGY_PRODUCT.title,
      subject: HIGH_ENERGY_PRODUCT.title,
      amount: HIGH_ENERGY_PRODUCT.amount,
      currency: "CNY",
      priceLabel: HIGH_ENERGY_PRODUCT.priceLabel,
      metadata: {
        miniAppId: "official.global-dharma",
        entitlement: HIGH_ENERGY_PRODUCT.productId,
      },
    });
    const payment = await fbApp.payments.openInvoice(invoice);
    if (isPaidPayment(payment)) {
      await saveHighEnergyPurchase(payment);
      log("支付成功，购买记录已由小程序 SDK 存储。后续可切换到后端 entitlement。");
      return true;
    }
    const confirmed = await waitForPaymentConfirmation(invoice);
    if (confirmed && isPaidPayment(confirmed)) {
      await saveHighEnergyPurchase(confirmed);
      log("支付成功，购买记录已由小程序 SDK 存储。后续可切换到后端 entitlement。");
      return true;
    }
    log("支付已发起，尚未确认成功。");
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
      if (containerRef.current && rendererRef.current?.domElement.parentElement === containerRef.current) {
        containerRef.current.removeChild(rendererRef.current.domElement);
      }
      geometry.dispose();
      material.dispose();
      particleGeo.dispose();
      particleMat.dispose();
      renderer.dispose();
    };
  }, []);

  const applyOptions = async (preset = selectedRegion, loop = loopEnabled) => {
    if (loop || preset.fieldEnergy) {
      try {
        await fbApp.invoke("system.keepAwake", { enabled: true, reason: "global-dharma-transfer" });
      } catch (error) {
        log(hostErrorMessage(error, "保持唤醒能力不可用"));
      }
    }
    const next = {
      selectedContent: selectedMaterial,
      wifiHotspot: preset.fieldEnergy
        ? { message: "本地场能模式已记录；如需热点，请在系统设置中开启。" }
        : undefined,
    };
    updateStatus(next);
    return next;
  };

  const handleStart = async (inputOverride?: string) => {
    const effectiveText = (inputOverride ?? text).trim();
    if (!effectiveText && !selectedMaterial) {
      log("请先输入链接、正文，或选择高能素材");
      return;
    }
    setBusy(true);
    stopLoopTimer();
    updateStatus({ isPreparingSend: true, isTransferring: false });
    try {
      log("正在由小程序创建传输任务...");
      await applyOptions();
      const content = await prepareTransferContent(effectiveText);
      const nodes = nodeCountFor(selectedRegion);
      const sentMB = (byteSize(content.text) * nodes) / (1024 * 1024);
      await postBotMessage(`全球法布施任务：${content.title}`, {
        miniAppId: "official.global-dharma",
        content,
        region: selectedRegion,
        loop: loopEnabled,
      });
      setStatus((prev) => ({
        ...prev,
        sentCount: prev.sentCount + nodes,
        sentMB: prev.sentMB + sentMB,
        isPreparingSend: false,
        isTransferring: loopEnabled,
        selectedContent: content,
        wifiHotspot: selectedRegion.fieldEnergy
          ? { message: "本地场能模式已记录；如需热点，请在系统设置中开启。" }
          : undefined,
        updatedAt: new Date().toISOString(),
      }));
      if (loopEnabled) {
        startLoopTimer(content, nodes);
        log("启动成功，循环发送中。");
      } else {
        log("传输完成。");
      }
      if (selectedRegion.fieldEnergy) {
        log("本地场能模式已启用，宿主只提供保持唤醒等系统原语。");
      }
      if (selectedRegion.localLoopback) {
        log("本地转经轮模式需要小程序配置本机回环服务地址。");
      }
    } catch (error) {
      log(hostErrorMessage(error, "启动失败"));
      updateStatus({ isPreparingSend: false, isTransferring: false });
    } finally {
      setBusy(false);
    }
  };

  const handleStop = async () => {
    try {
      log("正在停止全球传输...");
      stopLoopTimer();
      await fbApp.invoke("system.keepAwake", { enabled: false }).catch(() => null);
      updateStatus({ isTransferring: false, isPreparingSend: false });
      log("传输已停止。");
    } catch (error) {
      log(hostErrorMessage(error, "停止失败"));
    }
  };

  useEffect(() => {
    if (typeof window === "undefined") return undefined;

    let removeReadyListener: (() => void) | undefined;
    let unsubscribeCommand: (() => void) | undefined;
    const attachCommandListener = () => {
      const hostBot = (window as any).FabushiMiniApp?.bot;
      if (!hostBot || unsubscribeCommand) return;
      const commands = [
        { command: "/start", description: "开始全球循环法布施", order: 1 },
        { command: "/stop", description: "停止当前全球法布施", order: 2 },
        { command: "/loop", description: "切换循环发送开关", order: 3 },
        { command: "/status", description: "查看全球法布施状态", order: 4 },
      ];
      void fbApp.invoke("bot.setInputPlaceholder", {
        placeholder: "输入链接/正文，默认全球循环发送；也可点 + 选择小程序命令",
      }).catch(() => null);
      void fbApp.invoke("bot.setCommands", { commands }).catch(() => null);
      if (typeof hostBot.onAnyCommand === "function") {
        unsubscribeCommand = hostBot.onAnyCommand((detail: any) => {
          const command = String(detail?.command || "/start").trim();
          const incoming = String(detail?.args || detail?.rawText || detail?.text || "").trim();
          if (command === "/stop") {
            log("收到 /stop 命令，停止全球法布施。");
            void handleStop();
            return;
          }
          if (command === "/loop") {
            const next = !loopEnabled;
            log("收到 /loop 命令，循环发送已" + (next ? "开启。" : "关闭。"));
            void handleLoopChange(next);
            return;
          }
          if (command === "/status") {
            log("当前状态：已发送 " + (status?.sentCount || 0) + " 个节点，" + (status?.sentMB || 0).toFixed(2) + " MB，" + (loopEnabled ? "循环中。" : "单轮模式。"));
            return;
          }
          log("收到 /start 命令" + (incoming ? "，开始处理输入。" : "。"));
          if (incoming) setText(incoming);
          void handleStart(incoming);
        });
      }
    };

    attachCommandListener();
    const readyHandler = () => attachCommandListener();
    window.addEventListener("fabushi-miniapp-ready", readyHandler);
    removeReadyListener = () => window.removeEventListener("fabushi-miniapp-ready", readyHandler);

    return () => {
      removeReadyListener?.();
      unsubscribeCommand?.();
    };
  }, [loopEnabled, selectedMaterial, selectedRegion]);

  const handleRegionChange = async (preset: RegionPreset) => {
    setRegionId(preset.id);
    try {
      const data = await applyOptions(preset);
      log(`地区模式已切换：${preset.label}`);
      if (preset.fieldEnergy && data?.wifiHotspot?.message) {
        log(data.wifiHotspot.message);
      }
    } catch (error) {
      log(hostErrorMessage(error, "地区模式切换失败"));
    }
  };

  const handleMaterial = async () => {
    setBusy(true);
    try {
      log("正在准备高能素材...");
      const unlocked = await ensureHighEnergyPurchase();
      if (!unlocked) return;
      setSelectedMaterial(HIGH_ENERGY_MATERIAL);
      updateStatus({ selectedContent: HIGH_ENERGY_MATERIAL });
      log("已选择高能素材。");
    } catch (error) {
      log(hostErrorMessage(error, "素材选择失败"));
    } finally {
      setBusy(false);
    }
  };

  const handleLoopChange = async (checked: boolean) => {
    setLoopEnabled(checked);
    try {
      if (!checked) stopLoopTimer();
      await applyOptions(selectedRegion, checked);
    } catch (error) {
      log(hostErrorMessage(error, "循环模式设置失败"));
    }
  };

  const refreshStatus = async () => {
    try {
      await fbApp.getCapabilities();
      updateStatus({});
      log("状态已刷新。");
    } catch (error) {
      log(hostErrorMessage(error, "刷新状态失败"));
    }
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
        <span>{selectedMaterial?.title || `${HIGH_ENERGY_PRODUCT.title}${highEnergyUnlocked ? " · 已购买" : ` · ${HIGH_ENERGY_PRODUCT.priceLabel}`}`}</span>
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
          {logs.map((l, i) => <div key={i}>{l}</div>)}
        </div>
      )}
    </div>
  );
}
