"use client";

import { useMemo, useState } from "react";
import {
  buildGlobalDharmaChecklist,
  createDachengId,
  dachengBrand,
  dachengHeroChips,
  dachengToolEntries,
  globalDharmaStartMessage,
  makeDachengFlashcards,
  nextDachengFlashcardDue,
  remnoteInspiredFlashcardPrinciples,
  type DachengFlashcard,
  type DachengRating,
  type DachengToolId,
} from "@fabushi/shared";

type Role = "assistant" | "user";

interface Message {
  id: string;
  role: Role;
  text: string;
  tag?: string;
}

const ratingLabels: DachengRating[] = ["Again", "Hard", "Good", "Easy"];

export function FastDachengHome() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [tool, setTool] = useState<DachengToolId | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [logs, setLogs] = useState<string[]>([]);
  const [cards, setCards] = useState<DachengFlashcard[]>([]);
  const [cardIndex, setCardIndex] = useState(0);
  const [answerVisible, setAnswerVisible] = useState(false);

  const activeTool = useMemo(
    () => dachengToolEntries.find((item) => item.id === tool) ?? null,
    [tool],
  );
  const activeCard = cards[cardIndex] ?? null;

  function add(role: Role, text: string, tag?: string) {
    setMessages((items) => [...items, { id: createDachengId("msg"), role, text, tag }]);
  }

  function resetChat() {
    setMessages([]);
    setInput("");
    setTool(null);
    setMenuOpen(false);
    setLogs([]);
    setCards([]);
    setCardIndex(0);
    setAnswerVisible(false);
  }

  function choosePrompt(prompt: string, nextTool?: DachengToolId) {
    setInput(prompt);
    setTool(nextTool ?? null);
    setMenuOpen(false);
  }

  function runGlobalDharma(text: string) {
    const checklist = buildGlobalDharmaChecklist(text);
    setLogs(checklist.map((item) => `✓ ${item.label}`));
    add("assistant", globalDharmaStartMessage("web"), "全球法布施");
    add("assistant", `全球法布施完成：已整理 ${checklist.length} 个地区。`, "全球法布施");
  }

  function buildDeck(text: string) {
    const nextCards = makeDachengFlashcards(text);
    setCards((items) => [...nextCards, ...items]);
    setCardIndex(0);
    setAnswerVisible(false);
    add(
      "assistant",
      nextCards.length ? `已制作 ${nextCards.length} 张背诵闪卡。` : "内容太短，请补充正文后再制卡。",
      "背诵闪卡",
    );
  }

  function submit() {
    const text = input.trim() || dachengBrand.defaultText;
    setInput("");
    add("user", text, activeTool?.title);

    if (tool === "global-dharma") {
      runGlobalDharma(text);
      return;
    }

    if (tool === "flashcards") {
      buildDeck(text);
      return;
    }

    add("assistant", "已收到。可以继续输入，或点击 + 进入全球法布施和背诵闪卡。");
  }

  function review(rating: DachengRating) {
    if (!activeCard) return;

    setCards((items) =>
      items.map((card) =>
        card.id === activeCard.id
          ? { ...card, reviews: card.reviews + 1, due: nextDachengFlashcardDue(rating) }
          : card,
      ),
    );
    setAnswerVisible(false);
    setCardIndex((index) => (cards.length ? (index + 1) % cards.length : 0));
  }

  return (
    <main className={messages.length ? "fast-home has-chat" : "fast-home"}>
      <div className="fast-bg" aria-hidden="true" />

      <aside className="fast-sidebar" aria-label="首页功能">
        <a className="fast-logo" href="/">
          <span className="fast-logo-mark">大</span>
          <span>{dachengBrand.name}</span>
        </a>
        <button className="fast-side-button" type="button" onClick={resetChat}>
          ✦ 新对话
        </button>
        <nav className="fast-side-nav" aria-label="快捷功能">
          {dachengToolEntries.map((item) => (
            <button
              key={item.id}
              type="button"
              className={tool === item.id ? "is-active" : ""}
              onClick={() => setTool(item.id)}
            >
              <span>{item.icon}</span>
              <strong>{item.title}</strong>
              <small>{item.action}</small>
            </button>
          ))}
        </nav>
      </aside>

      <section className="fast-stage" aria-label="大乘首页">
        <header className="fast-topbar">
          <span className="fast-mobile-brand">{dachengBrand.name}</span>
          <div>
            <span className="fast-speed-badge">极速 Web</span>
            <button type="button" className="fast-login">登录</button>
          </div>
        </header>

        {!messages.length && (
          <section className="fast-hero">
            <h1>{dachengBrand.greeting}</h1>
            <p>{dachengBrand.tagline}</p>
            <div className="fast-chips" aria-label="建议问题">
              {dachengHeroChips.map((chip) => (
                <button key={chip.id} type="button" onClick={() => choosePrompt(chip.prompt, chip.tool)}>
                  <span>{chip.icon}</span>
                  {chip.label}
                </button>
              ))}
            </div>
          </section>
        )}

        <section className="fast-messages" aria-live="polite">
          {messages.map((message) => (
            <article className={`fast-message ${message.role}`} key={message.id}>
              <span className="fast-avatar">{message.role === "user" ? "我" : dachengBrand.name.slice(0, 1)}</span>
              <p className="fast-bubble">{message.tag ? `${message.tag}：` : ""}{message.text}</p>
            </article>
          ))}
        </section>

        <section className="fast-composer-wrap" aria-label="输入框">
          {menuOpen && (
            <div className="fast-tool-menu">
              {dachengToolEntries.map((item) => (
                <button key={item.id} type="button" onClick={() => { setTool(item.id); setMenuOpen(false); }}>
                  <span>{item.icon}</span>
                  <strong>{item.title}</strong>
                  <small>{item.description}</small>
                </button>
              ))}
            </div>
          )}
          <form
            className="fast-composer"
            onSubmit={(event) => {
              event.preventDefault();
              submit();
            }}
          >
            <button className="fast-plus" type="button" onClick={() => setMenuOpen((value) => !value)} aria-label="打开功能">
              +
            </button>
            <textarea
              value={input}
              rows={1}
              maxLength={1800}
              placeholder={activeTool ? `${activeTool.action}，也可以继续问一问大乘` : dachengBrand.inputPlaceholder}
              aria-label={dachengBrand.inputPlaceholder}
              onChange={(event) => setInput(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter" && !event.shiftKey) {
                  event.preventDefault();
                  submit();
                }
              }}
            />
            {activeTool && (
              <button className="fast-mode" type="button" onClick={() => setTool(null)}>
                {activeTool.shortTitle} ×
              </button>
            )}
            <button className="fast-send" type="submit" aria-label="发送">
              ➤
            </button>
          </form>
        </section>
      </section>

      <aside className="fast-tool-panel" aria-label="功能状态">
        <section>
          <h2>全球法布施</h2>
          <p>只保留首页轻量流程，首屏不加载 App 专属页面。</p>
          <pre>{logs.length ? logs.join("\n") : "等待输入正文后生成全球法布施清单。"}</pre>
        </section>
        <section>
          <h2>背诵闪卡</h2>
          <p>{cards.length ? `${cards.length} 张卡片` : "暂无卡片"}</p>
          <div className="fast-card">
            {activeCard ? (
              <>
                <small>{activeCard.kind} · {activeCard.due} · 已复习 {activeCard.reviews} 次</small>
                <strong>{activeCard.front}</strong>
                {answerVisible ? <p>{activeCard.back}</p> : <button type="button" onClick={() => setAnswerVisible(true)}>显示答案</button>}
                <div className="fast-reviews">
                  {ratingLabels.map((rating) => (
                    <button key={rating} type="button" onClick={() => review(rating)}>{rating}</button>
                  ))}
                </div>
              </>
            ) : (
              <p>输入正文并选择背诵闪卡后，这里会出现挖空卡和双向卡。</p>
            )}
          </div>
          <ul>
            {remnoteInspiredFlashcardPrinciples.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </section>
      </aside>
    </main>
  );
}
