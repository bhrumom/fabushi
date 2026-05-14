"use client";

import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

export type SiteLocale = "zh" | "en";

interface LocaleContextValue {
  locale: SiteLocale;
  setLocale: (nextLocale: SiteLocale) => void;
}

const STORAGE_KEY = "fabushi-site-locale";
const DEFAULT_LOCALE: SiteLocale = "zh";
const ZH_COUNTRY_CODES = new Set(["CN", "HK", "MO", "TW"]);

const LocaleContext = createContext<LocaleContextValue>({
  locale: DEFAULT_LOCALE,
  setLocale: () => {},
});

function applyLocale(locale: SiteLocale) {
  document.documentElement.lang = locale === "zh" ? "zh-CN" : "en";
  document.documentElement.dataset.siteLocale = locale;
}

function normalizeLocale(value: string | null | undefined): SiteLocale | null {
  if (value === "zh" || value === "en") {
    return value;
  }

  return null;
}

function resolveLocaleFromLanguage(language: string | null | undefined): SiteLocale {
  return language?.toLowerCase().startsWith("zh") ? "zh" : "en";
}

async function detectLocaleByIp(): Promise<SiteLocale | null> {
  const controller = new AbortController();
  const timeoutId = window.setTimeout(() => controller.abort(), 1800);

  try {
    const response = await fetch("/cdn-cgi/trace", {
      cache: "no-store",
      signal: controller.signal,
    });

    if (!response.ok) {
      return null;
    }

    const trace = await response.text();
    const countryCode = trace
      .split("\n")
      .find((line) => line.startsWith("loc="))
      ?.slice("loc=".length)
      .trim()
      .toUpperCase();

    if (!countryCode) {
      return null;
    }

    return ZH_COUNTRY_CODES.has(countryCode) ? "zh" : "en";
  } catch {
    return null;
  } finally {
    window.clearTimeout(timeoutId);
  }
}

export function LocaleProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<SiteLocale>(DEFAULT_LOCALE);

  useEffect(() => {
    let active = true;

    const storedLocale = normalizeLocale(window.localStorage.getItem(STORAGE_KEY));
    if (storedLocale) {
      setLocaleState(storedLocale);
      applyLocale(storedLocale);
      return;
    }

    const browserLocale = resolveLocaleFromLanguage(window.navigator.language);
    setLocaleState(browserLocale);
    applyLocale(browserLocale);

    detectLocaleByIp().then((detectedLocale) => {
      if (!active || !detectedLocale) {
        return;
      }

      setLocaleState(detectedLocale);
      applyLocale(detectedLocale);
    });

    return () => {
      active = false;
    };
  }, []);

  const setLocale = (nextLocale: SiteLocale) => {
    setLocaleState(nextLocale);
    applyLocale(nextLocale);
    window.localStorage.setItem(STORAGE_KEY, nextLocale);
  };

  const value = useMemo(
    () => ({ locale, setLocale }),
    [locale],
  );

  return <LocaleContext.Provider value={value}>{children}</LocaleContext.Provider>;
}

export function useSiteLocale() {
  return useContext(LocaleContext);
}
