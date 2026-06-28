"use client";

import React, { useEffect, useState } from "react";
import { BookOpenCheck, Layers, Sparkles, WandSparkles } from "lucide-react";
import { bootMiniApp, fbApp, hostErrorMessage } from "./miniapp-runtime";
import "./miniapps.css";

export default function FlashcardsApp() {
  const [text, setText] = useState("");
  const [requirement, setRequirement] = useState("");
  const [mode, setMode] = useState("random");
  const [logs, setLogs] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);
  const [deck, setDeck] = useState<any>(null);

  const log = (msg: string) => setLogs((prev) => [...prev, `[${new Date().toLocaleTimeString()}] ${msg}`]);

  useEffect(() => {
    void bootMiniApp("official.flashcards", "背诵闪卡");
  }, []);

  const handleCreate = async () => {
    const fullText = text.trim();
    if (!fullText) {
      log("请输入需要制卡的内容");
      return;
    }

    setLoading(true);
    setDeck(null);
    try {
      log(`正在使用${mode === "ai" ? "AI 制卡" : "随机挖空"}模式...`);
      const data = await fbApp.invoke<any>("flashcards.createDeck", {
        title: "背诵闪卡",
        text: fullText,
        mode,
        requirement,
        maxCards: mode === "ai" ? 40 : 36,
      });
      setDeck(data.deck);
      log(data.message || `制卡完成：${data.deck?.cardCount || 0} 张`);
    } catch (error) {
      log(hostErrorMessage(error, "制卡失败"));
    } finally {
      setLoading(false);
    }
  };

  const handleOpenDeck = async () => {
    if (!deck?.id) return;
    try {
      await fbApp.invoke("flashcards.openDeck", { deckId: deck.id });
    } catch (error) {
      log(hostErrorMessage(error, "打开卡组失败"));
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

      <button className="ma-btn" onClick={handleCreate} disabled={loading}>
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
