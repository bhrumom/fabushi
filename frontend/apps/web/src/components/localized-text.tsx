import type { ReactNode } from "react";

interface LocalizedTextProps {
  zh: ReactNode;
  en: ReactNode;
  className?: string;
}

export function LocalizedText({ zh, en, className }: LocalizedTextProps) {
  return (
    <span className={["localized-text", className].filter(Boolean).join(" ")}>
      <span className="locale-zh">{zh}</span>
      <span className="locale-en">{en}</span>
    </span>
  );
}
