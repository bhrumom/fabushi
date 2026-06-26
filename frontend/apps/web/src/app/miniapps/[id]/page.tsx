const miniApps: Record<
  string,
  {
    title: string;
    subtitle: string;
    accent: string;
    actions: Array<{ label: string; method: string; params?: Record<string, string> }>;
  }
> = {
  "official.global-dharma": {
    title: "全球法布施",
    subtitle: "准备内容、读取发送状态，并从宿主启动全球法布施。",
    accent: "#4CAF7A",
    actions: [
      {
        label: "读取发送状态",
        method: "dharma.getSendStatus",
      },
      {
        label: "准备示例内容",
        method: "dharma.prepareContent",
        params: {
          title: "小程序示例法布施",
          text: "愿以此善法内容，广结善缘，利益有情。",
        },
      },
    ],
  },
  "official.flashcards": {
    title: "背诵闪卡制作",
    subtitle: "小程序面板负责收集内容和模式，制卡由宿主统一执行。",
    accent: "#7E57C2",
    actions: [
      {
        label: "查看宿主能力",
        method: "app.getCapabilities",
      },
      {
        label: "请求制卡能力",
        method: "flashcards.createDeck",
        params: {
          title: "示例闪卡",
          text: "色不異空，空不異色。",
        },
      },
    ],
  },
  "official.platform-publish": {
    title: "法布施到平台",
    subtitle: "生成发布草稿，并通过宿主打开平台入口。",
    accent: "#FF9F43",
    actions: [
      {
        label: "创建发布草稿",
        method: "platformPublish.createDraft",
        params: {
          title: "法布施草稿",
          text: "愿以清净文字分享善法，令见闻者得安乐。",
        },
      },
    ],
  },
  "official.bot-father": {
    title: "机器人之父",
    subtitle: "通过对话生成个人沙箱小程序，并在 App 内立即打开。",
    accent: "#3D8BFF",
    actions: [
      {
        label: "读取上下文",
        method: "app.getContext",
      },
      {
        label: "请机器人说明流程",
        method: "bot.sendMessage",
        params: {
          message: "请说明如何通过机器人之父生成一个小程序。",
        },
      },
    ],
  },
};

type MiniAppPageProps = {
  params: Promise<{ id: string }>;
};

export default async function MiniAppPage({ params }: MiniAppPageProps) {
  const { id } = await params;
  const app = miniApps[id] ?? {
    title: "个人小程序",
    subtitle: "这是一个由 Fabushi 宿主加载的小程序面板。",
    accent: "#3390EC",
    actions: [{ label: "读取上下文", method: "app.getContext" }],
  };

  return (
    <main
      style={{
        minHeight: "100vh",
        background: "#0f1722",
        color: "#fff",
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
        padding: 20,
      }}
    >
      <section
        style={{
          border: "1px solid #263445",
          background: "#17212b",
          borderRadius: 16,
          padding: 18,
          marginBottom: 14,
        }}
      >
        <div
          style={{
            width: 42,
            height: 42,
            borderRadius: 12,
            background: app.accent,
            marginBottom: 12,
          }}
        />
        <h1 style={{ margin: "0 0 8px", fontSize: 24 }}>{app.title}</h1>
        <p style={{ margin: 0, color: "#91A3B7", lineHeight: 1.6 }}>
          {app.subtitle}
        </p>
      </section>

      <section
        style={{
          border: "1px solid #263445",
          background: "#17212b",
          borderRadius: 16,
          padding: 16,
        }}
      >
        <div style={{ display: "flex", flexWrap: "wrap", gap: 10 }}>
          {app.actions.map((action) => (
            <button
              key={action.label}
              data-method={action.method}
              data-params={JSON.stringify(action.params ?? {})}
              style={{
                border: 0,
                borderRadius: 999,
                padding: "10px 14px",
                background: app.accent,
                color: "#fff",
                fontWeight: 800,
              }}
            >
              {action.label}
            </button>
          ))}
        </div>
        <pre
          id="output"
          style={{
            marginTop: 14,
            whiteSpace: "pre-wrap",
            color: "#9EC7FF",
            lineHeight: 1.5,
          }}
        >
          等待宿主 API 调用...
        </pre>
      </section>

      <script
        dangerouslySetInnerHTML={{
          __html: `
const output = document.getElementById("output");
async function callHost(method, params) {
  if (!window.FabushiMiniApp) {
    output.textContent = "宿主 SDK 尚未就绪";
    return;
  }
  const result = await window.FabushiMiniApp.invoke(method, params || {});
  output.textContent = JSON.stringify(result, null, 2);
}
document.querySelectorAll("button[data-method]").forEach((button) => {
  button.addEventListener("click", () => {
    callHost(button.dataset.method, JSON.parse(button.dataset.params || "{}"));
  });
});
window.addEventListener("fabushi-miniapp-ready", () => callHost("app.getContext"));
`,
        }}
      />
    </main>
  );
}
