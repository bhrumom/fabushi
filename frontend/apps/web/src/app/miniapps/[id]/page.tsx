import GlobalDharmaApp from "./GlobalDharmaApp";
import FlashcardsApp from "./FlashcardsApp";
import PlatformPublishApp from "./PlatformPublishApp";

type MiniAppPageProps = {
  params: Promise<{ id: string }>;
};

export default async function MiniAppPage({ params }: MiniAppPageProps) {
  const { id } = await params;

  let AppContent;
  switch (id) {
    case "official.global-dharma":
      AppContent = <GlobalDharmaApp />;
      break;
    case "official.flashcards":
      AppContent = <FlashcardsApp />;
      break;
    case "official.platform-publish":
      AppContent = <PlatformPublishApp />;
      break;
    default:
      // Fallback for bot-father or unknown apps
      AppContent = (
        <div className="ma-card" style={{ "--accent-start": "#3390EC" } as any}>
          <h1 className="ma-header-title">通用小程序 ({id})</h1>
          <p className="ma-header-subtitle">这是一个通用的沙箱小程序环境。</p>
          <pre id="output" className="ma-log-box" style={{ marginTop: 24 }}>等待宿主 API 调用...</pre>
          <script dangerouslySetInnerHTML={{
            __html: `
              const output = document.getElementById("output");
              window.addEventListener("fabushi-miniapp-ready", async () => {
                output.textContent += "\\n\\nSDK 就绪！正在读取上下文...\\n";
                const res = await (window as any).FabushiMiniApp.invoke("app.getContext");
                output.textContent += JSON.stringify(res, null, 2);
              });
            `
          }} />
        </div>
      );
  }

  return (
    <main className="ma-container">
      {AppContent}
    </main>
  );
}
