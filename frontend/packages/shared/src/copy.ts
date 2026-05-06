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
  { label: "联系", href: "/contact" },
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
    ctaLabel: "加入 iOS 等待名单",
    ctaHref: "mailto:support@fabushi.com?subject=Fabushi%20iOS%20TestFlight",
  },
  {
    platform: "Android",
    status: "封闭测试中",
    description: "优先承接传播、榜单、公开档案与上传相关的完整主应用体验。",
    ctaLabel: "加入 Android 等待名单",
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

export const downloadStatusNotes = [
  "当前仓库里还没有可直接公开挂出的 App Store、TestFlight 或 APK 正式下载直链。",
  "官网先把各平台状态、职责和等待名单入口讲清楚，避免用户点进来却落到空页面。",
  "一旦正式下载链接可公开，优先替换 downloadOptions 中的对应入口即可，不需要重做页面结构。",
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
  {
    question: "为什么下载页现在是等待名单入口，而不是直接下载？",
    answer:
      "因为当前仓库和现有公开资料里还没有稳定、适合公开挂出的正式下载链接。先提供等待名单入口，可以让官网现在就上线，同时避免用户拿到失效地址。",
  },
] as const;

export const contactChannels = [
  {
    label: "支持邮箱",
    value: "support@fabushi.com",
    href: "mailto:support@fabushi.com",
    note: "下载申请、测试资格、问题反馈和合作沟通统一从这里进入。",
  },
  {
    label: "官网域名",
    value: "fabushi.ombhrum.com",
    href: "https://fabushi.ombhrum.com",
    note: "后续会作为官网、专题页和正式下载指引的统一入口。",
  },
  {
    label: "GitHub 仓库",
    value: "bhrumom/fabushi",
    href: "https://github.com/bhrumom/fabushi",
    note: "适合查看项目进展、提交 issue 和跟踪公开开发记录。",
  },
] as const;
