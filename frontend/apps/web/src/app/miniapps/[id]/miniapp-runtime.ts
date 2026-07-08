import { fbApp, MiniAppHostError } from "@fabushi/miniapp-sdk";

export { fbApp, MiniAppHostError };

export async function bootMiniApp(miniAppId: string, title: string): Promise<boolean> {
  const hostReady = await fbApp.ready({ timeoutMs: 8000, miniAppId });
  if (!hostReady) {
    fbApp.showFallback({
      mode: "open-in-app",
      title: "请在全球法布施 App 内打开",
      message: `${title} 需要宿主能力；普通浏览器可预览界面，但本地执行、支付和文件能力会被降级或禁用。`,
      appLink: `fabushi://miniapps/${encodeURIComponent(miniAppId)}`,
      ctaLabel: "在 App 内打开",
    });
  }
  return hostReady;
}

export function hostErrorMessage(error: unknown, fallback = "宿主调用失败"): string {
  if (error instanceof Error && error.message) return error.message;
  return fallback;
}
