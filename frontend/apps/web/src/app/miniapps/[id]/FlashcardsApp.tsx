"use client";

import React, { useState } from "react";
import { BookOpenCheck, Layers, Sparkles, WandSparkles } from "lucide-react";
import { miniAppHost } from "./miniapp-sdk";
import "./miniapps.css";

export default function FlashcardsApp() {
  const [text, setText] = useState("");
  const [requirement, setRequirement] = useState("");
  const [mode, setMode] = useState("random");
  const [logs, setLogs] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);
  const [deck, setDeck] = useState<any>(null);

  const log = (msg: string) => setLogs((prev) => [...prev, `[${new Date().toLocaleTimeString()}] ${msg}`]);

  const handleCreateRef = React.useRef<(overrideText?: string, commandId?: string) => Promise<void>>();

  React.useEffect(() => {
    const { startParam } = miniAppHost.bot.getInitData?.() || {};
    if (startParam) {
      setText(startParam);
      log(`收到启动参数: ${startParam}`);
      if (startParam.trim().startsWith("http://") || startParam.trim().startsWith("https://")) {
        setTimeout(() => handleCreateRef.current?.(startParam), 100);
      }
    }
    const unsubscribeStart = (
      miniAppHost.bot.exposeCommand?.(
        "/start",
        (args, event) => {
          if (args) setText(args);
          log("收到 /start 制卡命令");
          void handleCreateRef.current?.(args, event?.commandId);
        },
        { description: "用正文或链接生成背诵闪卡" },
      ) ||
      miniAppHost.bot.onCommand?.("/start", (args, event) => {
        if (args) setText(args);
        log("收到 /start 制卡命令");
        void handleCreateRef.current?.(args, event?.commandId);
      })
    );
    return () => unsubscribeStart?.();
  }, []);

  const handleCreate = async (overrideText?: string, commandId?: string) => {
    const fullText = (overrideText ?? text).trim();
    if (!fullText) {
      log("请输入需要制卡的内容");
      return;
    }
    
    setLoading(true);
    setDeck(null);
    try {
      log(`正在使用${mode === "ai" ? "AI 制卡" : "随机挖空"}模式...`);
      const data = await miniAppHost.flashcards.createDeck({
        title: "背诵闪卡",
        text: fullText,
        mode,
        requirement,
        maxCards: mode === "ai" ? 40 : 36,
      });
      setDeck(data.deck);
      log(data.message || `制卡完成：${data.deck?.cardCount || 0} 张`);
      if (commandId) {
        await miniAppHost.bot.reportCommandResult?.({
          commandId,
          status: "completed",
          message: data.message || `制卡完成：${data.deck?.cardCount || 0} 张`,
          data,
        });
      }
    } catch (error: any) {
      log(error.message || "制卡失败");
      if (commandId) {
        await miniAppHost.bot.reportCommandResult?.({
          commandId,
          status: "failed",
          message: error.message || "制卡失败",
        }).catch(() => {});
      }
    } finally {
      setLoading(false);
    }
  };
  handleCreateRef.current = handleCreate;

  const handleOpenDeck = async () => {
    if (!deck?.id) return;
    try {
      await miniAppHost.flashcards.openDeck(deck.id);
    } catch (error: any) {
      log(error.message || "打开卡组失败");
    }
  };

  return (
    <div className="ma-panel ma-flashcards ma-fade-in" style={{ "--accent-start": "#7E57C2", "--accent-end": "#5E35B1", "--accent-rgb": "126, 87, 194" } as any}>
      <div className="ma-title-row">
        <div>
          <h1 className="ma-header-title">背诵闪卡</h1>
          <p className="ma-header-subtitle">{deck ? `${deck.cardCount} 张 · ${deck.modeLabel}` : "随机挖空 / AI 制卡"}</p>
        </div>
        <Layers size={24} className="ma-title-icon" />
      </div>

      <div className="ma-pill-selector">
        <button className={`ma-pill ${mode === "random" ? "active" : ""}`} onClick={() => setMode("random")}>
          <WandSparkles size={15} />
          随机挖空
        </button>
        <button className={`ma-pill ${mode === "ai" ? "active" : ""}`} onClick={() => setMode("ai")}>
          <Sparkles size={15} />
          AI 制卡
        </button>
      </div>

      <label className="ma-label">链接或正文</label>
      <textarea
        className="ma-textarea ma-flashcard-input"
        placeholder="粘贴经文、文章正文或链接。"
        value={text}
        onChange={(event) => setText(event.target.value)}
      />

      {mode === "ai" && (
        <>
          <label className="ma-label">制卡要求</label>
          <input
            className="ma-input"
            placeholder="例如：偏重名相解释，答案简短。"
            value={requirement}
            onChange={(event) => setRequirement(event.target.value)}
          />
        </>
      )}

      <button className="ma-btn" onClick={() => handleCreate()} disabled={loading}>
        <BookOpenCheck size={19} />
        {loading ? "生成中" : "生成卡组"}
      </button>

      {deck && (
        <div className="ma-deck-preview">
          <div className="ma-deck-head">
            <div>
              <strong>{deck.title}</strong>
              <span>{deck.cardCount} 张</span>
            </div>
            <button className="ma-small-btn" onClick={handleOpenDeck}>开始背诵</button>
          </div>
          <div className="ma-card-list">
            {deck.cards.map((card: any) => (
              <div className="ma-flashcard-row" key={card.id}>
                <p>{card.front}</p>
                <span>{card.answer || card.back}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {logs.length > 0 && (
        <div className="ma-log-box ma-log-soft">
          {logs.map((l, i) => <div key={i}>{l}</div>)}
        </div>
      )}
    </div>
  );
}
