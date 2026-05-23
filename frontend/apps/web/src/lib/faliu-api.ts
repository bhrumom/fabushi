import { CBETA_API_ROOT, CBETA_PROXY_ROOT } from "./cbeta-config";

export interface CbetaWorkIndexItem {
  work: string;
  title: string;
  juans: string[];
}

export interface CbetaWorkInfo {
  work: string;
  category?: string;
  orig_category?: string;
  title: string;
  byline?: string;
  creators?: string;
  time_dynasty?: string;
  time_from?: number | null;
  time_to?: number | null;
  juan?: number;
  juan_start?: number;
  juan_end?: number;
}

export interface CbetaTocNode {
  title?: string;
  juan?: string | number;
  lb?: string;
  file?: string;
  type?: string;
  n?: string | number;
  isFolder?: boolean;
  children?: CbetaTocNode[];
}

export interface CbetaJuanDetail {
  work: string;
  juan: string;
  html: string;
  title: string;
  byline?: string;
  category?: string;
  toc: CbetaTocNode[];
  totalJuans: string[];
}

export interface ContentStats {
  likeCount: number;
  commentCount: number;
}

export interface AppComment {
  id: number;
  contentId: string;
  content: string;
  createdAt: string;
  parentId?: number | null;
  likeCount: number;
  username?: string | null;
  nickname?: string | null;
  avatar?: string | null;
  mainPractice?: string | null;
}

const APP_API_ROOT = "https://api.ombhrum.com/api";
const APP_PROXY_ROOT = "/api/app";
const SIMPLIFIED_TO_TRADITIONAL: Record<string, string> = {
  万: "萬",
  与: "與",
  丛: "叢",
  严: "嚴",
  义: "義",
  乐: "樂",
  书: "書",
  习: "習",
  乡: "鄉",
  乱: "亂",
  争: "爭",
  云: "雲",
  亚: "亞",
  产: "產",
  众: "眾",
  优: "優",
  会: "會",
  传: "傳",
  体: "體",
  余: "餘",
  侧: "側",
  侨: "僑",
  俨: "儼",
  债: "債",
  倾: "傾",
  偈: "偈",
  偿: "償",
  关: "關",
  兴: "興",
  养: "養",
  军: "軍",
  净: "淨",
  凉: "涼",
  几: "幾",
  击: "擊",
  刘: "劉",
  则: "則",
  刚: "剛",
  创: "創",
  别: "別",
  剑: "劍",
  剧: "劇",
  劝: "勸",
  办: "辦",
  务: "務",
  动: "動",
  势: "勢",
  华: "華",
  协: "協",
  単: "單",
  单: "單",
  卢: "盧",
  卫: "衛",
  却: "卻",
  历: "歷",
  厉: "厲",
  厌: "厭",
  县: "縣",
  参: "參",
  双: "雙",
  发: "發",
  变: "變",
  叠: "疊",
  叶: "葉",
  号: "號",
  后: "後",
  听: "聽",
  吴: "吳",
  启: "啟",
  员: "員",
  咒: "咒",
  咏: "詠",
  响: "響",
  唤: "喚",
  善: "善",
  园: "園",
  国: "國",
  图: "圖",
  圆: "圓",
  圣: "聖",
  场: "場",
  坚: "堅",
  坛: "壇",
  坏: "壞",
  坐: "坐",
  垢: "垢",
  垒: "壘",
  堕: "墮",
  增: "增",
  壮: "壯",
  声: "聲",
  处: "處",
  备: "備",
  复: "復",
  头: "頭",
  夹: "夾",
  夺: "奪",
  奋: "奮",
  妆: "妝",
  妙: "妙",
  始: "始",
  娄: "婁",
  婴: "嬰",
  学: "學",
  宁: "寧",
  宝: "寶",
  实: "實",
  审: "審",
  宽: "寬",
  寿: "壽",
  将: "將",
  对: "對",
  导: "導",
  尘: "塵",
  尽: "盡",
  层: "層",
  属: "屬",
  岁: "歲",
  岛: "島",
  岭: "嶺",
  峡: "峽",
  巅: "巔",
  师: "師",
  帐: "帳",
  带: "帶",
  帮: "幫",
  干: "乾",
  广: "廣",
  庄: "莊",
  庆: "慶",
  庐: "廬",
  库: "庫",
  应: "應",
  庙: "廟",
  开: "開",
  异: "異",
  弥: "彌",
  张: "張",
  强: "強",
  归: "歸",
  当: "當",
  录: "錄",
  形: "形",
  彦: "彥",
  往: "往",
  径: "徑",
  徕: "徠",
  德: "德",
  忆: "憶",
  忏: "懺",
  忧: "憂",
  念: "念",
  怀: "懷",
  态: "態",
  总: "總",
  恶: "惡",
  恼: "惱",
  悟: "悟",
  悦: "悅",
  惊: "驚",
  惧: "懼",
  惩: "懲",
  慈: "慈",
  慧: "慧",
  戏: "戲",
  户: "戶",
  执: "執",
  扩: "擴",
  扫: "掃",
  扬: "揚",
  护: "護",
  报: "報",
  担: "擔",
  拜: "拜",
  拥: "擁",
  择: "擇",
  挥: "揮",
  换: "換",
  损: "損",
  据: "據",
  授: "授",
  掌: "掌",
  探: "探",
  接: "接",
  摄: "攝",
  摇: "搖",
  摧: "摧",
  摩: "摩",
  撰: "撰",
  支: "支",
  改: "改",
  攻: "攻",
  放: "放",
  敛: "斂",
  数: "數",
  斋: "齋",
  断: "斷",
  旧: "舊",
  时: "時",
  显: "顯",
  晋: "晉",
  晓: "曉",
  智: "智",
  暂: "暫",
  暗: "暗",
  曲: "曲",
  曼: "曼",
  术: "術",
  机: "機",
  杂: "雜",
  权: "權",
  杀: "殺",
  来: "來",
  极: "極",
  构: "構",
  标: "標",
  树: "樹",
  栖: "棲",
  样: "樣",
  桥: "橋",
  梦: "夢",
  梵: "梵",
  检: "檢",
  楞: "楞",
  楼: "樓",
  欢: "歡",
  欧: "歐",
  欲: "欲",
  步: "步",
  歧: "歧",
  殊: "殊",
  残: "殘",
  毁: "毀",
  毕: "畢",
  气: "氣",
  汉: "漢",
  汤: "湯",
  沟: "溝",
  没: "沒",
  法: "法",
  泽: "澤",
  洁: "潔",
  洞: "洞",
  浅: "淺",
  浊: "濁",
  测: "測",
  济: "濟",
  浑: "渾",
  涅: "涅",
  涨: "漲",
  涩: "澀",
  渐: "漸",
  渊: "淵",
  温: "溫",
  湿: "濕",
  满: "滿",
  滞: "滯",
  灭: "滅",
  灯: "燈",
  灵: "靈",
  灾: "災",
  炉: "爐",
  点: "點",
  烦: "煩",
  烧: "燒",
  热: "熱",
  爱: "愛",
  牵: "牽",
  犹: "猶",
  独: "獨",
  献: "獻",
  现: "現",
  珠: "珠",
  琼: "瓊",
  瑜: "瑜",
  瑞: "瑞",
  瑶: "瑤",
  璎: "瓔",
  画: "畫",
  畅: "暢",
  疗: "療",
  痴: "癡",
  瘦: "瘦",
  皈: "皈",
  皱: "皺",
  监: "監",
  盖: "蓋",
  盘: "盤",
  目: "目",
  直: "直",
  相: "相",
  省: "省",
  眉: "眉",
  真: "真",
  着: "著",
  睹: "睹",
  知: "知",
  矫: "矯",
  研: "研",
  砺: "礪",
  碍: "礙",
  碎: "碎",
  礼: "禮",
  祈: "祈",
  祖: "祖",
  神: "神",
  禅: "禪",
  离: "離",
  种: "種",
  称: "稱",
  积: "積",
  稳: "穩",
  穷: "窮",
  窍: "竅",
  竞: "競",
  章: "章",
  童: "童",
  端: "端",
  笔: "筆",
  笃: "篤",
  筛: "篩",
  筑: "築",
  答: "答",
  签: "簽",
  简: "簡",
  算: "算",
  管: "管",
  类: "類",
  粮: "糧",
  精: "精",
  系: "系",
  纪: "紀",
  约: "約",
  红: "紅",
  级: "級",
  纯: "純",
  经: "經",
  绪: "緒",
  续: "續",
  缘: "緣",
  网: "網",
  罗: "羅",
  罚: "罰",
  羁: "羈",
  羅: "羅",
  翘: "翹",
  者: "者",
  联: "聯",
  肃: "肅",
  胜: "勝",
  胡: "胡",
  脑: "腦",
  脱: "脫",
  腊: "臘",
  舆: "輿",
  舍: "舍",
  舰: "艦",
  艺: "藝",
  节: "節",
  花: "花",
  苦: "苦",
  范: "範",
  荐: "薦",
  药: "藥",
  莲: "蓮",
  获: "獲",
  菩: "菩",
  萨: "薩",
  著: "著",
  藏: "藏",
  虚: "虛",
  虫: "蟲",
  蛇: "蛇",
  蛮: "蠻",
  蜜: "蜜",
  行: "行",
  补: "補",
  表: "表",
  观: "觀",
  规: "規",
  觉: "覺",
  览: "覽",
  见: "見",
  视: "視",
  触: "觸",
  言: "言",
  计: "計",
  订: "訂",
  记: "記",
  讫: "訖",
  讲: "講",
  讽: "諷",
  设: "設",
  证: "證",
  评: "評",
  识: "識",
  译: "譯",
  诵: "誦",
  诚: "誠",
  话: "話",
  说: "說",
  请: "請",
  诸: "諸",
  读: "讀",
  课: "課",
  调: "調",
  论: "論",
  谛: "諦",
  谷: "谷",
  象: "象",
  贤: "賢",
  败: "敗",
  贡: "貢",
  财: "財",
  责: "責",
  质: "質",
  赞: "讚",
  赠: "贈",
  赵: "趙",
  赶: "趕",
  践: "踐",
  踪: "蹤",
  身: "身",
  车: "車",
  轨: "軌",
  转: "轉",
  轮: "輪",
  轻: "輕",
  载: "載",
  辉: "輝",
  辑: "輯",
  输: "輸",
  边: "邊",
  达: "達",
  过: "過",
  运: "運",
  还: "還",
  进: "進",
  远: "遠",
  连: "連",
  适: "適",
  选: "選",
  遗: "遺",
  道: "道",
  遥: "遙",
  邓: "鄧",
  邻: "鄰",
  释: "釋",
  里: "裡",
  钟: "鐘",
  钵: "缽",
  银: "銀",
  锁: "鎖",
  错: "錯",
  锦: "錦",
  长: "長",
  门: "門",
  闭: "閉",
  问: "問",
  闻: "聞",
  阅: "閱",
  阴: "陰",
  阶: "階",
  际: "際",
  随: "隨",
  隐: "隱",
  难: "難",
  雾: "霧",
  霁: "霽",
  霊: "靈",
  霜: "霜",
  静: "靜",
  面: "面",
  须: "須",
  顿: "頓",
  颂: "頌",
  领: "領",
  频: "頻",
  题: "題",
  颜: "顏",
  风: "風",
  飞: "飛",
  饭: "飯",
  馆: "館",
  马: "馬",
  驮: "馱",
  驱: "驅",
  验: "驗",
  高: "高",
  魏: "魏",
  鲁: "魯",
  鲜: "鮮",
  鸠: "鳩",
  鸣: "鳴",
  鹅: "鵝",
  鹏: "鵬",
  麦: "麥",
  黄: "黃",
  黎: "黎",
  龙: "龍",
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

export function normalizeCbetaQuery(value: string) {
  return value
    .split("")
    .map((character) => SIMPLIFIED_TO_TRADITIONAL[character] ?? character)
    .join("")
    .trim();
}

function stripUnsafeCbetaHtml(rawHtml: string) {
  const bodyMatch = rawHtml.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
  const bodyHtml = bodyMatch?.[1] ?? rawHtml;

  return bodyHtml
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/<iframe[\s\S]*?<\/iframe>/gi, "")
    .replace(/<object[\s\S]*?<\/object>/gi, "")
    .replace(/<embed[\s\S]*?>/gi, "")
    .replace(/\son\w+=(?:"[^"]*"|'[^']*'|[^\s>]+)/gi, "")
    .replace(/\s(href|src)=["']javascript:[^"']*["']/gi, ' $1="#"');
}

function isBrowserRuntime() {
  return typeof window !== "undefined";
}

function cbetaUrls(path: string, params?: Record<string, string | number | undefined>) {
  const directUrl = buildUrl(CBETA_API_ROOT, path, params);

  if (!isBrowserRuntime()) {
    return [directUrl];
  }

  return [buildRelativeUrl(CBETA_PROXY_ROOT, path, params), directUrl];
}

function appUrls(path: string, params?: Record<string, string | number | undefined>) {
  const directUrl = buildUrl(APP_API_ROOT, path, params);

  if (!isBrowserRuntime()) {
    return [directUrl];
  }

  return [buildRelativeUrl(APP_PROXY_ROOT, path, params), directUrl];
}

async function fetchJson<T>(urls: string | string[]): Promise<T> {
  const candidates = Array.isArray(urls) ? urls : [urls];
  let lastError: unknown = null;

  for (const url of candidates) {
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

async function postJson<T>(urls: string | string[], body: unknown): Promise<T> {
  const candidates = Array.isArray(urls) ? urls : [urls];
  let lastError: unknown = null;

  for (const url of candidates) {
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify(body),
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

export function buildCbetaContentId(work: string, juan: string) {
  return `cbeta:${work}:${juan}`;
}

export async function fetchAllWorks(): Promise<CbetaWorkIndexItem[]> {
  return fetchJson<CbetaWorkIndexItem[]>(cbetaUrls("download/all-works.json"));
}

export async function searchWorksByTitle(query: string, start = 0, rows = 24): Promise<CbetaWorkInfo[]> {
  const terms = Array.from(new Set([query.trim(), normalizeCbetaQuery(query)].filter(Boolean)));
  const responses = await Promise.all(
    terms.map((term) =>
      fetchJson<{
        results?: Array<{
          work?: string;
          content?: string;
          byline?: string;
          juan?: number;
          time_dynasty?: string;
        }>;
      }>(cbetaUrls("search/title", { q: term, start, rows })),
    ),
  );
  const seen = new Set<string>();

  return responses.flatMap((data) =>
    (data.results ?? []).flatMap((item) => {
      if (!item.work || !item.content) {
        return [];
      }

      const key = `${item.work}:${item.juan ?? 1}`;

      if (seen.has(key)) {
        return [];
      }

      seen.add(key);

      return [
        {
          work: item.work,
          title: item.content,
          byline: item.byline,
          juan: item.juan,
          time_dynasty: item.time_dynasty,
        },
      ];
    }),
  );
}

export async function fetchWorkInfo(work: string): Promise<CbetaWorkInfo | null> {
  const data = await fetchJson<{ results?: CbetaWorkInfo[] }>(cbetaUrls("works", { work }));
  return data.results?.[0] ?? null;
}

export async function fetchJuanDetail(work: string, juan: string): Promise<CbetaJuanDetail | null> {
  const data = await fetchJson<{
    results?: Array<string | { html?: string; juan?: string | number }>;
    work_info?: CbetaWorkInfo;
    toc?: { mulu?: CbetaTocNode[]; juan?: CbetaTocNode[] };
  }>(cbetaUrls("juans", { work, juan, work_info: 1, toc: 1 }));

  const firstResult = data.results?.[0];
  const html = typeof firstResult === "string" ? firstResult : firstResult?.html;
  const workInfo = data.work_info;

  if (!html || !workInfo) {
    return null;
  }

  return {
    work,
    juan,
    html: stripUnsafeCbetaHtml(html),
    title: workInfo.title,
    byline: workInfo.byline,
    category: workInfo.category,
    toc: [...(data.toc?.juan ?? []), ...(data.toc?.mulu ?? [])],
    totalJuans: [],
  };
}

export async function fetchBatchStats(contentIds: string[]): Promise<Record<string, ContentStats>> {
  if (contentIds.length === 0) {
    return {};
  }

  const data = await postJson<{
    stats?: Record<string, { likeCount?: number; commentCount?: number }>;
  }>(appUrls("content/batch-stats"), { contentIds });

  const entries = Object.entries(data.stats ?? {});
  const mapped: Record<string, ContentStats> = {};

  for (const [contentId, value] of entries) {
    mapped[contentId] = {
      likeCount: value.likeCount ?? 0,
      commentCount: value.commentCount ?? 0,
    };
  }

  return mapped;
}

export async function fetchComments(contentId: string): Promise<AppComment[]> {
  const data = await fetchJson<{
    comments?: Array<{
      id: number;
      content_id?: string;
      video_id?: string;
      content?: string;
      created_at?: string;
      parent_id?: number | null;
      like_count?: number;
      username?: string | null;
      nickname?: string | null;
      avatar?: string | null;
      main_practice?: string | null;
    }>;
  }>(appUrls("comments", { contentId, page: 1, pageSize: 30 }));

  return (data.comments ?? []).map((item) => ({
    id: item.id,
    contentId: item.content_id ?? item.video_id ?? contentId,
    content: item.content ?? "",
    createdAt: item.created_at ?? "",
    parentId: item.parent_id,
    likeCount: item.like_count ?? 0,
    username: item.username,
    nickname: item.nickname,
    avatar: item.avatar,
    mainPractice: item.main_practice,
  }));
}
