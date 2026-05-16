import { LocalizedText } from "./localized-text";
import { siteHref } from "../lib/site-url";

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div>
        <p className="footer-title">
          <LocalizedText zh="法布施 大乘" en="Fabushi" />
        </p>
        <p className="footer-copy">
          <LocalizedText
            zh="经文、禅修、法流与全球法布施。"
            en="Sutras, meditation, dharma videos, and global giving."
          />
        </p>
      </div>
      <div className="footer-links">
        <a href={siteHref("/download")}>
          <LocalizedText zh="下载入口" en="Download" />
        </a>
        <a href={siteHref("/apply")}>
          <LocalizedText zh="申请测试" en="Apply" />
        </a>
        <a href={siteHref("/faq")}>
          <LocalizedText zh="常见问题" en="FAQ" />
        </a>
        <a href={siteHref("/community")}>
          <LocalizedText zh="佛法论坛" en="Community Forum" />
        </a>
        <a href={siteHref("/buddhadharma")}>
          <LocalizedText zh="佛法入门" en="Dharma Basics" />
        </a>
        <a href={siteHref("/start-learning-buddhism")}>
          <LocalizedText zh="学佛从哪里开始" en="Where to Begin" />
        </a>
        <a href={siteHref("/meditation")}>
          <LocalizedText zh="禅修入门" en="Meditation Guide" />
        </a>
        <a href={siteHref("/practice-guide")}>
          <LocalizedText zh="修行方法总览" en="Practice Guide" />
        </a>
        <a href={siteHref("/daily-practice")}>
          <LocalizedText zh="日常功课怎么安排" en="Daily Practice" />
        </a>
        <a href={siteHref("/sutra-guide")}>
          <LocalizedText zh="佛经导读" en="Sutra Guide" />
        </a>
        <a href={siteHref("/beginner-sutra-recommendations")}>
          <LocalizedText zh="初学者佛经推荐" en="Beginner Sutra Picks" />
        </a>
        <a href={siteHref("/privacy")}>
          <LocalizedText zh="隐私说明" en="Privacy" />
        </a>
        <a href={siteHref("/contact")}>
          <LocalizedText zh="联系" en="Contact" />
        </a>
        <a href={siteHref("/insights")}>
          <LocalizedText zh="内容专栏" en="Insights" />
        </a>
        <a href="mailto:support@ombhrum.com">support@ombhrum.com</a>
      </div>
    </footer>
  );
}
