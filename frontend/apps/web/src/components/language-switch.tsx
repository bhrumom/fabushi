"use client";

import { useSiteLocale } from "./locale-provider";

export function LanguageSwitch() {
  const { locale, setLocale } = useSiteLocale();

  return (
    <div className="language-switch" aria-label="Language switch">
      <button
        type="button"
        className={locale === "zh" ? "language-button active" : "language-button"}
        onClick={() => setLocale("zh")}
      >
        中
      </button>
      <button
        type="button"
        className={locale === "en" ? "language-button active" : "language-button"}
        onClick={() => setLocale("en")}
      >
        EN
      </button>
    </div>
  );
}
