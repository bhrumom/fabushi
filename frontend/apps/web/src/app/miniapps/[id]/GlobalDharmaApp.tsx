"use client";

import React, { useEffect, useMemo, useRef, useState } from "react";
import {
  CircleStop,
  Globe,
  Link2,
  RefreshCw,
  Send,
  Sparkles,
} from "lucide-react";
import { bootMiniApp, fbApp, hostErrorMessage } from "./miniapp-runtime";
import {
  GlobalDharmaSendService,
  type DharmaSendResult,
  type PreparedContent,
  type RegionPreset,
} from "./global-dharma-send-service";
import "./miniapps.css";

const regionPresets: RegionPreset[] = [
  { id: "global", label: "全球", global: true, countryCodes: ["ALL"] },
  {
    id: "eastAsia",
    label: "东亚",
    global: true,
    countryCodes: ["CN", "JP", "KR", "MN", "TW", "HK", "MO"],
  },
  {
    id: "americas",
    label: "美洲",
    global: true,
    countryCodes: ["US", "CA", "MX", "BR", "AR", "CL", "PE"],
  },
  {
    id: "europe",
    label: "欧洲",
    global: true,
    countryCodes: ["GB", "FR", "DE", "IT", "ES", "NL", "SE"],
  },
  { id: "field", label: "本地场能 UDP", global: false, fieldEnergy: true },
  {
    id: "loopback",
    label: "本地转经轮 UDP",
    global: false,
    localLoopback: true,
  },
];

const HIGH_ENERGY_MATERIAL: PreparedContent = {
  title: "3D佛像素材",
  text: "3D佛像素材",
  previewText: "已选择本机素材：3D佛像素材",
  charCount: 6,
};

type DharmaStatus = {
  sentCount: number;
  sentMB: number;
  isTransferring: boolean;
  isPreparingSend: boolean;
  selectedContent?: PreparedContent | null;
  lastResult?: DharmaSendResult | null;
  updatedAt?: string;
};

const INITIAL_STATUS: DharmaStatus = {
  sentCount: 0,
  sentMB: 0,
  isTransferring: false,
  isPreparingSend: false,
  selectedContent: null,
  lastResult: null,
};

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
  if (typeof document === "undefined") return value;
  const textarea = document.createElement("textarea");
  textarea.innerHTML = value;
  return textarea.value;
}

function extractHtmlTitle(html: string, fallback: string) {
  const match = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  return decodeHtmlEntities(match?.[1] || fallback)
    .replace(/\s+/g, " ")
    .trim();
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

function bodyTextFromHostResponse(response: any) {
  if (typeof response?.body === "string" && response.body.length > 0)
    return response.body;
  if (
    typeof response?.bodyBase64 === "string" &&
    response.bodyBase64.length > 0
  ) {
    return window.atob(response.bodyBase64);
  }
  return "";
}

function contentFromPlainText(
  raw: string,
  selectedMaterial: PreparedContent | null,
): PreparedContent {
  const merged = selectedMaterial ? `${raw}\n\n${selectedMaterial.text}` : raw;
  return {
    title: selectedMaterial?.title || "小程序全球法布施",
    text: merged,
    previewText: merged.slice(0, 180),
    charCount: merged.length,
  };
}

export default function GlobalDharmaApp() {
  const [text, setText] = useState("");
  const [status, setStatus] = useState<DharmaStatus>(INITIAL_STATUS);
  const [regionId, setRegionId] = useState("global");
  const [loopEnabled, setLoopEnabled] = useState(false);
  const [selectedMaterial, setSelectedMaterial] =
    useState<PreparedContent | null>(null);
  const [logs, setLogs] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const sendServiceRef = useRef(new GlobalDharmaSendService());
  const loopTimerRef = useRef<number | null>(null);
  const latestRunRef = useRef(0);
  const selectedRegion = useMemo(
    () =>
      regionPresets.find((item) => item.id === regionId) || regionPresets[0],
    [regionId],
  );

  const log = (message: string) => {
    setLogs((prev) => [
      ...prev.slice(-80),
      `[${new Date().toLocaleTimeString()}] ${message}`,
    ]);
  };

  const updateStatus = (next: Partial<DharmaStatus>) => {
    setStatus((prev) => ({
      ...prev,
      ...next,
      updatedAt: new Date().toISOString(),
    }));
  };

  const stopLoopTimer = () => {
    if (loopTimerRef.current === null) return;
    window.clearInterval(loopTimerRef.current);
    loopTimerRef.current = null;
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

    if (fbApp.isHostEnv()) {
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
        if (statusCode && (statusCode < 200 || statusCode >= 300))
          throw new Error(`HTTP ${statusCode}`);
        const prepared = buildPrepared(bodyTextFromHostResponse(response));
        if (prepared.text.length < 20) throw new Error("网页正文过短");
        log(`已通过宿主 network.http.fetch 读取链接正文：${prepared.title}`);
        return prepared;
      } catch (error) {
        log(hostErrorMessage(error, "宿主链接读取失败，降级到浏览器 fetch"));
      }
    }

    const response = await fetch(url, {
      cache: "no-store",
      headers: { Accept: "text/html,text/plain,application/xhtml+xml,*/*" },
    });
    if (!response.ok) throw new Error(`链接读取失败: HTTP ${response.status}`);
    const prepared = buildPrepared(await response.text());
    if (prepared.text.length < 20) throw new Error("网页正文过短");
    log(`已通过浏览器 fetch 读取链接正文：${prepared.title}`);
    return prepared;
  };

  const prepareTransferContent = async (
    inputOverride?: string,
  ): Promise<PreparedContent> => {
    const raw = (inputOverride ?? text).trim();
    const url = extractFirstHttpUrl(raw);
    if (raw && url && looksLikeHttpUrl(raw)) {
      const content = await fetchUrlContent(url);
      if (!selectedMaterial) return content;
      return {
        ...content,
        text: `${content.text}\n\n${selectedMaterial.text}`,
        previewText:
          `${content.previewText}\n${selectedMaterial.previewText}`.slice(
            0,
            220,
          ),
        charCount: content.charCount + selectedMaterial.charCount,
      };
    }
    if (raw) return contentFromPlainText(raw, selectedMaterial);
    if (selectedMaterial) return selectedMaterial;
    throw new Error("请先输入链接、正文，或选择高能素材");
  };

  const runRealSend = async (content: PreparedContent, commandId?: string) => {
    const result = await sendServiceRef.current.send({
      content,
      region: selectedRegion,
      loop: loopEnabled,
      commandId,
    });
    const sentMB = result.bytesSent / (1024 * 1024);
    setStatus((prev) => ({
      ...prev,
      sentCount: prev.sentCount + result.receipts.length,
      sentMB: prev.sentMB + sentMB,
      selectedContent: content,
      lastResult: result,
      isPreparingSend: false,
      isTransferring: loopEnabled,
      updatedAt: new Date().toISOString(),
    }));
    const receiptText =
      result.receipts.length > 0
        ? `真实发送完成：${result.status}，回执 ${result.receipts.length} 个，${sentMB.toFixed(4)} MB`
        : `发送已提交但暂无真实回执，未计入已发送数量`;
    log(`${receiptText}${result.jobId ? `，任务 ${result.jobId}` : ""}`);
    await postBotMessage(
      result.receipts.length > 0
        ? `全球法布施已发送：${content.title}`
        : `全球法布施已提交，等待真实回执：${content.title}`,
      {
        miniAppId: "official.global-dharma",
        contentHash: result.contentHash,
        jobId: result.jobId,
        jobIds: result.jobIds,
        receipts: result.receipts,
        region: selectedRegion,
        loop: loopEnabled,
      },
    );
    return result;
  };

  const handleStart = async (inputOverride?: string, commandId?: string) => {
    const effectiveText = (inputOverride ?? text).trim();
    if (!effectiveText && !selectedMaterial) {
      log("请先输入链接、正文，或选择高能素材");
      return;
    }
    const runId = Date.now();
    latestRunRef.current = runId;
    setBusy(true);
    stopLoopTimer();
    updateStatus({ isPreparingSend: true, isTransferring: false });
    try {
      log(
        fbApp.isHostEnv()
          ? "正在通过 Rust 系统级 delivery/UDP 执行真实发送..."
          : "正在通过 Web HTTP 执行真实发送...",
      );
      if (loopEnabled || selectedRegion.fieldEnergy) {
        await fbApp
          .invoke("system.keepAwake", {
            enabled: true,
            reason: "global-dharma-transfer",
          })
          .catch(() => null);
      }
      const content = await prepareTransferContent(effectiveText);
      await runRealSend(content, commandId);
      if (loopEnabled) {
        loopTimerRef.current = window.setInterval(() => {
          if (latestRunRef.current !== runId) return;
          void runRealSend(content, commandId).catch((error) => {
            log(hostErrorMessage(error, "循环发送失败"));
            updateStatus({ isTransferring: false });
            stopLoopTimer();
          });
        }, 30000);
        log("循环模式已开启：每 30 秒执行一次真实发送，不再使用模拟计数。 ");
      }
    } catch (error) {
      log(hostErrorMessage(error, "启动失败"));
      updateStatus({ isPreparingSend: false, isTransferring: false });
    } finally {
      setBusy(false);
    }
  };

  const handleStop = async () => {
    latestRunRef.current = Date.now();
    stopLoopTimer();
    await fbApp
      .invoke("system.keepAwake", { enabled: false })
      .catch(() => null);
    updateStatus({ isTransferring: false, isPreparingSend: false });
    log("真实发送已停止。 ");
  };

  const handleLoopChange = async (enabled: boolean) => {
    setLoopEnabled(enabled);
    if (!enabled) stopLoopTimer();
    await fbApp
      .invoke("system.keepAwake", { enabled, reason: "global-dharma-transfer" })
      .catch(() => null);
    log(enabled ? "循环真实发送已开启。" : "循环真实发送已关闭。");
  };

  useEffect(() => {
    let active = true;
    const refresh = async () => {
      try {
        await fbApp.getCapabilities();
        if (active) updateStatus({ isPreparingSend: false });
      } catch (error) {
        if (active && fbApp.isHostEnv())
          log(hostErrorMessage(error, "读取宿主能力失败"));
      }
    };
    void bootMiniApp("official.global-dharma", "全球法布施").then(() =>
      refresh(),
    );
    const unsubscribeReady = fbApp.on("ready", () => void refresh());
    return () => {
      active = false;
      stopLoopTimer();
      unsubscribeReady();
    };
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return undefined;
    let unsubscribeCommand: (() => void) | undefined;
    const attachCommandListener = () => {
      const hostBot = (window as any).FabushiMiniApp?.bot;
      if (!hostBot || unsubscribeCommand) return;
      void fbApp
        .invoke("bot.setInputPlaceholder", {
          placeholder: "输入链接/正文；Web 走 HTTP，App 走 Rust/UDP",
        })
        .catch(() => null);
      void fbApp
        .invoke("bot.setCommands", {
          commands: [
            { command: "/start", description: "开始真实全球法布施", order: 1 },
            { command: "/stop", description: "停止当前全球法布施", order: 2 },
            { command: "/loop", description: "切换循环真实发送", order: 3 },
            { command: "/status", description: "查看真实发送状态", order: 4 },
          ],
        })
        .catch(() => null);
      if (typeof hostBot.onAnyCommand === "function") {
        unsubscribeCommand = hostBot.onAnyCommand((detail: any) => {
          const command = String(detail?.command || "/start").trim();
          const incoming = String(
            detail?.args || detail?.rawText || detail?.text || "",
          ).trim();
          if (command === "/stop") {
            void handleStop();
            return;
          }
          if (command === "/loop") {
            void handleLoopChange(!loopEnabled);
            return;
          }
          if (command === "/status") {
            log(
              `状态：回执 ${status.sentCount} 个，${status.sentMB.toFixed(4)} MB，${status.isTransferring ? "循环中" : "未循环"}`,
            );
            return;
          }
          void handleStart(incoming || undefined, detail?.commandId);
        });
      }
    };
    attachCommandListener();
    window.addEventListener("fabushi-miniapp-ready", attachCommandListener);
    return () => {
      window.removeEventListener(
        "fabushi-miniapp-ready",
        attachCommandListener,
      );
      unsubscribeCommand?.();
    };
  }, [
    loopEnabled,
    selectedRegion,
    selectedMaterial,
    text,
    status.sentCount,
    status.sentMB,
    status.isTransferring,
  ]);

  const selectedReceiptText = status.lastResult?.receipts?.length
    ? `${status.lastResult.receipts.length} 个真实回执`
    : "暂无回执";

  return (
    <main className="miniapp-page global-dharma-app">
      <section className="miniapp-hero">
        <div className="miniapp-hero-icon">
          <Globe size={28} />
        </div>
        <div>
          <p className="miniapp-kicker">Official Mini App</p>
          <h1>全球法布施</h1>
          <p>
            Web 使用真实 HTTP 回执计数；桌面端与移动端通过 Rust 系统级
            delivery/UDP 发送。
          </p>
        </div>
      </section>

      <section className="miniapp-card">
        <label className="miniapp-label" htmlFor="global-dharma-input">
          链接或正文
        </label>
        <textarea
          id="global-dharma-input"
          value={text}
          onChange={(event) => setText(event.target.value)}
          placeholder="粘贴佛法链接、经文摘录或发愿文。普通 Web 使用真实 HTTP；App 内使用 Rust/UDP 系统发送。"
          rows={5}
        />
        <div className="miniapp-actions">
          <button
            type="button"
            onClick={() => void handleStart()}
            disabled={busy || status.isPreparingSend}
          >
            <Send size={16} /> 开始真实发送
          </button>
          <button
            type="button"
            onClick={() => void handleStop()}
            disabled={!status.isTransferring && !status.isPreparingSend}
          >
            <CircleStop size={16} /> 停止
          </button>
          <button
            type="button"
            onClick={() =>
              setSelectedMaterial((prev) =>
                prev ? null : HIGH_ENERGY_MATERIAL,
              )
            }
          >
            <Sparkles size={16} />{" "}
            {selectedMaterial ? "取消素材" : "加入3D佛像素材"}
          </button>
        </div>
      </section>

      <section className="miniapp-card">
        <div className="miniapp-grid">
          <label className="miniapp-label">
            发送区域
            <select
              value={regionId}
              onChange={(event) => setRegionId(event.target.value)}
            >
              {regionPresets.map((preset) => (
                <option key={preset.id} value={preset.id}>
                  {preset.label}
                </option>
              ))}
            </select>
          </label>
          <label className="miniapp-check">
            <input
              type="checkbox"
              checked={loopEnabled}
              onChange={(event) => void handleLoopChange(event.target.checked)}
            />
            循环真实发送，每轮都必须获得真实回执后才计数
          </label>
        </div>
      </section>

      <section className="miniapp-card miniapp-status-card">
        <div className="miniapp-status-item">
          <span>回执</span>
          <strong>{status.sentCount}</strong>
        </div>
        <div className="miniapp-status-item">
          <span>真实发送数据</span>
          <strong>{status.sentMB.toFixed(4)} MB</strong>
        </div>
        <div className="miniapp-status-item">
          <span>最新状态</span>
          <strong>
            {status.isPreparingSend
              ? "准备中"
              : status.isTransferring
                ? "循环中"
                : selectedReceiptText}
          </strong>
        </div>
      </section>

      {status.selectedContent && (
        <section className="miniapp-card">
          <h2>
            <Link2 size={18} /> 当前内容
          </h2>
          <p>{status.selectedContent.previewText}</p>
          {status.lastResult?.contentHash && (
            <p className="miniapp-muted">
              Hash: {status.lastResult.contentHash}
            </p>
          )}
          {status.lastResult?.jobId && (
            <p className="miniapp-muted">Job: {status.lastResult.jobId}</p>
          )}
        </section>
      )}

      <section className="miniapp-card">
        <h2>
          <RefreshCw size={18} /> 运行日志
        </h2>
        <div className="miniapp-log">
          {logs.length === 0 ? (
            <p>等待开始真实发送...</p>
          ) : (
            logs.map((item, index) => <p key={`${item}-${index}`}>{item}</p>)
          )}
        </div>
      </section>
    </main>
  );
}
