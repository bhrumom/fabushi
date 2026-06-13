"use client";

import { useEffect } from "react";

const COVER_IMAGES: Record<string, string> = {
  T0251: "/faliu/covers/T0251-heart-sutra-cover-thumb.jpg",
};

const COVER_STYLE_ID = "faliu-cover-image-enhancer-style";

function ensureCoverStyles() {
  if (document.getElementById(COVER_STYLE_ID)) {
    return;
  }

  const style = document.createElement("style");
  style.id = COVER_STYLE_ID;
  style.textContent = `
    [data-faliu-cover-image="true"] {
      background-image:
        linear-gradient(180deg, rgba(5, 8, 12, 0.5), rgba(5, 8, 12, 0.2) 42%, rgba(5, 8, 12, 0.7)),
        var(--faliu-cover-image) !important;
      background-size: cover !important;
      background-position: center !important;
      background-color: #081018 !important;
    }

    [data-faliu-cover-image="true"]::before {
      border-color: rgba(244, 239, 225, 0.38) !important;
    }

    [data-faliu-cover-image="true"] > div:first-child {
      opacity: 0.16 !important;
    }

    [data-faliu-cover-image="true"] h2,
    [data-faliu-cover-image="true"] p,
    [data-faliu-cover-image="true"] span {
      text-shadow: 0 2px 18px rgba(0, 0, 0, 0.62);
    }
  `;
  document.head.appendChild(style);
}

function applyCoverImages() {
  const cards = Array.from(document.querySelectorAll<HTMLElement>("article"));

  for (const card of cards) {
    const text = card.textContent ?? "";
    const coverEntry = Object.entries(COVER_IMAGES).find(([work]) => text.includes(work));

    if (!coverEntry) {
      continue;
    }

    const cover = card.querySelector<HTMLElement>("button > div");

    if (!cover) {
      continue;
    }

    const [, imageUrl] = coverEntry;
    cover.dataset.faliuCoverImage = "true";
    cover.style.setProperty("--faliu-cover-image", `url("${imageUrl}")`);
  }
}

export function FaliuCoverImageEnhancer() {
  useEffect(() => {
    ensureCoverStyles();
    applyCoverImages();

    const observer = new MutationObserver(() => applyCoverImages());
    observer.observe(document.body, { childList: true, subtree: true });

    return () => observer.disconnect();
  }, []);

  return null;
}
