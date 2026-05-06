export const homeHighlights = [
  {
    title: "全球法布施传播",
    description: "围绕内容传播、上传分享、回向记录与可见榜单，建立持续增长的善意网络。",
  },
  {
    title: "修行记录与隐私控制",
    description: "保留公开展示与私密修行的边界，让个人节奏与社交互动能自然共存。",
  },
  {
    title: "轻社群与共修关系",
    description: "通过关注、排行榜、共修小组和公开档案，帮助用户更容易找到同行者。",
  },
] as const;

export const primaryNavigation = [
  { label: "首页", href: "/" },
  { label: "下载", href: "/download" },
  { label: "常见问题", href: "/faq" },
  { label: "核心能力", href: "/#capabilities" },
  { label: "内容专栏", href: "/insights" },
] as const;

export const launchRoadmap = [
  "先上线官网，承接品牌介绍、功能说明、下载指引和后续活动落地页。",
  "同步建设微信小程序首期版本，优先覆盖轻浏览、榜单、公开档案和基础登录。",
  "继续把更重的创作、上传和沉浸式体验保留在 Flutter 主应用里。",
] as const;

export const downloadOptions = [
  {
    platform: "iOS",
    status: "内测准备中",
    description: "保留沉浸式内容浏览、上传分享、完整个人中心和重交互流程。",
    ctaLabel: "获取 TestFlight 通知",
    ctaHref: "mailto:support@fabushi.com?subject=Fabushi%20iOS%20TestFlight",
  },
  {
    platform: "Android",
    status: "封闭测试中",
    description: "优先承接传播、榜单、公开档案与上传相关的完整主应用体验。",
    ctaLabel: "申请 Android 内测",
    ctaHref: "mailto:support@fabushi.com?subject=Fabushi%20Android%20Beta",
  },
  {
    platform: "微信小程序",
    status: "首期规划中",
    description: "聚焦轻浏览、榜单、公开档案和微信生态内的便捷触达。",
    ctaLabel: "查看小程序路线",
    ctaHref: "/insights/wechat-mini-program-phase-one",
  },
  {
    platform: "Web 官网",
    status: "本轮建设中",
    description: "负责品牌说明、下载引导、FAQ、专题内容与活动落地页。",
    ctaLabel: "浏览官网路线",
    ctaHref: "/insights/official-site-structure",
  },
] as const;

export const faqItems = [
  {
    question: "官网、微信小程序和 Flutter 主应用分别承担什么角色？",
    answer:
      "官网负责品牌说明、下载入口、FAQ 和内容运营；微信小程序负责微信生态里的轻触达；Flutter 主应用继续承接完整的沉浸式体验和重交互流程。",
  },
  {
    question: "为什么不直接用 Flutter Web 同时做官网和小程序？",
    answer:
      "官网需要更好的 SEO、内容结构和首屏控制，小程序又有自己的运行规范。拆成 Next.js + Taro 可以减少后续返工，同时继续复用现有后端与业务层。",
  },
  {
    question: "官网和小程序会不会变成两套完全分裂的系统？",
    answer:
      "不会。新前端 monorepo 会持续共享 API client、类型、品牌文案和部分纯业务逻辑，差异主要保留在各自的页面表现层。",
  },
  {
    question: "小程序首期最先会上什么？",
    answer:
      "优先是轻浏览、榜单、公开档案和基础登录，先把传播入口和社交发现路径打通，再逐步补更复杂的内容创作与上传流程。",
  },
] as const;

export const insightArticles = [
  {
    slug: "product-roadmap",
    title: "法布施多端产品路线图",
    description: "官网、微信小程序与 Flutter 主应用的职责边界，以及为什么现在要拆出新的前端 monorepo。",
    category: "产品路线",
    publishedAt: "2026-05-06",
    body: [
      "法布施当前已经有一条稳定的 Flutter 主应用主线，它很适合承接完整功能、重交互和沉浸式内容体验，但并不天然适合作为官网和微信小程序的统一载体。",
      "官网这一侧更看重品牌识别、内容收录、页面结构与长期运营，因此选择 Next.js 作为新的官网框架。微信小程序这一侧更看重微信生态内的轻触达、轻交互和后续多端延展，因此选择 Taro。",
      "新的前端 monorepo 不追求把全部界面强行复用，而是把真正稳定的东西沉淀下来：接口层、类型、文案和部分纯业务逻辑。这样既能减少重复劳动，也能避免不同端互相牵制。",
    ],
  },
  {
    slug: "wechat-mini-program-phase-one",
    title: "微信小程序首期范围",
    description: "为什么首期优先做轻浏览、榜单、公开档案和基础登录，而不是把主应用完整搬进去。",
    category: "小程序",
    publishedAt: "2026-05-06",
    body: [
      "微信小程序首期的目标不是复制整个主应用，而是把最容易形成传播和留存入口的能力先放进去。",
      "轻浏览可以承担首次认知，榜单和公开档案可以承担社交发现，基础登录则为后续个人数据和关注关系打下最小闭环。",
      "等这些链路稳定之后，再决定哪些内容创作、上传或更重的互动流程值得继续往小程序里加，哪些则继续留在 Flutter 主应用里更合适。",
    ],
  },
  {
    slug: "official-site-structure",
    title: "官网信息结构与上线顺序",
    description: "官网为什么先补下载页、FAQ、内容页和 SEO，而不是只做一张漂亮首页。",
    category: "官网",
    publishedAt: "2026-05-06",
    body: [
      "首页负责第一印象，但真正决定官网能不能长期使用的是信息结构。用户来到官网之后，最常见的动作其实是找下载入口、确认产品定位、查看常见问题和继续阅读专题内容。",
      "因此官网的第一轮迭代不应该停在单页展示，而应该尽快补齐下载页、FAQ、内容页和搜索引擎需要的基础文件。",
      "这样一来，无论后续是做活动页、发布说明、更新日志还是功能专题，网站都会有稳定的承接骨架，而不是每次重新拼一张临时页面。",
    ],
  },
] as const;
