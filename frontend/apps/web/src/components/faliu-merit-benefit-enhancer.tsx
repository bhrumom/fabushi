"use client";

import { useEffect, useMemo, useState } from "react";
import { createPortal } from "react-dom";
import { getFaliuMeritBenefits, type FaliuMeritBenefit } from "../lib/faliu-merit-benefits";

const PANEL_TITLE = "功德利益";
const VIDEO_PANEL_TITLE = "视频";
const ALL_SECTIONS_KEY = "__all_sections__";
const READER_SELECTOR = 'section[aria-label="法流"] [class*="readerHtml"]';
const MODAL_SELECTOR = 'section[aria-label="法流"] [role="dialog"][aria-modal="true"]';
const HOST_SELECTOR = '[data-faliu-merit-benefit-host="true"]';
const HIGHLIGHT_NAME = "faliu-merit-benefit-highlight";
const SKIP_TEXT_SELECTOR = ".lb,.noteAnchor,.gaijiInfo,#cbeta-copyright,script,style,[aria-hidden='true']";

interface IndexedCharacter {
  node: Text;
  offset: number;
  length: number;
}

interface TextMatch {
  range: Range;
  element: HTMLElement;
}

interface BenefitSection {
  key: string;
  title: string;
  benefits: FaliuMeritBenefit[];
}

interface FaliuVideoItem {
  id: string;
  title: string;
  description: string;
  src: string;
  duration: string;
  source: string;
}

const FALIU_VIDEOS: Record<string, FaliuVideoItem[]> = {
  "T0235:1": [
    {
      id: "t0235-001-episode1",
      title: "金剛般若波羅蜜經 · 第一支試片",
      description: "以發心、降伏其心、無住布施為主題的 12 秒動畫導讀。導讀與經文原文在畫面中分開標注。",
      src: "/faliu/videos/t0235-001-episode1.mp4",
      duration: "12 秒",
      source: "CBETA XML P5 · T/T08/T08n0235.xml",
    },
  ],
};

function getFaliuVideos(work: string | null, juan: string | null) {
  if (!work || !juan) {
    return [];
  }

  return FALIU_VIDEOS[`${work}:${juan}`] ?? [];
}

function normalizeText(value: string) {
  return value.replace(/\s+/g, "").trim();
}

function getSelectedWorkAndJuan(modal: HTMLElement | null) {
  if (!modal) {
    return { work: null, juan: null };
  }

  const work = modal.querySelector<HTMLElement>('[class*="modalEyebrow"]')?.textContent?.trim() ?? null;
  const metaText = Array.from(modal.querySelectorAll<HTMLElement>('[class*="modalMeta"] span'))
    .map((node) => node.textContent?.trim() ?? "")
    .join(" ");
  const juanMatch = metaText.match(/卷次\s*([0-9]+)/);

  return { work, juan: juanMatch?.[1] ?? null };
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

function getCandidateAnchors(anchorText: string) {
  const normalizedAnchor = normalizeText(anchorText);
  const segments = normalizedAnchor
    .split(/[，。；：！？、,.!?;:]/)
    .map((item) => item.trim())
    .filter((item) => item.length >= 8)
    .sort((left, right) => right.length - left.length);

  return Array.from(new Set([normalizedAnchor, ...segments]));
}

function findOccurrence(source: string, candidate: string, occurrence: number) {
  let fromIndex = 0;
  let foundCount = 0;

  while (fromIndex < source.length) {
    const index = source.indexOf(candidate, fromIndex);

    if (index < 0) {
      return -1;
    }

    foundCount += 1;

    if (foundCount >= occurrence) {
      return index;
    }

    fromIndex = index + candidate.length;
  }

  return -1;
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

function findTextMatch(reader: HTMLElement, benefit: FaliuMeritBenefit): TextMatch | null {
  const { text, characters } = buildVisibleTextIndex(reader);
  const occurrence = benefit.occurrence ?? 1;

  for (const candidate of getCandidateAnchors(benefit.anchorText)) {
    const startIndex = findOccurrence(text, candidate, occurrence);

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
  if (document.getElementById("faliu-merit-benefit-highlight-style")) {
    return;
  }

  const style = document.createElement("style");
  style.id = "faliu-merit-benefit-highlight-style";
  style.textContent = `
    ::highlight(${HIGHLIGHT_NAME}) {
      background: rgba(232, 189, 107, 0.34);
      color: inherit;
    }
  `;
  document.head.appendChild(style);
}

function clearMarks(reader?: HTMLElement | null) {
  const registry = typeof window !== "undefined" ? getHighlightsRegistry() : null;
  registry?.highlights.delete(HIGHLIGHT_NAME);

  reader?.querySelectorAll<HTMLElement>('[data-merit-benefit-highlight="true"]').forEach((node) => {
    node.style.outline = "";
    node.style.background = "";
    node.style.borderRadius = "";
    node.style.padding = "";
    node.style.scrollMarginTop = "";
    node.removeAttribute("data-merit-benefit-highlight");
  });
}

function applyHighlight(match: TextMatch) {
  const registry = getHighlightsRegistry();

  if (registry) {
    ensureHighlightStyle();
    registry.highlights.set(HIGHLIGHT_NAME, new registry.HighlightConstructor(match.range));
  }

  match.element.dataset.meritBenefitHighlight = "true";
  match.element.style.outline = "1px solid rgba(232, 189, 107, 0.72)";
  match.element.style.background = "rgba(232, 189, 107, 0.08)";
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

function scrollToBenefit(benefit: FaliuMeritBenefit) {
  const reader = document.querySelector<HTMLElement>(READER_SELECTOR);

  if (!reader) {
    return;
  }

  clearMarks(reader);
  const match = findTextMatch(reader, benefit);

  if (!match) {
    return;
  }

  applyHighlight(match);
  scrollToMatch(match);
}

function groupBenefits(benefits: FaliuMeritBenefit[]) {
  return benefits.reduce<Record<string, FaliuMeritBenefit[]>>((groups, benefit) => {
    const key = benefit.category || PANEL_TITLE;
    groups[key] = [...(groups[key] ?? []), benefit];
    return groups;
  }, {});
}

function getSectionTitle(benefit: FaliuMeritBenefit) {
  return benefit.sectionTitle?.trim() ?? "";
}

function getBenefitSections(benefits: FaliuMeritBenefit[]) {
  const sections: BenefitSection[] = [];
  const indexByTitle = new Map<string, number>();

  for (const benefit of benefits) {
    const title = getSectionTitle(benefit);

    if (!title) {
      continue;
    }

    const existingIndex = indexByTitle.get(title);

    if (existingIndex !== undefined) {
      sections[existingIndex].benefits.push(benefit);
      continue;
    }

    indexByTitle.set(title, sections.length);
    sections.push({
      key: `section-${sections.length}`,
      title,
      benefits: [benefit],
    });
  }

  return sections;
}

function ensurePortalHost(panel: HTMLElement) {
  const existingHost = panel.querySelector<HTMLElement>(HOST_SELECTOR);

  if (existingHost) {
    return existingHost;
  }

  const host = document.createElement("div");
  host.dataset.faliuMeritBenefitHost = "true";
  panel.appendChild(host);
  return host;
}

function hidePanelChildren(panel: HTMLElement, host: HTMLElement) {
  Array.from(panel.children).forEach((child) => {
    if (!(child instanceof HTMLElement) || child === host) {
      return;
    }

    if (!child.dataset.faliuMeritBenefitPreviousDisplay) {
      child.dataset.faliuMeritBenefitPreviousDisplay = child.style.display;
    }

    child.style.display = "none";
    child.setAttribute("aria-hidden", "true");
  });
}

function restorePanelChildren(panel: HTMLElement, host: HTMLElement) {
  Array.from(panel.children).forEach((child) => {
    if (!(child instanceof HTMLElement) || child === host) {
      return;
    }

    child.style.display = child.dataset.faliuMeritBenefitPreviousDisplay ?? "";
    child.removeAttribute("aria-hidden");
    delete child.dataset.faliuMeritBenefitPreviousDisplay;
  });

  if (host.childElementCount === 0) {
    host.remove();
  }
}

function BenefitList({ benefits }: { benefits: FaliuMeritBenefit[] }) {
  const sections = useMemo(() => getBenefitSections(benefits), [benefits]);
  const hasSectionFilter = sections.length > 1;
  const [activeSectionKey, setActiveSectionKey] = useState<string | null>(null);
  const activeSection = sections.find((section) => section.key === activeSectionKey) ?? sections[0] ?? null;
  const visibleBenefits = hasSectionFilter && activeSectionKey !== ALL_SECTIONS_KEY && activeSection ? activeSection.benefits : benefits;
  const groups = useMemo(() => groupBenefits(visibleBenefits), [visibleBenefits]);

  useEffect(() => {
    if (!hasSectionFilter) {
      setActiveSectionKey(null);
      return;
    }

    if (!activeSectionKey || (activeSectionKey !== ALL_SECTIONS_KEY && !sections.some((section) => section.key === activeSectionKey))) {
      setActiveSectionKey(sections[0]?.key ?? ALL_SECTIONS_KEY);
    }
  }, [activeSectionKey, hasSectionFilter, sections]);

  return (
    <div data-faliu-merit-benefits="true" style={{ display: "grid", gap: 16 }}>
      <div>
        <h4 style={{ margin: "0 0 8px", color: "#ffffff", fontSize: "1rem" }}>{PANEL_TITLE}</h4>
        <p style={{ margin: 0, color: "rgba(255, 255, 255, 0.58)", fontSize: "0.9rem", lineHeight: 1.65 }}>
          共 {benefits.length} 句。点击句子可跳到经文对应位置。
        </p>
      </div>

      {hasSectionFilter ? (
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }} role="tablist" aria-label="按品查看功德利益">
          {sections.map((section) => {
            const isActive = section.key === activeSectionKey;
            return (
              <button
                key={section.key}
                type="button"
                role="tab"
                aria-selected={isActive}
                onClick={() => setActiveSectionKey(section.key)}
                style={{
                  minHeight: 34,
                  maxWidth: "100%",
                  border: `1px solid ${isActive ? "rgba(232, 189, 107, 0.48)" : "rgba(255, 255, 255, 0.12)"}`,
                  borderRadius: 8,
                  padding: "7px 10px",
                  background: isActive ? "rgba(232, 189, 107, 0.16)" : "rgba(255, 255, 255, 0.055)",
                  color: isActive ? "#ffffff" : "rgba(255, 255, 255, 0.68)",
                  cursor: "pointer",
                  fontSize: "0.82rem",
                  fontWeight: 760,
                  lineHeight: 1.25,
                }}
              >
                {section.title} · {section.benefits.length}
              </button>
            );
          })}
          <button
            type="button"
            role="tab"
            aria-selected={activeSectionKey === ALL_SECTIONS_KEY}
            onClick={() => setActiveSectionKey(ALL_SECTIONS_KEY)}
            style={{
              minHeight: 34,
              border: `1px solid ${activeSectionKey === ALL_SECTIONS_KEY ? "rgba(232, 189, 107, 0.48)" : "rgba(255, 255, 255, 0.12)"}`,
              borderRadius: 8,
              padding: "7px 10px",
              background: activeSectionKey === ALL_SECTIONS_KEY ? "rgba(232, 189, 107, 0.16)" : "rgba(255, 255, 255, 0.055)",
              color: activeSectionKey === ALL_SECTIONS_KEY ? "#ffffff" : "rgba(255, 255, 255, 0.68)",
              cursor: "pointer",
              fontSize: "0.82rem",
              fontWeight: 760,
              lineHeight: 1.25,
            }}
          >
            全部 · {benefits.length}
          </button>
        </div>
      ) : sections[0] ? (
        <div style={{ color: "rgba(255, 255, 255, 0.52)", fontSize: "0.82rem", lineHeight: 1.5 }}>
          {sections[0].title}
        </div>
      ) : null}

      {Object.entries(groups).map(([category, items]) => (
        <section key={category} style={{ display: "grid", gap: 10 }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
            <strong style={{ color: "#e8bd6b", fontSize: "0.92rem" }}>{category}</strong>
            <span style={{ color: "rgba(255, 255, 255, 0.45)", fontSize: "0.78rem" }}>{items.length}句</span>
          </div>

          {items.map((benefit) => (
            <button
              key={benefit.id}
              type="button"
              onClick={() => scrollToBenefit(benefit)}
              style={{
                width: "100%",
                border: "1px solid rgba(232, 189, 107, 0.18)",
                borderRadius: 10,
                padding: "12px 13px",
                background: "rgba(232, 189, 107, 0.07)",
                color: "rgba(255, 255, 255, 0.86)",
                cursor: "pointer",
                textAlign: "left",
              }}
            >
              <span style={{ display: "block", lineHeight: 1.68, fontSize: "0.92rem" }}>{benefit.text}</span>
              {benefit.note ? (
                <small style={{ display: "block", marginTop: 8, color: "rgba(255, 255, 255, 0.5)", lineHeight: 1.55 }}>
                  {benefit.note}
                </small>
              ) : null}
            </button>
          ))}
        </section>
      ))}
    </div>
  );
}
function VideoPanel({ videos }: { videos: FaliuVideoItem[] }) {
  return (
    <div data-faliu-videos="true" style={{ display: "grid", gap: 14 }}>
      <div>
        <h4 style={{ margin: "0 0 8px", color: "#ffffff", fontSize: "1rem" }}>{VIDEO_PANEL_TITLE}</h4>
        <p style={{ margin: 0, color: "rgba(255, 255, 255, 0.58)", fontSize: "0.9rem", lineHeight: 1.65 }}>
          共 {videos.length} 支。视频为导读试片，经文原文与说明文字已分开标注。
        </p>
      </div>

      {videos.map((video) => (
        <section key={video.id} style={{ display: "grid", gap: 10 }}>
          <video
            controls
            preload="metadata"
            src={video.src}
            style={{
              width: "100%",
              aspectRatio: "16 / 9",
              border: "1px solid rgba(232, 189, 107, 0.2)",
              borderRadius: 8,
              background: "#050505",
            }}
          />
          <div style={{ display: "grid", gap: 6 }}>
            <strong style={{ color: "#ffffff", fontSize: "0.94rem", lineHeight: 1.45 }}>{video.title}</strong>
            <span style={{ color: "rgba(232, 189, 107, 0.76)", fontSize: "0.8rem", lineHeight: 1.4 }}>{video.duration}</span>
            <p style={{ margin: 0, color: "rgba(255, 255, 255, 0.62)", fontSize: "0.86rem", lineHeight: 1.65 }}>
              {video.description}
            </p>
            <small style={{ color: "rgba(255, 255, 255, 0.42)", fontSize: "0.76rem", lineHeight: 1.45 }}>
              来源：{video.source}
            </small>
          </div>
        </section>
      ))}
    </div>
  );
}

function FaliuSidePanel({ benefits, videos }: { benefits: FaliuMeritBenefit[]; videos: FaliuVideoItem[] }) {
  const [activePanel, setActivePanel] = useState<"video" | "benefits">(videos.length > 0 ? "video" : "benefits");

  useEffect(() => {
    setActivePanel((current) => {
      if (current === "video" && videos.length > 0) {
        return current;
      }

      if (current === "benefits" && benefits.length > 0) {
        return current;
      }

      return videos.length > 0 ? "video" : "benefits";
    });
  }, [benefits.length, videos.length]);

  const tabs = [
    { key: "video" as const, label: VIDEO_PANEL_TITLE, count: videos.length, disabled: videos.length === 0 },
    { key: "benefits" as const, label: PANEL_TITLE, count: benefits.length, disabled: benefits.length === 0 },
  ];

  return (
    <div data-faliu-side-panel="true" style={{ display: "grid", gap: 16 }}>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(2, minmax(0, 1fr))", gap: 8 }} role="tablist" aria-label="法流侧边栏内容">
        {tabs.map((tab) => {
          const isActive = activePanel === tab.key;

          return (
            <button
              key={tab.key}
              type="button"
              role="tab"
              aria-selected={isActive}
              disabled={tab.disabled}
              onClick={() => setActivePanel(tab.key)}
              style={{
                minHeight: 36,
                border: `1px solid ${isActive ? "rgba(232, 189, 107, 0.48)" : "rgba(255, 255, 255, 0.12)"}`,
                borderRadius: 8,
                padding: "8px 10px",
                background: isActive ? "rgba(232, 189, 107, 0.16)" : "rgba(255, 255, 255, 0.055)",
                color: tab.disabled ? "rgba(255, 255, 255, 0.32)" : isActive ? "#ffffff" : "rgba(255, 255, 255, 0.68)",
                cursor: tab.disabled ? "not-allowed" : "pointer",
                fontSize: "0.84rem",
                fontWeight: 760,
                lineHeight: 1.25,
              }}
            >
              {tab.label} · {tab.count}
            </button>
          );
        })}
      </div>

      {activePanel === "video" && videos.length > 0 ? <VideoPanel videos={videos} /> : <BenefitList benefits={benefits} />}
    </div>
  );
}

export function FaliuMeritBenefitEnhancer() {
  const [targetHost, setTargetHost] = useState<HTMLElement | null>(null);
  const [targetPanel, setTargetPanel] = useState<HTMLElement | null>(null);
  const [benefits, setBenefits] = useState<FaliuMeritBenefit[]>([]);
  const [videos, setVideos] = useState<FaliuVideoItem[]>([]);

  useEffect(() => {
    function refresh() {
      const modal = document.querySelector<HTMLElement>(MODAL_SELECTOR);
      const { work, juan } = getSelectedWorkAndJuan(modal);
      const nextBenefits = getFaliuMeritBenefits(work, juan);
      const nextVideos = getFaliuVideos(work, juan);
      const infoPanels = Array.from(modal?.querySelectorAll<HTMLElement>('[class*="infoPanel"]') ?? []);
      const tocPanel = infoPanels.find((panel) => panel.querySelector("h4")?.textContent?.trim() === "目录") ?? null;

      if ((nextBenefits.length > 0 || nextVideos.length > 0) && tocPanel) {
        setTargetPanel(tocPanel);
        setTargetHost(ensurePortalHost(tocPanel));
      } else {
        setTargetPanel(null);
        setTargetHost(null);
      }

      setBenefits(nextBenefits);
      setVideos(nextVideos);
    }

    refresh();

    const observer = new MutationObserver(refresh);
    observer.observe(document.body, { childList: true, subtree: true });

    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!targetPanel || !targetHost || (benefits.length === 0 && videos.length === 0)) {
      return;
    }

    hidePanelChildren(targetPanel, targetHost);

    return () => {
      restorePanelChildren(targetPanel, targetHost);
    };
  }, [benefits.length, targetHost, targetPanel, videos.length]);

  useEffect(() => {
    return () => clearMarks(document.querySelector<HTMLElement>(READER_SELECTOR));
  }, []);

  if (!targetHost || (benefits.length === 0 && videos.length === 0)) {
    return null;
  }

  return createPortal(<FaliuSidePanel benefits={benefits} videos={videos} />, targetHost);
}
