import {
  dachengHomeExperience,
} from "@fabushi/shared";
import { siteHref } from "../lib/site-url";

const flashcardModes = [
  {
    id: "mixed",
    title: "混合制卡",
    shortTitle: "混合",
    description: "同时生成挖空卡和双向卡。",
  },
  {
    id: "cloze",
    title: "挖空卡",
    shortTitle: "挖空",
    description: "适合背诵关键句和关键词。",
  },
  {
    id: "bidirectional",
    title: "双向卡",
    shortTitle: "双向",
    description: "适合从提示回忆完整内容。",
  },
] as const;

export function FastDachengHome() {
  const {
    brand,
    heroChips,
    toolEntries,
    regions,
    flashcardPrinciples,
  } = dachengHomeExperience;

  return (
    <main
      className="fast-home"
      data-fast-home-root
      data-brand-name={brand.name}
      data-default-text={brand.defaultText}
      data-input-placeholder={brand.inputPlaceholder}
    >
      <div className="fast-bg" aria-hidden="true" />

      <aside className="fast-sidebar" aria-label="首页功能">
        <a className="fast-logo" href={siteHref("/")}>
          <span className="fast-logo-mark">大</span>
          <span>{brand.name}</span>
        </a>
        <button className="fast-side-button" type="button" data-new-chat>
          ✦ 新对话
        </button>
        <nav className="fast-side-nav" aria-label="快捷功能">
          {toolEntries.map((item) => (
            <button
              key={item.id}
              type="button"
              data-select-tool={item.id}
              data-tool-title={item.title}
              data-tool-short={item.shortTitle}
              data-tool-action={item.action}
            >
              <span>{item.icon}</span>
              <strong>{item.title}</strong>
              <small>{item.action}</small>
            </button>
          ))}
        </nav>
      </aside>

      <section className="fast-stage" aria-label="大乘首页">
        <header className="fast-topbar">
          <span className="fast-mobile-brand">{brand.name}</span>
          <div>
            <span className="fast-speed-badge">极速 Web</span>
            <button type="button" className="fast-login">登录</button>
          </div>
        </header>

        <section className="fast-hero" data-empty-state>
          <h1>{brand.greeting}</h1>
          <p>{brand.tagline}</p>
          <div className="fast-chips" aria-label="建议问题">
            {heroChips.map((chip) => (
              <button
                key={chip.id}
                type="button"
                data-chip
                data-prompt={chip.prompt}
                data-tool={chip.tool ?? ""}
              >
                <span>{chip.icon}</span>
                {chip.label}
              </button>
            ))}
          </div>
        </section>

        <section className="fast-messages" data-messages aria-live="polite" />

        <section className="fast-composer-wrap" aria-label="输入框">
          <div className="fast-tool-menu" data-tool-menu hidden>
            {toolEntries.map((item) => (
              <button
                key={item.id}
                type="button"
                data-select-tool={item.id}
                data-tool-title={item.title}
                data-tool-short={item.shortTitle}
                data-tool-action={item.action}
              >
                <span>{item.icon}</span>
                <strong>{item.title}</strong>
                <small>{item.description}</small>
              </button>
            ))}
          </div>
          <div className="fast-mode-tabs" data-flashcard-mode-bar hidden aria-label="闪卡制卡模式">
            {flashcardModes.map((item) => (
              <button
                key={item.id}
                type="button"
                data-select-card-mode={item.id}
                data-card-mode-title={item.title}
                data-card-mode-short={item.shortTitle}
              >
                <strong>{item.title}</strong>
                <small>{item.description}</small>
              </button>
            ))}
          </div>
          <form className="fast-composer" data-composer-form>
            <button className="fast-plus" type="button" data-toggle-menu aria-label="打开功能">
              +
            </button>
            <textarea
              data-composer-input
              rows={1}
              maxLength={1800}
              placeholder={brand.inputPlaceholder}
              aria-label={brand.inputPlaceholder}
            />
            <button className="fast-mode" type="button" data-current-mode hidden />
            <button className="fast-send" type="submit" aria-label="发送">
              ➤
            </button>
          </form>
        </section>
      </section>

      <aside className="fast-tool-panel" aria-label="功能状态">
        <section>
          <h2>全球法布施</h2>
          <p>只保留首页轻量流程，首屏不加载 App 专属页面。</p>
          <pre data-global-log>等待输入正文后生成全球法布施清单。</pre>
          <div className="fast-region-list" aria-hidden="true">
            {regions.map((region) => (
              <span key={region} data-region={region}>{region}</span>
            ))}
          </div>
        </section>
        <section>
          <h2>背诵闪卡</h2>
          <p data-card-count>暂无卡片</p>
          <div className="fast-card" data-card-wrap />
          <ul>
            {flashcardPrinciples.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </section>
      </aside>

      <script src={siteHref("/fast-home.js")} defer />
    </main>
  );
}
