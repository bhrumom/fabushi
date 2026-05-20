"use client";

import { useEffect, useMemo, useState } from "react";
import { createPortal } from "react-dom";
import { getFaliuMeritBenefits, type FaliuMeritBenefit } from "../lib/faliu-merit-benefits";

const PANEL_TITLE = "功德利益";
const READER_SELECTOR = 'section[aria-label="法流"] [class*="readerHtml"]';
const MODAL_SELECTOR = 'section[aria-label="法流"] [role="dialog"][aria-modal="true"]';
const HOST_SELECTOR = '[data-faliu-merit-benefit-host="true"]';

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

function findTextNode(root: Node, anchorText: string, occurrence = 1) {
  const normalizedAnchor = normalizeText(anchorText);
  let foundCount = 0;
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  let node = walker.nextNode();

  while (node) {
    const text = node.textContent ?? "";
    const normalized = normalizeText(text);

    if (normalized.includes(normalizedAnchor) || normalizedAnchor.includes(normalized)) {
      foundCount += 1;
      if (foundCount >= occurrence) {
        return node;
      }
    }

    node = walker.nextNode();
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

function clearMarks(reader: HTMLElement) {
  reader.querySelectorAll<HTMLElement>('[data-merit-benefit-highlight="true"]').forEach((node) => {
    node.style.outline = "";
    node.style.background = "";
    node.style.borderRadius = "";
    node.removeAttribute("data-merit-benefit-highlight");
  });
}

function scrollToBenefit(benefit: FaliuMeritBenefit) {
  const reader = document.querySelector<HTMLElement>(READER_SELECTOR);

  if (!reader) {
    return;
  }

  clearMarks(reader);
  const targetNode = findTextNode(reader, benefit.anchorText, benefit.occurrence ?? 1);
  const targetElement = targetNode?.parentElement;

  if (!targetElement) {
    return;
  }

  targetElement.dataset.meritBenefitHighlight = "true";
  targetElement.style.outline = "1px solid rgba(232, 189, 107, 0.72)";
  targetElement.style.background = "rgba(232, 189, 107, 0.12)";
  targetElement.style.borderRadius = "8px";

  const scrollParent = getScrollableParent(targetElement);

  if (scrollParent) {
    const parentRect = scrollParent.getBoundingClientRect();
    const targetRect = targetElement.getBoundingClientRect();
    scrollParent.scrollTo({
      top: scrollParent.scrollTop + targetRect.top - parentRect.top - 24,
      behavior: "smooth",
    });
  } else {
    targetElement.scrollIntoView({ behavior: "smooth", block: "center" });
  }
}

function groupBenefits(benefits: FaliuMeritBenefit[]) {
  return benefits.reduce<Record<string, FaliuMeritBenefit[]>>((groups, benefit) => {
    const key = benefit.category || PANEL_TITLE;
    groups[key] = [...(groups[key] ?? []), benefit];
    return groups;
  }, {});
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

function MeritBenefitPanel({ benefits }: { benefits: FaliuMeritBenefit[] }) {
  const groups = useMemo(() => groupBenefits(benefits), [benefits]);

  return (
    <div data-faliu-merit-benefits="true" style={{ display: "grid", gap: 16 }}>
      <div>
        <h4 style={{ margin: "0 0 8px", color: "#ffffff", fontSize: "1rem" }}>{PANEL_TITLE}</h4>
        <p style={{ margin: 0, color: "rgba(255, 255, 255, 0.58)", fontSize: "0.9rem", lineHeight: 1.65 }}>
          共 {benefits.length} 句。点击句子可跳到经文对应位置。
        </p>
      </div>

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

export function FaliuMeritBenefitEnhancer() {
  const [targetHost, setTargetHost] = useState<HTMLElement | null>(null);
  const [targetPanel, setTargetPanel] = useState<HTMLElement | null>(null);
  const [benefits, setBenefits] = useState<FaliuMeritBenefit[]>([]);

  useEffect(() => {
    function refresh() {
      const modal = document.querySelector<HTMLElement>(MODAL_SELECTOR);
      const { work, juan } = getSelectedWorkAndJuan(modal);
      const nextBenefits = getFaliuMeritBenefits(work, juan);
      const infoPanels = Array.from(modal?.querySelectorAll<HTMLElement>('[class*="infoPanel"]') ?? []);
      const tocPanel = infoPanels.find((panel) => panel.querySelector("h4")?.textContent?.trim() === "目录") ?? null;

      if (nextBenefits.length > 0 && tocPanel) {
        setTargetPanel(tocPanel);
        setTargetHost(ensurePortalHost(tocPanel));
      } else {
        setTargetPanel(null);
        setTargetHost(null);
      }

      setBenefits(nextBenefits);
    }

    refresh();

    const observer = new MutationObserver(refresh);
    observer.observe(document.body, { childList: true, subtree: true });

    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!targetPanel || !targetHost || benefits.length === 0) {
      return;
    }

    hidePanelChildren(targetPanel, targetHost);

    return () => {
      restorePanelChildren(targetPanel, targetHost);
    };
  }, [benefits.length, targetHost, targetPanel]);

  if (!targetHost || benefits.length === 0) {
    return null;
  }

  return createPortal(<MeritBenefitPanel benefits={benefits} />, targetHost);
}
