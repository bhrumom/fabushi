export const appExperienceStats = [
  { label: "今日共修", value: "12,086", unit: "人次" },
  { label: "法布施发送", value: "8.42", unit: "TB" },
  { label: "在线国家", value: "64", unit: "个" },
  { label: "经文素材", value: "1,248", unit: "份" },
] as const;

export const appModules = [
  {
    id: "global-dharma",
    title: "全球法布施",
    shortTitle: "法布施",
    summary: "选择经文、音频、图片或发愿文，一键发送到全球 HTTP 公共端点。",
    action: "开始发送",
    tone: "cyan",
    screenshot: "/product/global-dharma.png",
  },
  {
    id: "flashcards",
    title: "背诵闪卡",
    shortTitle: "闪卡",
    summary: "参考 RemNote 的挖空卡、双向卡和间隔复习，把经文内容变成可背诵知识点。",
    action: "开始背诵",
    tone: "blue",
    screenshot: "/product/main-sutra.png",
  },
  {
    id: "sutra",
    title: "经文听诵",
    shortTitle: "经文",
    summary: "读经、听诵、拼音辅助和功德利益说明集中在一个阅读面板。",
    action: "进入经藏",
    tone: "gold",
    screenshot: "/product/main-sutra.png",
  },
  {
    id: "meditation",
    title: "禅室修行",
    shortTitle: "禅室",
    summary: "香、灯、经书和计时器组合成可持续的每日修行空间。",
    action: "开始禅修",
    tone: "green",
    screenshot: "/product/immersive-meditation.png",
  },
  {
    id: "faliu",
    title: "法流学习",
    shortTitle: "法流",
    summary: "短内容、全文阅读、收藏和问经入口服务轻量学习。",
    action: "浏览法流",
    tone: "rose",
    screenshot: "/product/group-practice.png",
  },
  {
    id: "leaderboard",
    title: "共修榜单",
    shortTitle: "榜单",
    summary: "看见同行者的法布施与禅修节奏，也保留个人边界。",
    action: "查看榜单",
    tone: "violet",
    screenshot: "/product/global-ranking.png",
  },
] as const;

export const sutraLibrary = [
  {
    title: "心经",
    category: "般若",
    minutes: 8,
    progress: 86,
    summary: "适合每日短时听诵，训练把注意力收回空性与慈悲。",
  },
  {
    title: "金刚经",
    category: "般若",
    minutes: 42,
    progress: 64,
    summary: "适合做阶段性精读，结合重点偈句与回向记录。",
  },
  {
    title: "地藏经",
    category: "大乘经典",
    minutes: 108,
    progress: 32,
    summary: "适合分品听诵，配合家庭、祖先和众生回向。",
  },
  {
    title: "楞严咒",
    category: "咒语",
    minutes: 24,
    progress: 51,
    summary: "适合做固定功课，跟随音频逐段熟悉发音节奏。",
  },
] as const;

export const practicePlan = [
  {
    title: "清晨定课",
    duration: "18 分钟",
    detail: "净手、发愿、心经一遍、静坐十分钟。",
  },
  {
    title: "午间听诵",
    duration: "12 分钟",
    detail: "跟随音频复习今日经文，记录一句最有触动的句子。",
  },
  {
    title: "夜间回向",
    duration: "9 分钟",
    detail: "整理当天法布施内容，回向给具体人群与一切众生。",
  },
] as const;

export const dharmaFeedItems = [
  {
    title: "如何把一段经文整理成可分享资料",
    tag: "法布施",
    readTime: "4 分钟",
  },
  {
    title: "每日功课不稳定时，先保留一个最小动作",
    tag: "修行",
    readTime: "3 分钟",
  },
  {
    title: "共修关系里最重要的是清楚、温和与可持续",
    tag: "共修",
    readTime: "5 分钟",
  },
] as const;

export const aiQuickPrompts = [
  "帮我整理一段适合全球法布施的善法文字",
  "查找可公开分享的心经学习资源，并说明来源",
  "根据今天的状态安排一个 20 分钟修行计划",
  "把这段经文解释给初学者听，语气庄重简洁",
] as const;

export const leaderboardPreview = [
  { name: "明净", region: "中国", value: "328 分钟", rank: 1 },
  { name: "善行", region: "新加坡", value: "271 分钟", rank: 2 },
  { name: "慧灯", region: "加拿大", value: "236 分钟", rank: 3 },
  { name: "净愿", region: "马来西亚", value: "219 分钟", rank: 4 },
] as const;

export const miniProgramTabs = [
  { pagePath: "pages/index/index", text: "大乘", icon: "home" },
] as const;
