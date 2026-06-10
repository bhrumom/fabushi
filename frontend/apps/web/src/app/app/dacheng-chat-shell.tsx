"use client";

import { useMemo, useState } from "react";
import {
  type DachengToolId,
  dachengQuickPrompts,
  dachengToolEntries,
  globalDharmaPublicEndpoints,
  globalDharmaRegions,
  remnoteInspiredFlashcardPrinciples,
} from "@fabushi/shared";
import styles from "./dacheng-chat-shell.module.css";

type Role = "assistant" | "user";
type Rating = "Again" | "Hard" | "Good" | "Easy";

interface Message {
  id: string;
  role: Role;
  text: string;
  tag?: string;
}

interface Card {
  id: string;
  front: string;
  back: string;
  kind: "挖空" | "双向";
  reviews: number;
  due: string;
}

function id() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function sentences(text: string) {
  return text
    .split(/[。！？!?；;\n]+/)
    .map((item) => item.trim())
    .filter((item) => item.length > 5)
    .slice(0, 6);
}

function makeCards(text: string): Card[] {
  return sentences(text).flatMap((sentence) => {
    const plain = sentence.replace(/[，、：,\s]/g, "");
    const term = plain.slice(Math.max(0, Math.floor(plain.length / 3) - 1), Math.max(4, Math.floor(plain.length / 3) + 4));
    const cloze = term && sentence.includes(term) ? sentence.replace(term, "〔……〕") : `${sentence.slice(0, 8)}〔……〕${sentence.slice(12)}`;
    return [
      { id: id(), front: cloze, back: sentence, kind: "挖空" as const, reviews: 0, due: "现在" },
      { id: id(), front: `请背诵并解释：${sentence.slice(0, 18)}…`, back: sentence, kind: "双向" as const, reviews: 0, due: "现在" },
    ];
  });
}

function nextDue(rating: Rating) {
  if (rating === "Again") return "10 分钟后";
  if (rating === "Hard") return "明天";
  if (rating === "Good") return "3 天后";
  return "7 天后";
}

export function DachengChatShell() {
  const [messages, setMessages] = useState<Message[]>([
    { id: "welcome", role: "assistant", text: "欢迎来到大乘。点击 + 可选择全球法布施或背诵闪卡。" },
  ]);
  const [input, setInput] = useState("");
  const [tool, setTool] = useState<DachengToolId | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [cards, setCards] = useState<Card[]>([]);
  const [cardIndex, setCardIndex] = useState(0);
  const [answerVisible, setAnswerVisible] = useState(false);
  const [sendLog, setSendLog] = useState<string[]>([]);
  const activeCard = cards[cardIndex] ?? null;
  const currentTool = useMemo(() => dachengToolEntries.find((item) => item.id === tool), [tool]);

  function add(role: Role, text: string, tag?: string) {
    setMessages((items) => [...items, { id: id(), role, text, tag }]);
  }

  async function sendGlobal(text: string) {
    const log: string[] = [];
    add("assistant", "开始全球法布施：Web 版使用 HTTP 全球公共端点，不包含法布施到平台。", "全球法布施");
    for (const [index, region] of globalDharmaRegions.entries()) {
      const endpoint = globalDharmaPublicEndpoints[index % globalDharmaPublicEndpoints.length];
      try {
        const response = await fetch(endpoint.url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ source: "dacheng-web", region, text, timestamp: new Date().toISOString() }),
        });
        log.push(`${response.ok ? "✓" : "!"} ${region} · ${endpoint.label} · HTTP ${response.status}`);
      } catch {
        log.push(`! ${region} · ${endpoint.label} · 已记录待重试`);
      }
      setSendLog([...log]);
    }
    add("assistant", `全球法布施完成：已处理 ${globalDharmaRegions.length} 个地区。`, "全球法布施");
  }

  function buildDeck(text: string) {
    const nextCards = makeCards(text);
    setCards((items) => [...nextCards, ...items]);
    setCardIndex(0);
    setAnswerVisible(false);
    add("assistant", nextCards.length ? `已制作 ${nextCards.length} 张背诵闪卡。` : "内容太短，请补充正文后再制卡。", "背诵闪卡");
  }

  function submit() {
    const text = input.trim() || "愿以此功德，普及于一切，我等与众生，皆共成佛道。";
    setInput("");
    add("user", text, currentTool?.title);
    if (tool === "global-dharma") void sendGlobal(text);
    else if (tool === "flashcards") buildDeck(text);
    else add("assistant", "已收到。你可以继续对话，或点击 + 进入全球法布施和背诵闪卡。");
  }

  function review(rating: Rating) {
    if (!activeCard) return;
    setCards((items) => items.map((card) => card.id === activeCard.id ? { ...card, reviews: card.reviews + 1, due: nextDue(rating) } : card));
    setAnswerVisible(false);
    setCardIndex((index) => cards.length ? (index + 1) % cards.length : 0);
  }

  return (
    <main className={styles.shell}>
      <aside className={styles.sidebar}>
        <a className={styles.brand} href="/">
          <span>大</span>
          <strong>大乘</strong>
        </a>
        <button type="button" onClick={() => setMessages([{ id: id(), role: "assistant", text: "新的对话已经准备好。" }])}>新对话</button>
        <a className={styles.login} href="/api/app/auth/alipay/login-url?platform=web">支付宝登录</a>
        <div className={styles.tools}>
          {dachengToolEntries.map((item) => (
            <button key={item.id} type="button" className={tool === item.id ? styles.active : ""} onClick={() => setTool(item.id)}>
              <strong>{item.title}</strong>
              <small>{item.description}</small>
            </button>
          ))}
        </div>
      </aside>

      <section className={styles.chat}>
        <header className={styles.header}>
          <span>大乘对话</span>
          <span>{currentTool?.title ?? "通用"}</span>
        </header>
        <div className={styles.messages}>
          {messages.length <= 1 && (
            <div className={styles.empty}>
              <h1>你在忙什么？</h1>
              <p>输入经文、发愿文、链接摘要或问题。点击 + 可进入全球法布施和背诵闪卡。</p>
              <div>{dachengQuickPrompts.map((prompt) => <button key={prompt} type="button" onClick={() => setInput(prompt)}>{prompt}</button>)}</div>
            </div>
          )}
          {messages.map((message) => (
            <article className={`${styles.message} ${styles[message.role]}`} key={message.id}>
              <span>{message.role === "user" ? "我" : "大"}</span>
              <p>{message.tag ? `${message.tag}：` : ""}{message.text}</p>
            </article>
          ))}
        </div>
        <div className={styles.composerWrap}>
          {menuOpen && <div className={styles.menu}>{dachengToolEntries.map((item) => <button key={item.id} type="button" onClick={() => { setTool(item.id); setMenuOpen(false); }}>{item.title}<small>{item.description}</small></button>)}</div>}
          <form className={styles.composer} onSubmit={(event) => { event.preventDefault(); submit(); }}>
            <button type="button" onClick={() => setMenuOpen((value) => !value)}>+</button>
            <textarea value={input} onChange={(event) => setInput(event.target.value)} placeholder="有问题，尽管问" rows={1} />
            {currentTool && <button type="button" onClick={() => setTool(null)}>{currentTool.shortTitle} ×</button>}
            <button type="submit">发送</button>
          </form>
        </div>
      </section>

      <aside className={styles.panel}>
        <section>
          <h2>全球法布施</h2>
          <p>Web 和小程序均不显示“法布施到平台”。</p>
          {(sendLog.length ? sendLog : ["等待发送任务"]).map((line) => <span key={line}>{line}</span>)}
        </section>
        <section>
          <h2>背诵闪卡</h2>
          <p>{cards.length ? `${cards.length} 张卡` : "暂无卡片"}</p>
          {activeCard && <div className={styles.card}><small>{activeCard.kind} · {activeCard.due}</small><strong>{activeCard.front}</strong>{answerVisible ? <p>{activeCard.back}</p> : <button type="button" onClick={() => setAnswerVisible(true)}>显示答案</button>}<div>{(["Again", "Hard", "Good", "Easy"] as Rating[]).map((rating) => <button key={rating} type="button" onClick={() => review(rating)}>{rating}</button>)}</div></div>}
          <ul>{remnoteInspiredFlashcardPrinciples.map((item) => <li key={item}>{item}</li>)}</ul>
        </section>
      </aside>
    </main>
  );
}
