import type { Metadata } from "next";
import {
  aiQuickPrompts,
  appExperienceStats,
  appModules,
  brand,
  dharmaFeedItems,
  leaderboardPreview,
  practicePlan,
  sutraLibrary,
} from "@fabushi/shared";
import {
  BookOpen,
  Bot,
  BrainCircuit,
  CalendarDays,
  ChevronRight,
  CircleUserRound,
  Flame,
  Globe2,
  Headphones,
  Library,
  LineChart,
  PlayCircle,
  Search,
  Sparkles,
  Timer,
  Users,
  Zap,
} from "lucide-react";
import { siteHref, siteUrl } from "../../lib/site-url";
import styles from "./app-dashboard.module.css";

const pageTitle = `大乘 Web App | ${brand.name}`;
const pageDescription =
  "大乘 Web App 是法布施 App 的快速网页版，提供全球法布施、经文听诵、禅室修行、法流学习、榜单和大乘 AI 入口。";

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: siteUrl("/app"),
  },
  openGraph: {
    title: pageTitle,
    description: pageDescription,
    url: siteUrl("/app"),
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
};

const moduleIcons = {
  "global-dharma": Globe2,
  sutra: BookOpen,
  meditation: Timer,
  faliu: Headphones,
  leaderboard: LineChart,
  ai: Bot,
} as const;

export default function WebAppPage() {
  return (
    <main className={styles.shell}>
      <div className={styles.topBar}>
        <a className={styles.brand} href={siteHref("/")}>
          <span className={styles.brandMark}>
            <Sparkles size={18} aria-hidden="true" />
          </span>
          <span>大乘 Web</span>
        </a>
        <div className={styles.topNav}>
          <a className={styles.navLink} href={siteHref("/download")}>
            下载 App
          </a>
          <a className={styles.navLink} href={siteHref("/faq")}>
            FAQ
          </a>
          <a className={styles.ghostButton} href={siteHref("/app/ai")}>
            <Bot size={17} aria-hidden="true" />
            大乘 AI
          </a>
        </div>
      </div>

      <section className={styles.hero}>
        <div className={styles.heroCopy}>
          <p className={styles.eyebrow}>
            <Zap size={16} aria-hidden="true" />
            替代 Flutter Web 的快速入口
          </p>
          <h1 className={styles.heroTitle}>
            <span>大乘</span>
            <span>现在从 Web 开始</span>
          </h1>
          <p className={styles.heroText}>
            经文、禅室、法流、榜单和全球法布施被重新组织成轻量 Web 工作台。首屏不加载 Flutter
            runtime，核心信息静态输出，AI 与资源搜索按需连接后端。
          </p>
          <div className={styles.heroActions}>
            <a className={styles.primaryButton} href={siteHref("/app/ai")}>
              <Bot size={18} aria-hidden="true" />
              打开大乘 AI
            </a>
            <a className={styles.ghostButton} href="#modules">
              <PlayCircle size={18} aria-hidden="true" />
              浏览功能
            </a>
          </div>
          <div className={styles.statsGrid} aria-label="大乘 Web App 状态">
            {appExperienceStats.map((item) => (
              <div className={styles.stat} key={item.label}>
                <strong>{item.value}</strong>
                <span>
                  {item.label} · {item.unit}
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className={styles.device} aria-label="Web App preview">
          <div className={styles.deviceFrame}>
            <div className={styles.deviceScreen}>
              <img className={styles.screenImage} src={siteHref("/product/global-dharma.png")} alt="" />
              <div className={styles.screenPanel}>
                <h2>今日修行工作台</h2>
                <p>把一次法布施、一段听诵和一个 AI 资源任务放在同一条线上。</p>
                <div className={styles.screenTools}>
                  <span className={styles.screenTool}>发送</span>
                  <span className={styles.screenTool}>听诵</span>
                  <span className={styles.screenTool}>问 AI</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className={styles.section} id="modules">
        <div className={styles.sectionHeader}>
          <h2>核心模块</h2>
          <p>网页版先承接高频浏览、轻交互和 AI 任务，重本地能力继续留在原生 App。</p>
        </div>
        <div className={styles.moduleGrid}>
          {appModules.map((item) => {
            const Icon = moduleIcons[item.id] ?? Library;
            const href = item.id === "ai" ? siteHref("/app/ai") : `#${item.id}`;
            return (
              <a className={styles.moduleCard} href={href} key={item.id}>
                <span className={styles.moduleTop}>
                  <span className={styles.moduleIcon}>
                    <Icon size={22} aria-hidden="true" />
                  </span>
                  <ChevronRight size={18} aria-hidden="true" />
                </span>
                <span>
                  <h3>{item.title}</h3>
                  <p>{item.summary}</p>
                  <span className={styles.moduleAction}>{item.action}</span>
                </span>
              </a>
            );
          })}
        </div>
      </section>

      <section className={styles.section} id="sutra">
        <div className={styles.sectionHeader}>
          <h2>经文与功课</h2>
          <p>Web 版默认展示可扫描的进度、摘要和听诵时长，适合在电脑与微信内快速续接。</p>
        </div>
        <div className={styles.workGrid}>
          <div className={styles.panel}>
            <div className={styles.panelTitle}>
              <h3>经文书架</h3>
              <BookOpen size={20} aria-hidden="true" />
            </div>
            <div className={styles.sutraList}>
              {sutraLibrary.map((item) => (
                <div className={styles.sutraItem} key={item.title}>
                  <span>
                    <span className={styles.itemTitle}>{item.title}</span>
                    <span className={styles.itemMeta}>
                      {item.category} · {item.minutes} 分钟 · {item.summary}
                    </span>
                  </span>
                  <span className={styles.progress} aria-label={`${item.title} 进度 ${item.progress}%`}>
                    <span style={{ width: `${item.progress}%` }} />
                  </span>
                </div>
              ))}
            </div>
          </div>
          <div className={styles.panel} id="meditation">
            <div className={styles.panelTitle}>
              <h3>今日修行</h3>
              <CalendarDays size={20} aria-hidden="true" />
            </div>
            <div className={styles.practiceList}>
              {practicePlan.map((item) => (
                <div className={styles.practiceItem} key={item.title}>
                  <span className={styles.itemTitle}>
                    {item.title} · {item.duration}
                  </span>
                  <span className={styles.itemMeta}>{item.detail}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className={styles.section} id="faliu">
        <div className={styles.bottomGrid}>
          <div className={styles.panel}>
            <div className={styles.panelTitle}>
              <h3>法流</h3>
              <Flame size={20} aria-hidden="true" />
            </div>
            <div className={styles.feedList}>
              {dharmaFeedItems.map((item) => (
                <div className={styles.feedItem} key={item.title}>
                  <span className={styles.itemTitle}>{item.title}</span>
                  <span className={styles.itemMeta}>
                    {item.tag} · {item.readTime}
                  </span>
                </div>
              ))}
            </div>
          </div>

          <div className={styles.panel} id="leaderboard">
            <div className={styles.panelTitle}>
              <h3>共修榜</h3>
              <Users size={20} aria-hidden="true" />
            </div>
            <div className={styles.rankList}>
              {leaderboardPreview.map((item) => (
                <div className={styles.rankItem} key={item.name}>
                  <span className={styles.rankNumber}>{item.rank}</span>
                  <span>
                    <span className={styles.itemTitle}>{item.name}</span>
                    <span className={styles.itemMeta}>{item.region}</span>
                  </span>
                  <strong>{item.value}</strong>
                </div>
              ))}
            </div>
          </div>

          <div className={styles.panel} id="global-dharma">
            <div className={styles.panelTitle}>
              <h3>全球发送</h3>
              <Globe2 size={20} aria-hidden="true" />
            </div>
            <div className={styles.practiceList}>
              <div className={styles.practiceItem}>
                <span className={styles.itemTitle}>目标地区</span>
                <span className={styles.itemMeta}>中国、东南亚、北美、欧洲节点自动排队。</span>
              </div>
              <div className={styles.practiceItem}>
                <span className={styles.itemTitle}>当前素材</span>
                <span className={styles.itemMeta}>经文文字、发愿文、公开音频与图片说明。</span>
              </div>
              <div className={styles.practiceItem}>
                <span className={styles.itemTitle}>连接状态</span>
                <span className={styles.itemMeta}>Web 版展示状态，原生 App 承接本机发送能力。</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className={styles.section} id="ai">
        <div className={styles.aiBand}>
          <div>
            <p className={styles.eyebrow}>
              <BrainCircuit size={16} aria-hidden="true" />
              大乘 AI
            </p>
            <h2>从资源查找到发愿文，交给新的 Web AI 入口。</h2>
            <p className={styles.heroText}>
              新 AI 页面支持流式回答、资源搜索、会话记录和移动端分享入口。Flutter App 的大乘 AI
              会跳转到这里。
            </p>
            <div className={styles.heroActions}>
              <a className={styles.primaryButton} href={siteHref("/app/ai")}>
                <Search size={18} aria-hidden="true" />
                进入 AI 控制台
              </a>
              <a className={styles.ghostButton} href={siteHref("/download")}>
                <CircleUserRound size={18} aria-hidden="true" />
                下载原生 App
              </a>
            </div>
          </div>
          <div className={styles.promptGrid}>
            {aiQuickPrompts.map((prompt) => (
              <a
                className={styles.promptLink}
                href={siteHref(`/app/ai?prompt=${encodeURIComponent(prompt)}`)}
                key={prompt}
              >
                <span>{prompt}</span>
                <ChevronRight size={18} aria-hidden="true" />
              </a>
            ))}
          </div>
        </div>
      </section>
    </main>
  );
}
