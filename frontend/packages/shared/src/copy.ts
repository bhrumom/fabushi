export const homeHighlights = [
  {
    title: "传播佛法",
    description: "上传、分享、回向，让善意被看见。",
  },
  {
    title: "记录修行",
    description: "公开或私密记录，保留自己的节奏。",
  },
  {
    title: "找到同行者",
    description: "通过关注、榜单和共修关系连接彼此。",
  },
] as const;

export const primaryNavigation = [
  { label: "首页", href: "/" },
  { label: "下载", href: "/download" },
  { label: "申请测试", href: "/apply" },
  { label: "FAQ", href: "/faq" },
  { label: "联系", href: "/contact" },
  { label: "核心能力", href: "/#capabilities" },
  { label: "内容", href: "/insights" },
] as const;

export const launchRoadmap = [
  "官网先承接介绍、下载、FAQ 和活动入口。",
  "微信小程序优先做轻浏览、榜单和公开档案。",
  "Flutter 主应用继续承接完整体验。",
] as const;

export const downloadOptions = [
  {
    platform: "iOS",
    status: "内测准备中",
    description: "完整主应用体验，开放后通过 TestFlight 参与。",
    ctaLabel: "加入 iOS 等待名单",
    ctaHref: "mailto:support@fabushi.com?subject=Fabushi%20iOS%20TestFlight",
  },
  {
    platform: "Android",
    status: "封闭测试中",
    description: "优先体验传播、榜单、档案与上传流程。",
    ctaLabel: "加入 Android 等待名单",
    ctaHref: "mailto:support@fabushi.com?subject=Fabushi%20Android%20Beta",
  },
  {
    platform: "微信小程序",
    status: "规划中",
    description: "轻浏览、榜单和微信生态触达。",
    ctaLabel: "查看小程序路线",
    ctaHref: "/insights/wechat-mini-program-phase-one",
  },
  {
    platform: "Web 官网",
    status: "建设中",
    description: "品牌说明、下载引导、FAQ 与专题内容。",
    ctaLabel: "浏览官网路线",
    ctaHref: "/insights/official-site-structure",
  },
] as const;

export const downloadStatusNotes = [
  "当前还没有可公开挂出的 App Store、TestFlight 或 APK 正式直链。",
  "官网先展示真实状态和等待名单入口。",
  "正式链接可公开后，直接替换对应入口。",
] as const;

export const faqItems = [
  {
    question: "官网、微信小程序和主应用分别做什么？",
    answer:
      "官网负责介绍、下载、FAQ 和内容；微信小程序负责轻触达；主应用承接完整体验。",
  },
  {
    question: "为什么不直接用 Flutter Web 做官网？",
    answer:
      "官网更需要 SEO、内容结构和首屏速度，所以使用 Next.js。",
  },
  {
    question: "官网和小程序会不会分裂？",
    answer:
      "不会。前端会共享 API、类型、品牌文案和部分业务逻辑。",
  },
  {
    question: "小程序首期会上什么？",
    answer: "轻浏览、榜单、公开档案和基础登录。",
  },
  {
    question: "为什么下载页不只是等待名单？",
    answer:
      "下载页会逐步接入 Android beta、TestFlight 状态和正式版信息。",
  },
] as const;

export const contactChannels = [
  {
    label: "支持邮箱",
    value: "support@fabushi.com",
    href: "mailto:support@fabushi.com",
    note: "测试申请、问题反馈、合作沟通。",
  },
  {
    label: "官网域名",
    value: "fabushi.ombhrum.com",
    href: "https://fabushi.ombhrum.com",
    note: "官网和正式下载入口。",
  },
  {
    label: "GitHub 仓库",
    value: "bhrumom/fabushi",
    href: "https://github.com/bhrumom/fabushi",
    note: "查看进展、提交 issue。",
  },
] as const;

export const betaApplicationTracks = [
  {
    name: "iOS TestFlight",
    summary: "适合优先体验完整主应用流程的用户。",
    checklist: [
      "留下常用邮箱",
      "说明关注内容传播、修行记录还是社交发现",
      "说明是否愿意反馈问题",
    ],
    ctaLabel: "申请 iOS 内测",
    ctaHref:
      "mailto:support@fabushi.com?subject=Fabushi%20iOS%20Beta%20Application&body=%E4%BD%A0%E5%A5%BD%EF%BC%8C%E6%88%91%E6%83%B3%E7%94%B3%E8%AF%B7%20Fabushi%20iOS%20%E5%86%85%E6%B5%8B%E3%80%82%0A%0A%E5%B8%B8%E7%94%A8%E9%82%AE%E7%AE%B1%EF%BC%9A%0A%E5%85%B3%E6%B3%A8%E7%82%B9%EF%BC%9A%0A%E6%98%AF%E5%90%A6%E6%84%BF%E6%84%8F%E5%8F%8D%E9%A6%88%E9%97%AE%E9%A2%98%EF%BC%9A%0A",
  },
  {
    name: "Android Beta",
    summary: "适合优先体验 Android 主流程的用户。",
    checklist: [
      "留下常用邮箱",
      "说明 Android 机型或系统版本",
      "说明最想体验的模块",
    ],
    ctaLabel: "申请 Android 内测",
    ctaHref:
      "mailto:support@fabushi.com?subject=Fabushi%20Android%20Beta%20Application&body=%E4%BD%A0%E5%A5%BD%EF%BC%8C%E6%88%91%E6%83%B3%E7%94%B3%E8%AF%B7%20Fabushi%20Android%20%E5%86%85%E6%B5%8B%E3%80%82%0A%0A%E5%B8%B8%E7%94%A8%E9%82%AE%E7%AE%B1%EF%BC%9A%0AAndroid%20%E6%9C%BA%E5%9E%8B%2F%E7%B3%BB%E7%BB%9F%E7%89%88%E6%9C%AC%EF%BC%9A%0A%E6%9C%80%E6%83%B3%E4%BD%93%E9%AA%8C%E7%9A%84%E6%A8%A1%E5%9D%97%EF%BC%9A%0A",
  },
  {
    name: "合作与渠道",
    summary: "适合讨论内容、渠道或活动合作。",
    checklist: [
      "留下姓名或组织名称",
      "说明合作方向",
      "留下回联方式",
    ],
    ctaLabel: "发起合作沟通",
    ctaHref:
      "mailto:support@fabushi.com?subject=Fabushi%20Partnership%20Inquiry&body=%E4%BD%A0%E5%A5%BD%EF%BC%8C%E6%88%91%E6%83%B3%E5%92%8C%20Fabushi%20%E8%AE%A8%E8%AE%BA%E5%90%88%E4%BD%9C%E3%80%82%0A%0A%E5%A7%93%E5%90%8D%E6%88%96%E7%BB%84%E7%BB%87%E5%90%8D%E7%A7%B0%EF%BC%9A%0A%E5%90%88%E4%BD%9C%E6%96%B9%E5%90%91%EF%BC%9A%0A%E5%9B%9E%E8%81%94%E6%96%B9%E5%BC%8F%EF%BC%9A%0A",
  },
] as const;
