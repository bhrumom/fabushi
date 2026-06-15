"use client";

import { useEffect, useMemo, useState } from "react";
import { createPortal } from "react-dom";
import { FALIU_ANKI_DECK_MAP, type FaliuAnkiCard, type FaliuAnkiDeck } from "../data/faliu-anki-cards";

const REVIEW_STORAGE_KEY = "fabushi:faliu-anki-review:v1";
const MAX_FALLBACK_CARDS = 12;
const READER_SELECTOR = 'section[aria-label="法流"] [class*="readerHtml"]';
const HIGHLIGHT_NAME = "faliu-anki-source-highlight";
const SKIP_TEXT_SELECTOR = ".lb,.noteAnchor,.gaijiInfo,#cbeta-copyright,script,style,[aria-hidden='true']";

type ReviewGrade = "again" | "hard" | "good" | "easy";

interface ReviewRecord {
  reviewed: number;
  ease: number;
  intervalDays: number;
  due: number;
}

interface ReaderContext {
  contentId: string;
  work: string;
  juan: string;
  title: string;
  readerText: string;
  host: HTMLElement;
}

interface IndexedCharacter {
  node: Text;
  offset: number;
  length: number;
}

interface TextMatch {
  range: Range;
  element: HTMLElement;
}

function buildContentId(work: string, juan: string) {
  return `cbeta:${work}:${juan}`;
}

function getModal() {
  return document.querySelector<HTMLElement>('section[aria-label="法流"] div[class*="modal"][role="dialog"]');
}

function getSidePanel() {
  return document.querySelector<HTMLElement>('section[aria-label="法流"] aside[class*="sidePanel"]');
}

function getText(selector: string, root: ParentNode = document) {
  return root.querySelector<HTMLElement>(selector)?.textContent?.trim() ?? "";
}

function getSelectedJuan(modal: HTMLElement) {
  const metaText = Array.from(modal.querySelectorAll<HTMLElement>('div[class*="modalMeta"] span'))
    .map((item) => item.textContent?.trim() ?? "")
    .find((item) => item.startsWith("卷次"));

  return metaText?.replace(/^卷次\s*/, "").trim() || "1";
}

function isSameContext(left: ReaderContext | null, right: ReaderContext | null) {
  if (left === right) {
    return true;
  }

  if (!left || !right) {
    return false;
  }

  return (
    left.contentId === right.contentId &&
    left.title === right.title &&
    left.readerText === right.readerText &&
    left.host === right.host
  );
}

function readReviewRecords(): Record<string, ReviewRecord> {
  try {
    const raw = window.localStorage.getItem(REVIEW_STORAGE_KEY);
    return raw ? (JSON.parse(raw) as Record<string, ReviewRecord>) : {};
  } catch {
    return {};
  }
}

function writeReviewRecords(records: Record<string, ReviewRecord>) {
  try {
    window.localStorage.setItem(REVIEW_STORAGE_KEY, JSON.stringify(records));
  } catch {
    return;
  }
}

function normalizeReaderLine(value: string) {
  return value.replace(/\s+/g, " ").replace(/[\u2460-\u2473]/g, "").trim();
}

function normalizeSearchText(value: string) {
  return value.replace(/\s+/g, "").trim();
}

function shouldSkipTextNode(node: Node, root: HTMLElement) {
  const parent = node.parentElement;

  if (!parent || !root.contains(parent)) {
    return true;
  }

  return Boolean(parent.closest(SKIP_TEXT_SELECTOR));
}

function buildVisibleTextIndex(root: HTMLElement) {
  const characters: IndexedCharacter[] = [];
  let text = "";
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
    acceptNode(node) {
      return shouldSkipTextNode(node, root) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
    },
  });

  let node = walker.nextNode();

  while (node) {
    const value = node.textContent ?? "";
    let offset = 0;

    for (const character of value) {
      if (!/\s/.test(character)) {
        text += character;
        characters.push({ node: node as Text, offset, length: character.length });
      }

      offset += character.length;
    }

    node = walker.nextNode();
  }

  return { text, characters };
}

function getCandidateAnchors(sourceText: string) {
  const normalizedSource = normalizeSearchText(sourceText);
  const segments = normalizedSource
    .split(/[，。；：！？、,.!?;:]/)
    .map((item) => item.trim())
    .filter((item) => item.length >= 4)
    .sort((left, right) => right.length - left.length);

  return Array.from(new Set([normalizedSource, ...segments]));
}

function getElementForRange(range: Range, reader: HTMLElement) {
  const startElement = range.startContainer instanceof HTMLElement ? range.startContainer : range.startContainer.parentElement;
  let current = startElement;

  while (current && current !== reader) {
    if (["P", "DIV", "LI", "SECTION", "ARTICLE"].includes(current.tagName)) {
      return current;
    }

    current = current.parentElement;
  }

  return startElement ?? reader;
}

function findTextMatch(reader: HTMLElement, sourceText: string): TextMatch | null {
  const { text, characters } = buildVisibleTextIndex(reader);

  for (const candidate of getCandidateAnchors(sourceText)) {
    const startIndex = text.indexOf(candidate);

    if (startIndex < 0) {
      continue;
    }

    const endIndex = startIndex + candidate.length - 1;
    const start = characters[startIndex];
    const end = characters[endIndex];

    if (!start || !end) {
      continue;
    }

    const range = document.createRange();
    range.setStart(start.node, start.offset);
    range.setEnd(end.node, end.offset + end.length);

    return {
      range,
      element: getElementForRange(range, reader),
    };
  }

  return null;
}

function getScrollableParent(element: HTMLElement | null) {
  let current = element?.parentElement ?? null;

  while (current) {
    const style = window.getComputedStyle(current);
    const canScroll = /(auto|scroll)/.test(`${style.overflow}${style.overflowY}${style.overflowX}`);

    if (canScroll && current.scrollHeight > current.clientHeight) {
      return current;
    }

    current = current.parentElement;
  }

  return null;
}

function getHighlightsRegistry() {
  const css = window.CSS as unknown as { highlights?: { delete: (name: string) => void; set: (name: string, value: unknown) => void } };
  const HighlightConstructor = (window as unknown as { Highlight?: new (range: Range) => unknown }).Highlight;

  if (!css.highlights || !HighlightConstructor) {
    return null;
  }

  return { highlights: css.highlights, HighlightConstructor };
}

function ensureHighlightStyle() {
  if (document.getElementById("faliu-anki-source-highlight-style")) {
    return;
  }

  const style = document.createElement("style");
  style.id = "faliu-anki-source-highlight-style";
  style.textContent = `
    ::highlight(${HIGHLIGHT_NAME}) {
      background: rgba(111, 211, 255, 0.34);
      color: inherit;
    }
  `;
  document.head.appendChild(style);
}

function clearSourceMarks(reader?: HTMLElement | null) {
  const registry = typeof window !== "undefined" ? getHighlightsRegistry() : null;
  registry?.highlights.delete(HIGHLIGHT_NAME);

  reader?.querySelectorAll<HTMLElement>('[data-anki-source-highlight="true"]').forEach((node) => {
    node.style.outline = "";
    node.style.background = "";
    node.style.borderRadius = "";
    node.style.padding = "";
    node.style.scrollMarginTop = "";
    node.removeAttribute("data-anki-source-highlight");
  });
}

function applySourceHighlight(match: TextMatch) {
  const registry = getHighlightsRegistry();

  if (registry) {
    ensureHighlightStyle();
    registry.highlights.set(HIGHLIGHT_NAME, new registry.HighlightConstructor(match.range));
  }

  match.element.dataset.ankiSourceHighlight = "true";
  match.element.style.outline = "1px solid rgba(111, 211, 255, 0.72)";
  match.element.style.background = "rgba(111, 211, 255, 0.08)";
  match.element.style.borderRadius = "8px";
  match.element.style.padding = "4px 6px";
  match.element.style.scrollMarginTop = "24px";
}

function scrollToMatch(match: TextMatch) {
  const scrollParent = getScrollableParent(match.element);
  const rect = match.range.getBoundingClientRect();
  const targetRect = rect.height > 0 ? rect : match.element.getBoundingClientRect();

  if (scrollParent) {
    const parentRect = scrollParent.getBoundingClientRect();
    scrollParent.scrollTo({
      top: scrollParent.scrollTop + targetRect.top - parentRect.top - 32,
      behavior: "smooth",
    });
  } else {
    match.element.scrollIntoView({ behavior: "smooth", block: "center" });
  }
}

function scrollToCardSource(card: FaliuAnkiCard) {
  if (!card.sourceText) {
    return false;
  }

  const reader = document.querySelector<HTMLElement>(READER_SELECTOR);

  if (!reader) {
    return false;
  }

  clearSourceMarks(reader);
  const match = findTextMatch(reader, card.sourceText);

  if (!match) {
    return false;
  }

  applySourceHighlight(match);
  scrollToMatch(match);
  return true;
}

function buildFallbackDeck(context: ReaderContext): FaliuAnkiDeck {
  const lines = context.readerText
    .split(/[\n。！？!?；;]/)
    .map(normalizeReaderLine)
    .filter((line) => line.length >= 12 && line.length <= 90)
    .filter((line) => !/^第.+卷$/.test(line) && !line.includes("CBETA") && !line.includes("大正藏"));

  const seen = new Set<string>();
  const cards: FaliuAnkiCard[] = [];

  for (const line of lines) {
    if (seen.has(line)) {
      continue;
    }

    seen.add(line);
    const cueLength = Math.min(14, Math.max(6, Math.floor(line.length * 0.34)));
    const cue = line.slice(0, cueLength);
    cards.push({
      id: `${context.contentId}:auto-${cards.length + 1}`,
      front: `請背誦接下來的經文：${cue}……`,
      back: line,
      hint: `摘自第 ${context.juan} 卷正文`,
      sourceText: line,
      tags: [context.work, "auto"],
    });

    if (cards.length >= MAX_FALLBACK_CARDS) {
      break;
    }
  }

  return {
    contentId: context.contentId,
    work: context.work,
    juan: context.juan,
    title: context.title,
    cards,
  };
}

function getReaderContext(): ReaderContext | null {
  const modal = getModal();
  const host = getSidePanel();

  if (!modal || !host) {
    return null;
  }

  const work = getText('p[class*="modalEyebrow"]', modal);
  const title = getText("h3", modal);
  const juan = getSelectedJuan(modal);
  const readerText = getText('div[class*="readerHtml"]', modal);

  if (!work || !title || !juan) {
    return null;
  }

  return {
    contentId: buildContentId(work, juan),
    work,
    juan,
    title,
    readerText,
    host,
  };
}

function scheduleReview(current: ReviewRecord | undefined, grade: ReviewGrade): ReviewRecord {
  const now = Date.now();
  const baseEase = current?.ease ?? 2.5;
  const baseInterval = current?.intervalDays ?? 0;
  const nextEase = Math.max(1.3, baseEase + (grade === "easy" ? 0.15 : grade === "hard" ? -0.15 : grade === "again" ? -0.25 : 0));
  const nextInterval =
    grade === "again"
      ? 0
      : grade === "hard"
        ? Math.max(1, Math.round(baseInterval || 1))
        : grade === "easy"
          ? Math.max(4, Math.round((baseInterval || 2) * nextEase * 1.3))
          : Math.max(2, Math.round((baseInterval || 1) * nextEase));

  return {
    reviewed: now,
    ease: nextEase,
    intervalDays: nextInterval,
    due: now + nextInterval * 24 * 60 * 60 * 1000,
  };
}

export function FaliuAnkiEnhancer() {
  const [context, setContext] = useState<ReaderContext | null>(null);
  const [records, setRecords] = useState<Record<string, ReviewRecord>>({});
  const [activeIndex, setActiveIndex] = useState(0);
  const [isRevealed, setIsRevealed] = useState(false);
  const [sourceLookupFailed, setSourceLookupFailed] = useState(false);

  useEffect(() => {
    setRecords(readReviewRecords());
  }, []);

  useEffect(() => {
    const syncContext = () => {
      const nextContext = getReaderContext();
      setContext((currentContext) => (isSameContext(currentContext, nextContext) ? currentContext : nextContext));
    };
    const observer = new MutationObserver(() => window.setTimeout(syncContext, 80));

    observer.observe(document.body, { childList: true, subtree: true, characterData: true });
    syncContext();

    return () => observer.disconnect();
  }, []);

  const deck = useMemo(() => {
    if (!context) {
      return null;
    }

    return FALIU_ANKI_DECK_MAP[context.contentId] ?? buildFallbackDeck(context);
  }, [context]);

  useEffect(() => {
    setActiveIndex(0);
    setIsRevealed(false);
    setSourceLookupFailed(false);
  }, [deck?.contentId]);

  useEffect(() => {
    setSourceLookupFailed(false);
  }, [activeIndex, deck?.contentId]);

  useEffect(() => {
    return () => clearSourceMarks(document.querySelector<HTMLElement>(READER_SELECTOR));
  }, []);

  const dueCards = useMemo(() => {
    if (!deck) {
      return [];
    }

    const now = Date.now();
    const due = deck.cards.filter((card) => !records[card.id] || records[card.id].due <= now);
    return due.length > 0 ? due : deck.cards;
  }, [deck, records]);

  if (!context || !deck) {
    return null;
  }

  const activeCard = dueCards[activeIndex % Math.max(1, dueCards.length)];
  const finishedCount = deck.cards.filter((card) => records[card.id]?.reviewed).length;
  const isAiDeck = Boolean(FALIU_ANKI_DECK_MAP[context.contentId]);

  function review(grade: ReviewGrade) {
    if (!activeCard) {
      return;
    }

    const nextRecords = {
      ...records,
      [activeCard.id]: scheduleReview(records[activeCard.id], grade),
    };

    setRecords(nextRecords);
    writeReviewRecords(nextRecords);
    setIsRevealed(false);
    setSourceLookupFailed(false);
    setActiveIndex((current) => (dueCards.length <= 1 ? 0 : (current + 1) % dueCards.length));
  }

  function jumpToSource() {
    if (!activeCard) {
      return;
    }

    setSourceLookupFailed(!scrollToCardSource(activeCard));
  }

  return createPortal(
    <section
      aria-label="经文背诵卡片"
      style={{
        marginTop: 16,
        padding: 18,
        border: "1px solid rgba(232, 189, 107, 0.18)",
        borderRadius: 8,
        background: "linear-gradient(180deg, rgba(232, 189, 107, 0.08), rgba(255, 255, 255, 0.04))",
      }}
    >
      <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", gap: 12 }}>
        <div>
          <h4 style={{ margin: "0 0 6px", color: "#ffffff", fontSize: "1rem" }}>背诵卡片</h4>
          <p style={{ margin: 0, color: "rgba(255, 255, 255, 0.56)", fontSize: "0.86rem", lineHeight: 1.55 }}>
            {isAiDeck ? "AI 精修卡片" : "临时摘句卡片，后续可由 AI 批量替换"} · {deck.cards.length} 张
          </p>
        </div>
        <span style={{ color: "rgba(255, 255, 255, 0.55)", fontSize: "0.82rem" }}>
          {finishedCount}/{deck.cards.length}
        </span>
      </div>

      {activeCard ? (
        <div style={{ marginTop: 16 }}>
          <div
            style={{
              minHeight: 160,
              display: "grid",
              gap: 14,
              alignContent: "center",
              padding: 18,
              borderRadius: 8,
              background: "rgba(0, 0, 0, 0.2)",
              border: "1px solid rgba(255, 255, 255, 0.08)",
            }}
          >
            <p style={{ margin: 0, color: "#ffffff", fontSize: "1.02rem", fontWeight: 760, lineHeight: 1.72 }}>
              {activeCard.front}
            </p>
            {activeCard.hint ? (
              <p style={{ margin: 0, color: "rgba(255, 255, 255, 0.58)", fontSize: "0.9rem", lineHeight: 1.55 }}>
                提示：{activeCard.hint}
              </p>
            ) : null}
            {isRevealed ? (
              <p style={{ margin: 0, color: "#ffe3a3", fontSize: "1rem", lineHeight: 1.78 }}>
                {activeCard.back}
              </p>
            ) : null}
          </div>

          {activeCard.sourceText ? (
            <div style={{ marginTop: 12, display: "grid", gap: 8 }}>
              <button
                type="button"
                onClick={jumpToSource}
                style={{
                  width: "100%",
                  minHeight: 38,
                  border: "1px solid rgba(111, 211, 255, 0.32)",
                  borderRadius: 8,
                  background: "rgba(111, 211, 255, 0.1)",
                  color: "#ffffff",
                  fontSize: "0.88rem",
                  fontWeight: 760,
                  cursor: "pointer",
                }}
              >
                定位原文
              </button>
              {sourceLookupFailed ? (
                <p style={{ margin: 0, color: "rgba(255, 255, 255, 0.5)", fontSize: "0.82rem", lineHeight: 1.5 }}>
                  暂未在当前正文中匹配到这张卡的来源句。
                </p>
              ) : null}
            </div>
          ) : null}

          {!isRevealed ? (
            <button
              type="button"
              onClick={() => setIsRevealed(true)}
              style={{
                width: "100%",
                minHeight: 42,
                marginTop: 12,
                border: "1px solid rgba(232, 189, 107, 0.34)",
                borderRadius: 8,
                background: "rgba(232, 189, 107, 0.16)",
                color: "#ffffff",
                fontWeight: 820,
                cursor: "pointer",
              }}
            >
              显示答案
            </button>
          ) : (
            <div style={{ display: "grid", gridTemplateColumns: "repeat(4, minmax(0, 1fr))", gap: 8, marginTop: 12 }}>
              {[
                ["again", "重来"],
                ["hard", "困难"],
                ["good", "记得"],
                ["easy", "熟了"],
              ].map(([grade, label]) => (
                <button
                  key={grade}
                  type="button"
                  onClick={() => review(grade as ReviewGrade)}
                  style={{
                    minHeight: 38,
                    border: "1px solid rgba(255, 255, 255, 0.1)",
                    borderRadius: 8,
                    background: "rgba(255, 255, 255, 0.07)",
                    color: "#ffffff",
                    fontSize: "0.88rem",
                    fontWeight: 760,
                    cursor: "pointer",
                  }}
                >
                  {label}
                </button>
              ))}
            </div>
          )}
        </div>
      ) : (
        <p style={{ margin: "14px 0 0", color: "rgba(255, 255, 255, 0.58)", lineHeight: 1.65 }}>
          正文载入后会自动生成可练习的摘句卡；AI 批量卡片导入后会优先显示精修版本。
        </p>
      )}
    </section>,
    context.host,
  );
}
