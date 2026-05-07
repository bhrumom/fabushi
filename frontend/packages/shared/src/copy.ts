export const homeHighlights = [
  {
    title: "传播入口更清楚",
    description: "把项目定位、下载状态、申请测试和内容入口收拢到同一官网里，减少用户第一次接触时的理解成本。",
  },
  {
    title: "修行记录更有边界",
    description: "同时照顾公开传播、个人修行记录与隐私控制，让分享、回向与安静练习可以并存。",
  },
  {
    title: "多端协作不再割裂",
    description: "官网负责理解与转化，小程序负责轻触达，主应用负责完整体验，三者围绕同一套品牌与发布节奏协同工作。",
  },
] as const;

export const homeTrustSignals = [
  {
    title: "平台分工清晰",
    summary: "官网负责解释与引导，小程序负责轻触达，主应用负责完整体验。",
    description:
      "用户第一次进入时就能知道该从哪里了解产品、从哪里申请测试、从哪里进入更深度的使用流程，减少入口混乱和跳失。",
  },
  {
    title: "发布状态可见",
    summary: "下载页会直接承接 beta 安装包、TestFlight 状态和正式版发布说明。",
    description:
      "官网不再只是静态等待名单，而是开始连接真实发布链路，让用户、合作方和搜索引擎都能看到当前可获得的入口。",
  },
  {
    title: "内容能够持续累积",
    summary: "除了首页，官网还承接路线、专题内容、更新说明和 FAQ。",
    description:
      "这让站点既能做品牌入口，也能沉淀长期可搜索、可引用、可分享的内容资产，而不是一页式说明页。",
  },
] as const;

export const homeUseCases = [
  {
    audience: "新用户",
    title: "先理解产品，再决定从哪个入口进入。",
    description: "官网优先解释 Fabushi 是什么、适合谁、当前能做什么，以及 iOS、Android、微信小程序分别是什么状态。",
  },
  {
    audience: "内测申请者",
    title: "快速找到申请路径、下载状态和反馈方式。",
    description: "把等待名单、测试资格、安装包说明和反馈邮箱放在一条清晰路径里，减少用户往返询问。",
  },
  {
    audience: "合作与渠道方",
    title: "更快判断项目方向、公开能力和可合作的切入点。",
    description: "官网把产品定位、公开协作方式、内容专栏和联系入口整理清楚，方便外部伙伴快速完成判断。",
  },
  {
    audience: "生成式搜索与搜索引擎",
    title: "更容易准确理解 Fabushi 的平台结构和价值主张。",
    description: "定义、场景、FAQ、内容专栏和可见发布状态会一起组成更容易被引用和总结的站点语义结构。",
  },
] as const;

export const primaryNavigation = [
  { label: "首页", href: "/" },
  { label: "下载", href: "/download" },
  { label: "申请测试", href: "/apply" },
  { label: "常见问题", href: "/faq" },
  { label: "联系", href: "/contact" },
  { label: "核心能力", href: "/#capabilities" },
  { label: "内容专栏", href: "/insights" },
] as const;

export const launchRoadmap = [
  "先把官网做成稳定的公开入口，集中承接项目介绍、下载状态、FAQ、内容更新和联系路径。",
  "同步推进微信小程序首期版本，优先覆盖轻浏览、榜单、公开档案和基础登录等轻场景触达能力。",
  "继续把更完整的上传、沉浸式浏览、个人中心和重交互流程保留在 Flutter 主应用里。",
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
  "官网现在会直接承接 Android beta、iOS TestFlight 和正式版发布状态，不再只是一个泛泛的等待名单页面。",
  "当正式下载链接尚未公开时，页面会优先说明状态、适用人群和下一步动作，避免用户点进来却找不到判断依据。",
  "一旦正式下载链接可公开，优先替换对应入口即可，不需要重新改整页结构。",
] as const;

export const faqItems = [
  {
    question: "法布施 Fabushi 是什么？",
    answer:
      "Fabushi 是一个围绕佛法传播、修行记录、善意分享与社群连接组织起来的多端产品入口。官网负责解释与引导，小程序负责轻触达，主应用负责完整体验。",
  },
  {
    question: "官网、微信小程序和 Flutter 主应用分别承担什么角色？",
    answer:
      "官网负责品牌说明、下载入口、FAQ、发布说明和内容运营；微信小程序负责微信生态里的轻浏览与轻交互；Flutter 主应用继续承接更完整的沉浸式体验和重交互流程。",
  },
  {
    question: "Fabushi 现在可以下载吗？",
    answer:
      "可以先通过官网查看 Android beta、iOS TestFlight 与正式版的当前状态。可公开下载时，官网会直接给出入口；暂未公开时，会明确说明申请测试或等待下一步发布的方式。",
  },
  {
    question: "为什么不直接用 Flutter Web 同时做官网和小程序？",
    answer:
      "官网需要更清晰的 SEO、内容结构、首屏表达和发布信息管理，小程序也有自己的运行规范。拆成 Next.js 官网和 Taro 小程序，可以减少后续返工，同时继续复用现有后端与业务层。",
  },
  {
    question: "Fabushi 适合哪些人先关注？",
    answer:
      "适合正在做佛法内容传播、需要安静记录修行、希望与共修同行者建立连接，或者想参与传播合作与渠道联动的人。官网会优先帮助这些人快速判断自己该走哪条入口。",
  },
  {
    question: "为什么下载页现在不再只是等待名单入口？",
    answer:
      "因为官网已经开始直接读取 GitHub Release 的 Android beta 安装包、TestFlight 上传状态，以及人工验收后发布的正式版信息。这样下载页会跟着发布链路一起更新，而不是只靠手工改文案。",
  },
] as const;

export const contactChannels = [
  {
    label: "支持邮箱",
    value: "support@fabushi.com",
    href: "mailto:support@fabushi.com",
    note: "测试申请、下载问题、反馈收集和合作沟通统一从这里进入，避免入口分散。",
  },
  {
    label: "官网域名",
    value: "fabushi.ombhrum.com",
    href: "https://fabushi.ombhrum.com",
    note: "长期对外入口会统一收拢到官网，便于承接下载、FAQ、专题内容和活动页面。",
  },
  {
    label: "GitHub 仓库",
    value: "bhrumom/fabushi",
    href: "https://github.com/bhrumom/fabushi",
    note: "适合查看公开开发记录、发布资产、issue 反馈与持续迭代进展。",
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
