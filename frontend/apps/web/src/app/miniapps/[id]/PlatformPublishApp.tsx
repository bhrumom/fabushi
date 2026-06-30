"use client";

import React, { useEffect, useMemo, useRef, useState } from "react";
import { ExternalLink, FileText, FolderOpen, Play, RefreshCw, Terminal, Upload } from "lucide-react";
import "./miniapps.css";

type Platform = {
  id: string;
  label: string;
  url: string;
};

const platforms: Platform[] = [
  { id: "wechat", label: "微信公众号", url: "https://mp.weixin.qq.com/" },
  { id: "xiaohongshu", label: "小红书", url: "https://creator.xiaohongshu.com/" },
  { id: "zhihu", label: "知乎", url: "https://www.zhihu.com/creator" },
];

class HostInvokeError extends Error {
  code?: string;

  constructor(response: any) {
    super(response?.message || "宿主调用失败");
    this.name = "HostInvokeError";
    this.code = response?.errorCode;
  }
}

async function invokeHost(method: string, params: Record<string, any> = {}) {
  const sdk = (window as any).FabushiMiniApp;
  if (!sdk?.invoke) throw new Error("SDK 尚未就绪");
  const res = await sdk.invoke(method, params);
  if (!res?.ok) throw new HostInvokeError(res);
  return res.data;
}

function slugTime() {
  return new Date().toISOString().replace(/[:.]/g, "-");
}

export default function PlatformPublishApp() {
  const [title, setTitle] = useState("法布施文章");
  const [text, setText] = useState("");
  const [platformId, setPlatformId] = useState("wechat");
  const [draft, setDraft] = useState<any>(null);
  const [savedPath, setSavedPath] = useState("");
  const [running, setRunning] = useState(false);
  const [capabilities, setCapabilities] = useState<string[]>([]);
  const [logs, setLogs] = useState<string[]>([]);
  const handleChatCommandRef = useRef<
    ((body: string, commandId?: string, mode?: "draft" | "run") => Promise<void>) | null
  >(null);

  const platform = useMemo(
    () => platforms.find((item) => item.id === platformId) || platforms[0],
    [platformId],
  );

  const log = (message: string) => {
    setLogs((prev) => [...prev, `[${new Date().toLocaleTimeString()}] ${message}`]);
  };

  useEffect(() => {
    const refresh = () => {
      if (!(window as any).FabushiMiniApp?.ready) return;
      invokeHost("app.getCapabilities")
        .then((data) => setCapabilities(data?.capabilities || []))
        .catch((error) => log(error.message));
    };
    refresh();
    window.addEventListener("fabushi-miniapp-ready", refresh);
    return () => window.removeEventListener("fabushi-miniapp-ready", refresh);
  }, []);

  useEffect(() => {
    const { startParam } = miniAppHost.bot.getInitData?.() || {};
    if (startParam) {
      setText(startParam);
      log(`收到启动参数: ${startParam}`);
    }
    const unsubscribeStart = (
      miniAppHost.bot.exposeCommand?.(
        "/start",
        (args, event) => {
          log("收到 /start 发布草稿命令");
          void handleChatCommandRef.current?.(args, event?.commandId, "draft");
        },
        { description: "生成发布草稿" },
      ) ||
      miniAppHost.bot.onCommand?.("/start", (args, event) => {
        log("收到 /start 发布草稿命令");
        void handleChatCommandRef.current?.(args, event?.commandId, "draft");
      })
    );
    const unsubscribeRun = (
      miniAppHost.bot.exposeCommand?.(
        "/run",
        (args, event) => {
          log("收到 /run 发布流水线命令");
          void handleChatCommandRef.current?.(args, event?.commandId, "run");
        },
        { description: "生成草稿并运行本地发布流水线" },
      ) ||
      miniAppHost.bot.onCommand?.("/run", (args, event) => {
        log("收到 /run 发布流水线命令");
        void handleChatCommandRef.current?.(args, event?.commandId, "run");
      })
    );
    return () => {
      unsubscribeStart?.();
      unsubscribeRun?.();
    };
  }, []);

  const hasCapability = (permission: string) => capabilities.includes(permission);

  const handleChatCommand = async (
    body: string,
    commandId?: string,
    mode: "draft" | "run" = "draft",
  ) => {
    const fullText = body.trim();
    if (!fullText) {
      log("请在命令后输入正文或链接。");
      return;
    }
    setText(fullText);
    setRunning(true);
    try {
      const data = await miniAppHost.platformPublish.createDraft({ title, text: fullText });
      setDraft(data);
      setTitle(data?.title || title);
      if (data?.body) setText(data.body);
      log("草稿已生成。");

      let resultMessage = `发布草稿已生成：${data?.title || title}`;
      if (mode === "run") {
        const bodyText = data?.body || fullText;
        const markdown = `# ${data?.title || title}\n\n${bodyText}\n`;
        const saved = await miniAppHost.fs.writeFile({
          path: `platform-publish/${platform.id}-${slugTime()}.md`,
          content: markdown,
        });
        setSavedPath(saved?.path || "");
        const script = [
          `console.log("Fabushi platform pipeline: ${platform.label}");`,
          `console.log("title: ${JSON.stringify(data?.title || title)}");`,
          `console.log("body chars: ${bodyText.length}");`,
          `console.log("draft file: ${JSON.stringify(saved?.path || "")}");`,
          `console.log("ready to hand off to browser automation.");`,
        ].join("\n");
        const file = await miniAppHost.fs.writeFile({
          path: `platform-publish/run-${platform.id}-${slugTime()}.js`,
          content: script,
        });
        await miniAppHost.shell.execute({
          title: `${platform.label} 发布流水线`,
          command: "node",
          arguments: [file.path],
        });
        resultMessage = `${platform.label} 发布流水线已启动。`;
      }

      if (commandId) {
        await miniAppHost.bot.reportCommandResult?.({
          commandId,
          status: "completed",
          message: resultMessage,
          data,
        });
      }
    } catch (error: any) {
      log(error.message || "发布命令执行失败");
      if (commandId) {
        await miniAppHost.bot.reportCommandResult?.({
          commandId,
          status: "failed",
          message: error.message || "发布命令执行失败",
        }).catch(() => {});
      }
    } finally {
      setRunning(false);
    }
  };
  handleChatCommandRef.current = handleChatCommand;

  const handlePickFiles = async () => {
    try {
      const data = await invokeHost("files.pick", { replaceExisting: false });
      log(data?.selected ? "已加入本地文件素材。" : "未选择文件。");
    } catch (error: any) {
      log(error.message || "选择文件失败");
    }
  };

  const handleCreateDraft = async () => {
    setRunning(true);
    try {
      const data = await invokeHost("platformPublish.createDraft", { title, text });
      setDraft(data);
      setTitle(data?.title || title);
      if (data?.body) setText(data.body);
      log("草稿已生成。");
    } catch (error: any) {
      log(error.message || "生成草稿失败");
    } finally {
      setRunning(false);
    }
  };

  const handleSaveDraft = async () => {
    const body = draft?.body || text;
    if (!body.trim()) {
      log("请先输入正文或生成草稿。");
      return;
    }
    setRunning(true);
    try {
      const markdown = `# ${draft?.title || title}\n\n${body}\n`;
      const data = await invokeHost("fs.writeFile", {
        path: `platform-publish/${platform.id}-${slugTime()}.md`,
        content: markdown,
      });
      setSavedPath(data?.path || "");
      log(`草稿已写入：${data?.path || "本地小程序目录"}`);
    } catch (error: any) {
      log(error.message || "写入本地文件失败");
    } finally {
      setRunning(false);
    }
  };

  const handleRunPipeline = async () => {
    const body = draft?.body || text;
    if (!body.trim()) {
      log("请先准备草稿正文。");
      return;
    }
    setRunning(true);
    try {
      const script = [
        `console.log("Fabushi platform pipeline: ${platform.label}");`,
        `console.log("title: ${JSON.stringify(draft?.title || title)}");`,
        `console.log("body chars: ${body.length}");`,
        savedPath
          ? `console.log("draft file: ${JSON.stringify(savedPath)}");`
          : `console.log("draft file: not saved yet");`,
        `console.log("ready to hand off to browser automation.");`,
      ].join("\n");
      const file = await invokeHost("fs.writeFile", {
        path: `platform-publish/run-${platform.id}-${slugTime()}.js`,
        content: script,
      });
      await invokeHost("shell.execute", {
        title: `${platform.label} 发布流水线`,
        command: "node",
        arguments: [file.path],
      });
      log("终端流水线已交给宿主执行。");
    } catch (error: any) {
      log(error.message || "终端流水线启动失败");
    } finally {
      setRunning(false);
    }
  };

  const handleOpenPlatform = async () => {
    try {
      await invokeHost("browser.open", { url: platform.url });
      log(`已打开：${platform.label}`);
    } catch (error: any) {
      log(error.message || "打开平台失败");
    }
  };

  const handleRefreshSpec = async () => {
    try {
      const data = await invokeHost("app.getHostApiSpec");
      log(`宿主 API ${data?.hostApiVersion || ""} 已就绪。`);
    } catch (error: any) {
      log(error.message || "读取宿主能力失败");
    }
  };

  return (
    <div className="ma-panel ma-fade-in" style={{ "--accent-start": "#FF9F43", "--accent-end": "#E67E22", "--accent-rgb": "255, 159, 67" } as any}>
      <div className="ma-title-row">
        <div>
          <h1 className="ma-header-title">法布施到平台</h1>
          <p className="ma-header-subtitle">{platform.label} · {savedPath ? "已保存草稿" : "待准备草稿"}</p>
        </div>
        <button className="ma-icon-btn" onClick={handleRefreshSpec} aria-label="刷新宿主能力">
          <RefreshCw size={18} />
        </button>
      </div>

      <label className="ma-label">平台</label>
      <div className="ma-segment-grid">
        {platforms.map((item) => (
          <button
            key={item.id}
            className={`ma-chip-btn ${platform.id === item.id ? "active" : ""}`}
            onClick={() => setPlatformId(item.id)}
          >
            <Upload size={15} />
            {item.label}
          </button>
        ))}
      </div>

      <label className="ma-label">标题</label>
      <input className="ma-input" value={title} onChange={(event) => setTitle(event.target.value)} />

      <label className="ma-label">正文</label>
      <textarea
        className="ma-textarea ma-textarea-tall"
        placeholder="粘贴 Markdown、正文或链接。"
        value={text}
        onChange={(event) => setText(event.target.value)}
      />

      {savedPath && (
        <div className="ma-selected-content">
          <FileText size={15} />
          <span>{savedPath}</span>
        </div>
      )}

      <div className="ma-action-row ma-action-row-wrap">
        <button className="ma-btn" onClick={handleCreateDraft} disabled={running}>
          <FileText size={18} />
          生成草稿
        </button>
        <button className="ma-btn ma-btn-secondary" onClick={handleSaveDraft} disabled={running || !hasCapability("fs.readWrite")}>
          <FolderOpen size={18} />
          保存文件
        </button>
        <button className="ma-btn ma-btn-secondary" onClick={handleRunPipeline} disabled={running || !hasCapability("shell.execute")}>
          <Terminal size={18} />
          运行终端
        </button>
        <button className="ma-btn ma-btn-secondary" onClick={handleOpenPlatform} disabled={!hasCapability("browser.external")}>
          <ExternalLink size={18} />
          打开平台
        </button>
        <button className="ma-btn ma-btn-secondary" onClick={handlePickFiles} disabled={!hasCapability("files.pick")}>
          <Play size={18} />
          选文件
        </button>
      </div>

      {logs.length > 0 && (
        <div className="ma-log-box">
          {logs.map((item, index) => <div key={index}>{item}</div>)}
        </div>
      )}
    </div>
  );
}
