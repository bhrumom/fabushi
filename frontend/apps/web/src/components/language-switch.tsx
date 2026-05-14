"use client";

import { useEffect, useRef, useState } from "react";
import { useSiteLocale } from "./locale-provider";

export function LanguageSwitch() {
  const { locale, setLocale } = useSiteLocale();
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    function handlePointerDown(event: MouseEvent) {
      if (!rootRef.current?.contains(event.target as Node)) {
        setOpen(false);
      }
    }

    function handleEscape(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setOpen(false);
      }
    }

    document.addEventListener("mousedown", handlePointerDown);
    document.addEventListener("keydown", handleEscape);
    return () => {
      document.removeEventListener("mousedown", handlePointerDown);
      document.removeEventListener("keydown", handleEscape);
    };
  }, []);

  function selectLocale(nextLocale: "zh" | "en") {
    setLocale(nextLocale);
    setOpen(false);
  }

  return (
    <div ref={rootRef} className="language-switch" aria-label="Language switch">
      <button
        type="button"
        className="language-toggle"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={locale === "zh" ? "切换语言" : "Change language"}
        onClick={() => setOpen((current) => !current)}
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path
            d="M12 3h9M16.5 3c0 7-3.5 12-8.5 15M13 8H6m0 0h5m-5 0c0 3.5 1.8 6.7 4.8 8.9M5 21l4.2-10.5L13.4 21"
            fill="none"
            stroke="currentColor"
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="1.7"
          />
        </svg>
      </button>
      {open ? (
        <div className="language-menu" role="menu">
          <button
            type="button"
            role="menuitemradio"
            aria-checked={locale === "zh"}
            className={locale === "zh" ? "language-option active" : "language-option"}
            onClick={() => selectLocale("zh")}
          >
            简体中文
          </button>
          <button
            type="button"
            role="menuitemradio"
            aria-checked={locale === "en"}
            className={locale === "en" ? "language-option active" : "language-option"}
            onClick={() => selectLocale("en")}
          >
            English
          </button>
        </div>
      ) : null}
    </div>
  );
}
