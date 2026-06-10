export type DachengToolId = "global-dharma" | "flashcards";

export const dachengToolEntries = [
  {
    id: "global-dharma",
    title: "全球法布施",
    shortTitle: "法布施",
    description: "使用 HTTP 全球公共端点发送整理后的善法文字。",
    action: "开始全球发送",
  },
  {
    id: "flashcards",
    title: "背诵闪卡",
    shortTitle: "闪卡",
    description: "参考 RemNote 的挖空卡、双向卡和间隔复习，直接从对话内容制卡。",
    action: "制作闪卡",
  },
] as const satisfies readonly {
  id: DachengToolId;
  title: string;
  shortTitle: string;
  description: string;
  action: string;
}[];

export const dachengQuickPrompts = [
  "帮我整理一段适合全球法布施的善法文字",
  "把这段经文拆成适合背诵的闪卡",
  "请用庄重、简洁的方式解释这段佛法内容",
  "根据今天的状态安排一个 20 分钟修行计划",
] as const;

export const globalDharmaPublicEndpoints = [
  {
    id: "httpbin",
    label: "HTTPBin 公共端点",
    url: "https://httpbin.org/post",
    expectedStatus: 200,
  },
  {
    id: "jsonplaceholder",
    label: "JSONPlaceholder 公共端点",
    url: "https://jsonplaceholder.typicode.com/posts",
    expectedStatus: 201,
  },
] as const;

export const globalDharmaRegions = [
  "中国",
  "新加坡",
  "日本",
  "印度",
  "澳大利亚",
  "德国",
  "法国",
  "英国",
  "美国",
  "加拿大",
  "巴西",
  "南非",
] as const;

export const remnoteInspiredFlashcardPrinciples = [
  "一个卡片只考一个最小记忆点。",
  "优先做挖空卡，再补充正反向问答卡。",
  "按 Again、Hard、Good、Easy 四档安排下次复习。",
  "保留上下文，避免只背孤立词句。",
] as const;
