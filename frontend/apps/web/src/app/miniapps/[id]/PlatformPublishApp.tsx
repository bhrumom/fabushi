"use client";

import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ExternalLink, FileText, FolderOpen, Play, RefreshCw, Terminal, Upload } from "lucide-react";
import { bootMiniApp, fbApp, hostErrorMessage } from "./miniapp-runtime";
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
  const pendingChatTextRef = useRef("");

  const platform = useMemo(
    () => platforms.find((item) => item.id === platformId) || platforms[0],
    [platformId],
  );

  const log = useCallback((message: string) => {
    setLogs((prev) => [...prev, `[${new Date().toLocaleTimeString()}] ${message}`]);
  }, []);
  const postBotMessage = useCallback(
    (message: string, level = "info") =>
      fbApp.invoke("bot.postMessage", { message, level }).catch(() => null),
    [],
  );

  useEffect(() => {
    const refresh = async () => {
      await bootMiniApp("official.platform-publish", "法布施到平台");
      try {
        setCapabilities(await fbApp.getCapabilities());
      } catch (error) {
        log(hostErrorMessage(error, "读取宿主能力失败"));
      }
    };
    void refresh();
    const unsubscribe = fbApp.on("ready", () => {
      void fbApp.getCapabilities().then(setCapabilities).catch((error) => log(hostErrorMessage(error)));
    });
    return unsubscribe;
  }, []);

  const hasCapability = (permission: string) => capabilities.includes(permission);

  const handlePickFiles = async () => {
    try {
      const data = await fbApp.invoke<any>("files.pick", { replaceExisting: false });
      log(data?.selected ? "已加入本地文件素材。" : "未选择文件。");
    } catch (error) {
      log(hostErrorMessage(error, "选择文件失败"));
    }
  };

  const createDraftFromText = useCallback(
    async (sourceText = text, announce = true) => {
      const body = sourceText.trim();
      if (!body) {
        log("请先输入正文或链接。");
        if (announce) void postBotMessage("请先输入正文或链接。", "error");
        return null;
      }
      setRunning(true);
      try {
        const data = await fbApp.invoke<any>("platformPublish.createDraft", {
          title,
          text: body,
        });
        setDraft(data);
        setTitle(data?.title || title);
        if (data?.body) setText(data.body);
        log("草稿已生成。");
        if (announce) void postBotMessage("草稿已生成。");
        return data;
      } catch (error) {
        const message = hostErrorMessage(error, "生成草稿失败");
        log(message);
        if (announce) void postBotMessage(message, "error");
        return null;
      } finally {
        setRunning(false);
      }
    },
    [log, postBotMessage, text, title],
  );

  const handleCreateDraft = async () => {
    await createDraftFromText(text);
  };

  const saveDraftBody = useCallback(
    async (body: string, draftTitle = title) => {
      if (!body.trim()) {
        log("请先输入正文或生成草稿。");
        void postBotMessage("请先输入正文或生成草稿。", "error");
        return;
      }
      setRunning(true);
      try {
        const markdown = `# ${draftTitle}\n\n${body}\n`;
        const data = await fbApp.invoke<any>("fs.writeFile", {
          path: `platform-publish/${platform.id}-${slugTime()}.md`,
          content: markdown,
        });
        setSavedPath(data?.path || "");
        log(`草稿已写入：${data?.path || "本地小程序目录"}`);
        void postBotMessage(`草稿已写入：${data?.path || "本地小程序目录"}`);
      } catch (error) {
        const message = hostErrorMessage(error, "写入本地文件失败");
        log(message);
        void postBotMessage(message, "error");
      } finally {
        setRunning(false);
      }
    },
    [log, platform.id, postBotMessage, title],
  );

  const handleSaveDraft = async () => {
    const body = draft?.body || text;
    await saveDraftBody(body, draft?.title || title);
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
      const file = await fbApp.invoke<any>("fs.writeFile", {
        path: `platform-publish/run-${platform.id}-${slugTime()}.js`,
        content: script,
      });
      await fbApp.invoke("shell.execute", {
        title: `${platform.label} 发布流水线`,
        command: "node",
        arguments: [file.path],
      });
      log("终端流水线已交给宿主执行。");
    } catch (error) {
      log(hostErrorMessage(error, "终端流水线启动失败"));
    } finally {
      setRunning(false);
    }
  };

  const handleOpenPlatform = useCallback(async () => {
    try {
      await fbApp.ui.openLink(platform.url);
      log(`已打开：${platform.label}`);
      void postBotMessage(`已打开：${platform.label}`);
    } catch (error) {
      const message = hostErrorMessage(error, "打开平台失败");
      log(message);
      void postBotMessage(message, "error");
    }
  }, [log, platform.label, platform.url, postBotMessage]);

  useEffect(() => {
    if (typeof window === "undefined") return undefined;
    let unsubscribeCommand: (() => void) | undefined;
    const attachCommandListener = () => {
      const hostBot = (window as any).FabushiMiniApp?.bot;
      if (!hostBot || unsubscribeCommand) return;
      void fbApp
        .invoke("bot.setInputPlaceholder", {
          placeholder: "粘贴正文/链接；收到选项后回复数字",
        })
        .catch(() => null);
      void fbApp
        .invoke("bot.setCommands", {
          commands: [
            { command: "/start", description: "生成发布草稿", order: 1 },
          ],
        })
        .catch(() => null);
      if (typeof hostBot.onAnyCommand === "function") {
        unsubscribeCommand = hostBot.onAnyCommand((detail: any) => {
          const command = String(detail?.command || "/start").trim();
          const incoming = String(
            detail?.args || detail?.rawText || detail?.text || "",
          ).trim();
          const cleanInput = (
            incoming ||
            (command.startsWith("/") && command !== "/start" ? command.slice(1) : "")
          ).trim();
          const content = pendingChatTextRef.current || text.trim();
          if (cleanInput === "1") {
            if (!content) {
              void postBotMessage("当前没有待发布内容，请先发送链接或正文。", "error");
              return;
            }
            void createDraftFromText(content);
            pendingChatTextRef.current = "";
            return;
          }
          if (cleanInput === "2") {
            if (!content) {
              void postBotMessage("当前没有待发布内容，请先发送链接或正文。", "error");
              return;
            }
            void (async () => {
              const data = await createDraftFromText(content, false);
              await saveDraftBody(data?.body || content, data?.title || title);
              pendingChatTextRef.current = "";
            })();
            return;
          }
          if (cleanInput === "3") {
            void handleOpenPlatform();
            return;
          }
          if (cleanInput === "4") {
            pendingChatTextRef.current = "";
            void postBotMessage("已取消本次发布任务。");
            return;
          }
          if (!cleanInput) {
            void postBotMessage("请发送要发布的正文或链接。");
            return;
          }
          pendingChatTextRef.current = cleanInput;
          setText(cleanInput);
          void postBotMessage(
            "已收到发布内容。请回复数字选择：\n1. 生成发布草稿\n2. 保存草稿到本地\n3. 打开平台入口\n4. 取消本次任务",
          );
        });
      }
    };
    attachCommandListener();
    window.addEventListener("fabushi-miniapp-ready", attachCommandListener);
    return () => {
      window.removeEventListener("fabushi-miniapp-ready", attachCommandListener);
      unsubscribeCommand?.();
    };
  }, [
    createDraftFromText,
    handleOpenPlatform,
    postBotMessage,
    saveDraftBody,
    text,
    title,
  ]);

  const handleRefreshSpec = async () => {
    try {
      const data = await fbApp.getHostApiSpec();
      setCapabilities(await fbApp.getCapabilities());
      log(`宿主 API ${data?.hostApiVersion || ""} 已就绪。`);
    } catch (error) {
      log(hostErrorMessage(error, "读取宿主能力失败"));
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
