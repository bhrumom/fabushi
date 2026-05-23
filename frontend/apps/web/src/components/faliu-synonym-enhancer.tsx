"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { CBETA_API_ROOT, CBETA_PROXY_ROOT } from "../lib/cbeta-config";
import { normalizeCbetaQuery } from "../lib/faliu-api";

const MAX_SUGGESTIONS_PER_GROUP = 8;
const MIN_QUERY_LENGTH = 2;

const TRADITIONAL_TO_SIMPLIFIED: Record<string, string> = {
  萬: "万",
  與: "与",
  叢: "丛",
  嚴: "严",
  義: "义",
  樂: "乐",
  書: "书",
  習: "习",
  鄉: "乡",
  亂: "乱",
  爭: "争",
  雲: "云",
  亞: "亚",
  產: "产",
  眾: "众",
  優: "优",
  會: "会",
  傳: "传",
  體: "体",
  餘: "余",
  側: "侧",
  僑: "侨",
  儼: "俨",
  債: "债",
  傾: "倾",
  償: "偿",
  關: "关",
  興: "兴",
  養: "养",
  軍: "军",
  淨: "净",
  涼: "凉",
  幾: "几",
  擊: "击",
  劉: "刘",
  則: "则",
  剛: "刚",
  創: "创",
  別: "别",
  劍: "剑",
  劇: "剧",
  勸: "劝",
  辦: "办",
  務: "务",
  動: "动",
  勢: "势",
  華: "华",
  協: "协",
  單: "单",
  盧: "卢",
  衛: "卫",
  卻: "却",
  歷: "历",
  厲: "厉",
  厭: "厌",
  縣: "县",
  參: "参",
  雙: "双",
  發: "发",
  變: "变",
  疊: "叠",
  葉: "叶",
  號: "号",
  後: "后",
  聽: "听",
  吳: "吴",
  啟: "启",
  員: "员",
  詠: "咏",
  響: "响",
  喚: "唤",
  園: "园",
  國: "国",
  圖: "图",
  圓: "圆",
  聖: "圣",
  場: "场",
  堅: "坚",
  壇: "坛",
  壞: "坏",
  壘: "垒",
  墮: "堕",
  壯: "壮",
  聲: "声",
  處: "处",
  備: "备",
  復: "复",
  頭: "头",
  夾: "夹",
  奪: "夺",
  奮: "奋",
  妝: "妆",
  婁: "娄",
  嬰: "婴",
  學: "学",
  寧: "宁",
  寶: "宝",
  實: "实",
  審: "审",
  寬: "宽",
  壽: "寿",
  將: "将",
  對: "对",
  導: "导",
  塵: "尘",
  盡: "尽",
  層: "层",
  屬: "属",
  歲: "岁",
  島: "岛",
  嶺: "岭",
  峽: "峡",
  巔: "巅",
  師: "师",
  帳: "帐",
  帶: "带",
  幫: "帮",
  廣: "广",
  莊: "庄",
  慶: "庆",
  廬: "庐",
  庫: "库",
  應: "应",
  廟: "庙",
  開: "开",
  異: "异",
  彌: "弥",
  張: "张",
  強: "强",
  歸: "归",
  當: "当",
  錄: "录",
  徑: "径",
  徠: "徕",
  憶: "忆",
  懺: "忏",
  憂: "忧",
  懷: "怀",
  態: "态",
  總: "总",
  惡: "恶",
  惱: "恼",
  驚: "惊",
  懼: "惧",
  懲: "惩",
  戲: "戏",
  戶: "户",
  執: "执",
  擴: "扩",
  掃: "扫",
  揚: "扬",
  護: "护",
  報: "报",
  擔: "担",
  擁: "拥",
  擇: "择",
  揮: "挥",
  換: "换",
  損: "损",
  據: "据",
  攝: "摄",
  搖: "摇",
  斂: "敛",
  數: "数",
  齋: "斋",
  斷: "断",
  舊: "旧",
  時: "时",
  顯: "显",
  晉: "晋",
  曉: "晓",
  暫: "暂",
  術: "术",
  機: "机",
  雜: "杂",
  權: "权",
  殺: "杀",
  來: "来",
  極: "极",
  構: "构",
  標: "标",
  樹: "树",
  棲: "栖",
  樣: "样",
  橋: "桥",
  夢: "梦",
  檢: "检",
  樓: "楼",
  歡: "欢",
  歐: "欧",
  淺: "浅",
  濁: "浊",
  測: "测",
  濟: "济",
  渾: "浑",
  澀: "涩",
  漸: "渐",
  淵: "渊",
  溫: "温",
  濕: "湿",
  滿: "满",
  滯: "滞",
  滅: "灭",
  燈: "灯",
  靈: "灵",
  災: "灾",
  爐: "炉",
  點: "点",
  煩: "烦",
  燒: "烧",
  熱: "热",
  愛: "爱",
  牽: "牵",
  猶: "犹",
  獨: "独",
  獻: "献",
  現: "现",
  瓊: "琼",
  瑤: "瑶",
  瓔: "璎",
  畫: "画",
  暢: "畅",
  療: "疗",
  癡: "痴",
  皺: "皱",
  監: "监",
  蓋: "盖",
  盤: "盘",
  礙: "碍",
  禮: "礼",
  禪: "禅",
  離: "离",
  種: "种",
  稱: "称",
  積: "积",
  穩: "稳",
  窮: "穷",
  竅: "窍",
  競: "竞",
  筆: "笔",
  篤: "笃",
  篩: "筛",
  築: "筑",
  簽: "签",
  簡: "简",
  類: "类",
  糧: "粮",
  紀: "纪",
  約: "约",
  紅: "红",
  級: "级",
  純: "纯",
  經: "经",
  緒: "绪",
  續: "续",
  緣: "缘",
  網: "网",
  羅: "罗",
  罰: "罚",
  羈: "羁",
  翹: "翘",
  聯: "联",
  肅: "肃",
  勝: "胜",
  腦: "脑",
  脫: "脱",
  臘: "腊",
  輿: "舆",
  艦: "舰",
  藝: "艺",
  節: "节",
  範: "范",
  薦: "荐",
  藥: "药",
  蓮: "莲",
  獲: "获",
  薩: "萨",
  虛: "虚",
  蟲: "虫",
  蠻: "蛮",
  補: "补",
  觀: "观",
  規: "规",
  覺: "觉",
  覽: "览",
  見: "见",
  視: "视",
  觸: "触",
  計: "计",
  訂: "订",
  記: "记",
  訖: "讫",
  講: "讲",
  諷: "讽",
  設: "设",
  證: "证",
  評: "评",
  識: "识",
  譯: "译",
  誦: "诵",
  誠: "诚",
  話: "话",
  說: "说",
  請: "请",
  諸: "诸",
  讀: "读",
  課: "课",
  調: "调",
  論: "论",
  諦: "谛",
  賢: "贤",
  敗: "败",
  貢: "贡",
  財: "财",
  責: "责",
  質: "质",
  讚: "赞",
  贈: "赠",
  趙: "赵",
  趕: "赶",
  踐: "践",
  蹤: "踪",
  車: "车",
  軌: "轨",
  轉: "转",
  輪: "轮",
  輕: "轻",
  載: "载",
  輝: "辉",
  輯: "辑",
  輸: "输",
  邊: "边",
  達: "达",
  過: "过",
  運: "运",
  還: "还",
  進: "进",
  遠: "远",
  連: "连",
  適: "适",
  選: "选",
  遺: "遗",
  遙: "遥",
  鄧: "邓",
  鄰: "邻",
  釋: "释",
  裡: "里",
  鐘: "钟",
  缽: "钵",
  銀: "银",
  鎖: "锁",
  錯: "错",
  錦: "锦",
  長: "长",
  門: "门",
  閉: "闭",
  問: "问",
  聞: "闻",
  閱: "阅",
  陰: "阴",
  階: "阶",
  際: "际",
  隨: "随",
  隱: "隐",
  難: "难",
  霧: "雾",
  霽: "霁",
  靜: "静",
  須: "须",
  頓: "顿",
  頌: "颂",
  領: "领",
  頻: "频",
  題: "题",
  顏: "颜",
  風: "风",
  飛: "飞",
  飯: "饭",
  館: "馆",
  馬: "马",
  馱: "驮",
  驅: "驱",
  驗: "验",
  魯: "鲁",
  鮮: "鲜",
  鳩: "鸠",
  鳴: "鸣",
  鵝: "鹅",
  鵬: "鹏",
  麥: "麦",
  黃: "黄",
  龍: "龙",
  無: "无",
  頂: "顶",
};

type CbetaSynonymResponse = {
  results?: string[];
};

type CbetaVariantResponse = {
  results?: Array<{
    q?: string;
    hits?: number;
  }>;
};

type VariantSuggestion = {
  value: string;
  hits: number;
};

function buildUrl(base: string, path: string, params?: Record<string, string | number | undefined>) {
  const url = new URL(path, `${base}/`);

  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value === undefined || value === null || value === "") {
        continue;
      }

      url.searchParams.set(key, String(value));
    }
  }

  return url.toString();
}

function buildRelativeUrl(base: string, path: string, params?: Record<string, string | number | undefined>) {
  const normalizedBase = base.replace(/\/+$/g, "");
  const normalizedPath = path.replace(/^\/+/g, "");
  const query = new URLSearchParams();

  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value === undefined || value === null || value === "") {
        continue;
      }

      query.set(key, String(value));
    }
  }

  const suffix = query.toString();
  return `${normalizedBase}/${normalizedPath}${suffix ? `?${suffix}` : ""}`;
}

function cbetaUrls(path: string, params: Record<string, string | number | undefined>) {
  return [buildRelativeUrl(CBETA_PROXY_ROOT, path, params), buildUrl(CBETA_API_ROOT, path, params)];
}

async function fetchJson<T>(urls: string[]): Promise<T> {
  let lastError: unknown = null;

  for (const url of urls) {
    try {
      const response = await fetch(url, {
        headers: {
          Accept: "application/json",
        },
      });

      if (!response.ok) {
        lastError = new Error(`Request failed: ${response.status}`);
        continue;
      }

      return (await response.json()) as T;
    } catch (cause) {
      lastError = cause;
    }
  }

  if (lastError instanceof Error) {
    throw lastError;
  }

  throw new Error("Request failed");
}

function getQueryTerms(query: string) {
  return Array.from(new Set([query.trim(), normalizeCbetaQuery(query)].filter(Boolean)));
}

function getBlockedTerms(terms: string[]) {
  return new Set(terms.map((term) => normalizeCbetaQuery(term).toLowerCase()));
}

function simplifyCbetaQuery(value: string) {
  return value
    .split("")
    .map((character) => TRADITIONAL_TO_SIMPLIFIED[character] ?? character)
    .join("")
    .trim();
}

function collectSimplifiedSuggestions(query: string, variants: VariantSuggestion[], synonyms: string[]) {
  const sourceValues = [query, ...variants.map((item) => item.value), ...synonyms].map((item) => item.trim()).filter(Boolean);
  const blockedValues = new Set(sourceValues);
  const seen = new Set<string>();
  const suggestions: string[] = [];

  for (const value of sourceValues) {
    const simplified = simplifyCbetaQuery(value);

    if (
      !simplified ||
      simplified.length < MIN_QUERY_LENGTH ||
      simplified === value ||
      blockedValues.has(simplified) ||
      seen.has(simplified)
    ) {
      continue;
    }

    seen.add(simplified);
    suggestions.push(simplified);

    if (suggestions.length >= MAX_SUGGESTIONS_PER_GROUP) {
      return suggestions;
    }
  }

  return suggestions;
}

async function fetchCbetaSynonyms(query: string) {
  const terms = getQueryTerms(query);
  const blockedTerms = getBlockedTerms(terms);
  const responses = await Promise.allSettled(
    terms.map((term) => fetchJson<CbetaSynonymResponse>(cbetaUrls("search/synonym", { q: term }))),
  );
  const seen = new Set<string>();
  const suggestions: string[] = [];

  for (const response of responses) {
    if (response.status !== "fulfilled") {
      continue;
    }

    for (const item of response.value.results ?? []) {
      const synonym = item.trim();
      const normalized = normalizeCbetaQuery(synonym).toLowerCase();

      if (!synonym || blockedTerms.has(normalized) || seen.has(normalized)) {
        continue;
      }

      seen.add(normalized);
      suggestions.push(synonym);

      if (suggestions.length >= MAX_SUGGESTIONS_PER_GROUP) {
        return suggestions;
      }
    }
  }

  return suggestions;
}

async function fetchCbetaVariants(query: string) {
  const terms = getQueryTerms(query);
  const blockedTerms = getBlockedTerms(terms);
  const responses = await Promise.allSettled(
    terms.map((term) => fetchJson<CbetaVariantResponse>(cbetaUrls("search/variants", { q: term, scope: "title" }))),
  );
  const seen = new Set<string>();
  const suggestions: VariantSuggestion[] = [];

  for (const response of responses) {
    if (response.status !== "fulfilled") {
      continue;
    }

    for (const item of response.value.results ?? []) {
      const variant = item.q?.trim() ?? "";
      const normalized = normalizeCbetaQuery(variant).toLowerCase();

      if (!variant || blockedTerms.has(normalized) || seen.has(normalized)) {
        continue;
      }

      seen.add(normalized);
      suggestions.push({ value: variant, hits: item.hits ?? 0 });

      if (suggestions.length >= MAX_SUGGESTIONS_PER_GROUP) {
        return suggestions;
      }
    }
  }

  return suggestions.sort((left, right) => right.hits - left.hits);
}

function setNativeInputValue(input: HTMLInputElement, value: string) {
  const descriptor = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value");

  if (descriptor?.set) {
    descriptor.set.call(input, value);
  } else {
    input.value = value;
  }
}

export function FaliuSynonymEnhancer() {
  const [host, setHost] = useState<HTMLFormElement | null>(null);
  const [input, setInput] = useState<HTMLInputElement | null>(null);
  const [query, setQuery] = useState("");
  const [simplifiedSuggestions, setSimplifiedSuggestions] = useState<string[]>([]);
  const [synonymSuggestions, setSynonymSuggestions] = useState<string[]>([]);
  const [variantSuggestions, setVariantSuggestions] = useState<VariantSuggestion[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    const formElement = document.querySelector<HTMLFormElement>('section[aria-label="法流"] form');
    const inputElement = formElement?.querySelector<HTMLInputElement>('input[aria-label="搜索佛典"]');

    if (!formElement || !inputElement) {
      return;
    }

    if (!formElement.style.position) {
      formElement.style.position = "relative";
    }

    const handleInput = () => {
      setQuery(inputElement.value.trim());
    };

    setHost(formElement);
    setInput(inputElement);
    handleInput();
    inputElement.addEventListener("input", handleInput);

    return () => {
      inputElement.removeEventListener("input", handleInput);
    };
  }, []);

  useEffect(() => {
    const nextQuery = query.trim();

    if (nextQuery.length < MIN_QUERY_LENGTH) {
      setSimplifiedSuggestions([]);
      setSynonymSuggestions([]);
      setVariantSuggestions([]);
      setIsLoading(false);
      return;
    }

    let cancelled = false;
    const timeout = window.setTimeout(() => {
      setIsLoading(true);
      Promise.all([fetchCbetaVariants(nextQuery), fetchCbetaSynonyms(nextQuery)])
        .then(([variants, synonyms]) => {
          if (!cancelled) {
            setVariantSuggestions(variants);
            setSynonymSuggestions(synonyms);
            setSimplifiedSuggestions(collectSimplifiedSuggestions(nextQuery, variants, synonyms));
          }
        })
        .catch(() => {
          if (!cancelled) {
            setSimplifiedSuggestions([]);
            setVariantSuggestions([]);
            setSynonymSuggestions([]);
          }
        })
        .finally(() => {
          if (!cancelled) {
            setIsLoading(false);
          }
        });
    }, 260);

    return () => {
      cancelled = true;
      window.clearTimeout(timeout);
    };
  }, [query]);

  function searchWithSuggestion(value: string) {
    if (!input || !host) {
      return;
    }

    setSimplifiedSuggestions([]);
    setSynonymSuggestions([]);
    setVariantSuggestions([]);
    setQuery(value);
    setNativeInputValue(input, value);
    input.dispatchEvent(new Event("input", { bubbles: true }));
    input.dispatchEvent(new Event("change", { bubbles: true }));

    window.setTimeout(() => {
      if (typeof host.requestSubmit === "function") {
        host.requestSubmit();
      } else {
        host.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
      }
    }, 0);
  }

  const hasSuggestions =
    simplifiedSuggestions.length > 0 || synonymSuggestions.length > 0 || variantSuggestions.length > 0;

  if (!host || (!isLoading && !hasSuggestions)) {
    return null;
  }

  return createPortal(
    <div
      role="listbox"
      aria-label="CBETA 搜索建议"
      style={{
        position: "absolute",
        top: "calc(100% + 8px)",
        left: 0,
        right: 0,
        zIndex: 30,
        display: "grid",
        gap: 12,
        padding: "12px 14px",
        border: "1px solid rgba(255, 255, 255, 0.14)",
        borderRadius: 14,
        background: "rgba(8, 16, 24, 0.96)",
        boxShadow: "0 18px 46px rgba(0, 0, 0, 0.36)",
        backdropFilter: "blur(14px)",
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          gap: 12,
          color: "rgba(255, 255, 255, 0.64)",
          fontSize: "0.82rem",
          lineHeight: 1.4,
        }}
      >
        <span>CBETA 搜索建议</span>
        <span>{isLoading ? "正在查找..." : "点击后自动搜索"}</span>
      </div>

      {simplifiedSuggestions.length > 0 ? (
        <section style={{ display: "grid", gap: 8 }}>
          <strong style={{ color: "rgba(255, 255, 255, 0.78)", fontSize: "0.86rem" }}>简体字建议</strong>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
            {simplifiedSuggestions.map((item) => (
              <button
                key={item}
                type="button"
                role="option"
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => searchWithSuggestion(item)}
                style={{
                  minHeight: 34,
                  padding: "0 12px",
                  border: "1px solid rgba(255, 255, 255, 0.24)",
                  borderRadius: 999,
                  background: "rgba(255, 255, 255, 0.11)",
                  color: "#ffffff",
                  fontWeight: 760,
                  cursor: "pointer",
                }}
              >
                {item}
              </button>
            ))}
          </div>
        </section>
      ) : null}

      {variantSuggestions.length > 0 ? (
        <section style={{ display: "grid", gap: 8 }}>
          <strong style={{ color: "rgba(255, 255, 255, 0.78)", fontSize: "0.86rem" }}>异体字建议</strong>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
            {variantSuggestions.map((item) => (
              <button
                key={item.value}
                type="button"
                role="option"
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => searchWithSuggestion(item.value)}
                style={{
                  minHeight: 34,
                  padding: "0 12px",
                  border: "1px solid rgba(25, 228, 220, 0.28)",
                  borderRadius: 999,
                  background: "rgba(25, 228, 220, 0.12)",
                  color: "#e3fffd",
                  fontWeight: 760,
                  cursor: "pointer",
                }}
              >
                {item.value}
                {item.hits > 0 ? ` · ${item.hits}` : ""}
              </button>
            ))}
          </div>
        </section>
      ) : null}

      {synonymSuggestions.length > 0 ? (
        <section style={{ display: "grid", gap: 8 }}>
          <strong style={{ color: "rgba(255, 255, 255, 0.78)", fontSize: "0.86rem" }}>近义词建议</strong>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
            {synonymSuggestions.map((item) => (
              <button
                key={item}
                type="button"
                role="option"
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => searchWithSuggestion(item)}
                style={{
                  minHeight: 34,
                  padding: "0 12px",
                  border: "1px solid rgba(232, 189, 107, 0.28)",
                  borderRadius: 999,
                  background: "rgba(232, 189, 107, 0.12)",
                  color: "#fff7e3",
                  fontWeight: 760,
                  cursor: "pointer",
                }}
              >
                {item}
              </button>
            ))}
          </div>
        </section>
      ) : null}
    </div>,
    host,
  );
}
