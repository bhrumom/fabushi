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

export const trustHighlights = [
  {
    title: "发布状态回流官网",
    value: "Release / TestFlight / 正式版同步",
    description: "下载页可以直接承接 GitHub Release、TestFlight 上传状态和后续人工验收后的正式版入口。",
  },
  {
    title: "三端分工清楚",
    value: "官网 / 微信小程序 / 主应用",
    description: "用户先看懂从哪里开始，再决定是轻触达、持续传播，还是进入完整沉浸式体验。",
  },
  {
    title: "现有后端继续复用",
    value: "Workers API + 共享类型",
    description: "官网不是独立空壳，而是继续共用现有 API、业务模型和发布链路。",
  },
  {
    title: "公开开发可追踪",
    value: "GitHub 仓库持续公开",
    description: "官网、下载状态、专题内容与项目推进可以在同一条公开记录里被追溯和验证。",
  },
] as const;

export const audienceJourneys = [
  {
    title: "第一次了解法布施的人",
    summary: "先通过官网快速理解产品定位、开放状态和当前最合适的入口。",
    detail: "适合想知道这个项目到底解决什么问题、当前能不能加入、下一步应该从哪里开始的人。",
  },
  {
    title: "已经在持续修行的人",
    summary: "可以用主应用沉淀更完整的修行记录、公开档案和内容互动。",
    detail: "如果你需要更完整的个人中心、内容创作和长期记录体验，主应用会是核心承接面。",
  },
  {
    title: "希望传播或共修协作的人",
    summary: "先从微信小程序和公开榜单进入轻触达，再逐步沉淀到更完整的关系链路里。",
    detail: "这条路径更适合内容传播、活动扩散、公开发现和社群连接等轻量但高频的场景。",
  },
] as const;

export const productSurfaceMap = [
  {
    title: "官网",
    role: "品牌说明、下载入口、FAQ、专题内容",
    bestFor: "初次认知、搜索收录、生成式搜索引用、活动落地页与长期对外入口。",
  },
  {
    title: "微信小程序",
    role: "轻浏览、榜单、公开档案、基础登录",
    bestFor: "微信生态内的轻触达、社交发现和传播起点。",
  },
  {
    title: "Flutter 主应用",
    role: "完整体验、重交互、沉浸式内容与长期记录",
    bestFor: "更完整的创作、上传、关系链与个人沉淀。",
  },
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
    question: "为什么下载页现在不再只是等待名单入口？",
    answer:
      "因为官网已经开始直接读取 GitHub Release 的 Android beta 安装包、TestFlight 上传状态，以及人工验收后发布的正式版信息。这样下载页会跟着发布链路一起更新，而不是靠手动改文案。",
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

export const betaApplicationTracks = [
  {
    name: "iOS TestFlight",
    summary: "适合想优先体验完整主应用流程，并愿意接受内测节奏的用户。",
    checklist: [
      "附上你的常用邮箱",
      "说明你更关注内容传播、修行记录还是社交发现",
      "写明你是否愿意反馈 bug 和体验问题",
    ],
    ctaLabel: "申请 iOS 内测",
    ctaHref:
      "mailto:support@fabushi.com?subject=Fabushi%20iOS%20Beta%20Application&body=%E4%BD%A0%E5%A5%BD%EF%BC%8C%E6%88%91%E6%83%B3%E7%94%B3%E8%AF%B7%20Fabushi%20iOS%20%E5%86%85%E6%B5%8B%E3%80%82%0A%0A%E5%B8%B8%E7%94%A8%E9%82%AE%E7%AE%B1%EF%BC%9A%0A%E5%85%B3%E6%B3%A8%E7%82%B9%EF%BC%9A%0A%E6%98%AF%E5%90%A6%E6%84%BF%E6%84%8F%E5%8F%8D%E9%A6%88%E9%97%AE%E9%A2%98%EF%BC%9A%0A",
  },
  {
    name: "Android Beta",
    summary: "适合想尽快体验传播、榜单、公开档案和上传相关完整主流程的用户。",
    checklist: [
      "附上你的常用邮箱",
      "说明你的 Android 机型或系统版本",
      "写明你最想优先体验哪个模块",
    ],
    ctaLabel: "申请 Android 内测",
    ctaHref:
      "mailto:support@fabushi.com?subject=Fabushi%20Android%20Beta%20Application&body=%E4%BD%A0%E5%A5%BD%EF%BC%8C%E6%88%91%E6%83%B3%E7%94%B3%E8%AF%B7%20Fabushi%20Android%20%E5%86%85%E6%B5%8B%E3%80%82%0A%0A%E5%B8%B8%E7%94%A8%E9%82%AE%E7%AE%B1%EF%BC%9A%0AAndroid%20%E6%9C%BA%E5%9E%8B%2F%E7%B3%BB%E7%BB%9F%E7%89%88%E6%9C%AC%EF%BC%9A%0A%E6%9C%80%E6%83%B3%E4%BD%93%E9%AA%8C%E7%9A%84%E6%A8%A1%E5%9D%97%EF%BC%9A%0A",
  },
  {
    name: "合作与渠道",
    summary: "适合想讨论传播合作、内容共建、渠道联动或活动承接的人。",
    checklist: [
      "附上你的姓名或组织名称",
      "说明合作方向或渠道资源",
      "留下可回联的邮箱或微信说明",
    ],
    ctaLabel: "发起合作沟通",
    ctaHref:
      "mailto:support@fabushi.com?subject=Fabushi%20Partnership%20Inquiry&body=%E4%BD%A0%E5%A5%BD%EF%BC%8C%E6%88%91%E6%83%B3%E5%92%8C%20Fabushi%20%E8%AE%A8%E8%AE%BA%E5%90%88%E4%BD%9C%E3%80%82%0A%0A%E5%A7%93%E5%90%8D%E6%88%96%E7%BB%84%E7%BB%87%E5%90%8D%E7%A7%B0%EF%BC%9A%0A%E5%90%88%E4%BD%9C%E6%96%B9%E5%90%91%EF%BC%9A%0A%E5%9B%9E%E8%81%94%E6%96%B9%E5%BC%8F%EF%BC%9A%0A",
  },
] as const;
