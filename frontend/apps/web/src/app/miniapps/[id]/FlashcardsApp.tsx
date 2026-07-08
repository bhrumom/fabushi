"use client";

import React, { useCallback, useEffect, useRef, useState } from "react";
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
  const pendingChatTextRef = useRef("");

  const log = useCallback(
    (msg: string) => setLogs((prev) => [...prev, `[${new Date().toLocaleTimeString()}] ${msg}`]),
    [],
  );
  const postBotMessage = useCallback(
    (message: string, level = "info") =>
      fbApp.invoke("bot.postMessage", { message, level }).catch(() => null),
    [],
  );

  useEffect(() => {
    void bootMiniApp("official.flashcards", "背诵闪卡");
  }, []);

  const createDeckFromText = useCallback(
    async (
      fullText: string,
      selectedMode = mode,
      selectedRequirement = requirement,
    ) => {
      if (!fullText) {
        log("请输入需要制卡的内容");
        return;
      }

      setLoading(true);
      setDeck(null);
      try {
        log(`正在使用${selectedMode === "ai" ? "AI 制卡" : "随机挖空"}模式...`);
        const data = await fbApp.invoke<any>("flashcards.createDeck", {
          title: "背诵闪卡",
          text: fullText,
          mode: selectedMode,
          requirement: selectedRequirement,
          maxCards: selectedMode === "ai" ? 40 : 36,
        });
        setDeck(data.deck);
        const message = data.message || `制卡完成：${data.deck?.cardCount || 0} 张`;
        log(message);
        void postBotMessage(message);
      } catch (error) {
        const message = hostErrorMessage(error, "制卡失败");
        log(message);
        void postBotMessage(message, "error");
      } finally {
        setLoading(false);
      }
    },
    [log, mode, postBotMessage, requirement],
  );

  const handleCreate = async () => {
    await createDeckFromText(text.trim());
  };

  const handleOpenDeck = async () => {
    if (!deck?.id) return;
    try {
      await fbApp.invoke("flashcards.openDeck", { deckId: deck.id });
    } catch (error) {
      log(hostErrorMessage(error, "打开卡组失败"));
    }
  };

  useEffect(() => {
    if (typeof window === "undefined") return undefined;
    let unsubscribeCommand: (() => void) | undefined;
    const attachCommandListener = () => {
      const hostBot = (window as any).FabushiMiniApp?.bot;
      if (!hostBot || unsubscribeCommand) return;
      void fbApp
        .invoke("bot.setInputPlaceholder", {
          placeholder: "粘贴正文/链接；收到选项后回复 1 或 2",
        })
        .catch(() => null);
      void fbApp
        .invoke("bot.setCommands", {
          commands: [
            { command: "/start", description: "制作背诵闪卡", order: 1 },
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
          if (cleanInput === "1") {
            const content = pendingChatTextRef.current || text.trim();
            if (!content) {
              void postBotMessage("当前没有待制卡内容，请先发送链接或正文。", "error");
              return;
            }
            setMode("random");
            void postBotMessage("正在使用随机挖空模式制作背诵闪卡...");
            void createDeckFromText(content, "random", requirement);
            pendingChatTextRef.current = "";
            return;
          }
          if (cleanInput === "2") {
            const content = pendingChatTextRef.current || text.trim();
            if (!content) {
              void postBotMessage("当前没有待制卡内容，请先发送链接或正文。", "error");
              return;
            }
            setMode("ai");
            void postBotMessage("正在使用 AI 模式制作背诵闪卡...");
            void createDeckFromText(content, "ai", requirement);
            pendingChatTextRef.current = "";
            return;
          }
          if (cleanInput === "3") {
            void fbApp.invoke("bot.openPanel", {}).catch(() => null);
            void postBotMessage("已打开背诵闪卡小程序，请在面板中继续编辑。");
            return;
          }
          if (cleanInput === "4") {
            pendingChatTextRef.current = "";
            void postBotMessage("已取消本次制卡任务。");
            return;
          }
          if (!cleanInput) {
            void postBotMessage("请发送需要制卡的链接或正文。");
            return;
          }
          pendingChatTextRef.current = cleanInput;
          setText(cleanInput);
          void postBotMessage(
            "已收到制卡内容。请回复数字选择：\n1. 随机挖空制卡\n2. AI 制卡\n3. 打开小程序编辑\n4. 取消本次任务",
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
  }, [createDeckFromText, postBotMessage, requirement, text]);

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
