"use client";

import { useEffect } from "react";

const COVER_IMAGES: Record<string, string> = {
  T0251: "/faliu/covers/T0251-heart-sutra-cover-thumb.jpg",
  T0366: "/faliu/covers/T0366-amitabha-sutra-cover-thumb.jpg",
};

function findCoverElement(card: HTMLElement, work: string) {
  const candidates = Array.from(card.querySelectorAll<HTMLElement>("button div"));
  return candidates.find((element) => (element.textContent ?? "").includes(work) && element.querySelector("h2")) ?? null;
}

function applyInlineCoverStyle(cover: HTMLElement, imageUrl: string) {
  cover.dataset.faliuCoverImage = "true";
  cover.style.backgroundImage = `linear-gradient(180deg, rgba(5, 8, 12, 0.5), rgba(5, 8, 12, 0.2) 42%, rgba(5, 8, 12, 0.7)), url("${imageUrl}")`;
  cover.style.backgroundSize = "cover";
  cover.style.backgroundPosition = "center";
  cover.style.backgroundColor = "#081018";

  const texture = cover.firstElementChild;
  if (texture instanceof HTMLElement) {
    texture.style.opacity = "0.16";
  }

  for (const textElement of cover.querySelectorAll<HTMLElement>("h2, p, span")) {
    textElement.style.textShadow = "0 2px 18px rgba(0, 0, 0, 0.62)";
  }
}

function applyCoverImages() {
  const cards = Array.from(document.querySelectorAll<HTMLElement>("article"));

  for (const card of cards) {
    const cardText = card.textContent ?? "";
    const coverEntry = Object.entries(COVER_IMAGES).find(([work]) => cardText.includes(work));

    if (!coverEntry) {
      continue;
    }

    const [work, imageUrl] = coverEntry;
    const cover = findCoverElement(card, work);

    if (!cover) {
      continue;
    }

    applyInlineCoverStyle(cover, imageUrl);
  }
}

export function FaliuCoverImageEnhancer() {
  useEffect(() => {
    applyCoverImages();

    const observer = new MutationObserver(() => applyCoverImages());
    observer.observe(document.body, { childList: true, subtree: true });

    return () => observer.disconnect();
  }, []);

  return null;
}
