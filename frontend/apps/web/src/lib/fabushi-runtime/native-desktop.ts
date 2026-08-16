export type NativeDesktopEvent = "window-state" | "theme-changed";

export interface NativeDesktopBridge {
  invoke<T>(method: string, params?: Record<string, unknown>): Promise<T>;
  subscribe(listeners: Partial<Record<NativeDesktopEvent, (payload: unknown) => void>>): () => void;
}

declare global {
  interface Window {
    fabushiNative?: NativeDesktopBridge;
  }
}

export function nativeDesktopBridge(): NativeDesktopBridge | null {
  if (typeof window === "undefined") return null;
  return typeof window.fabushiNative?.invoke === "function" ? window.fabushiNative : null;
}

export async function nativeOnboardingSeen(): Promise<boolean | null> {
  const bridge = nativeDesktopBridge();
  if (!bridge) return null;
  return bridge.invoke<boolean>("getOnboardingSeen").catch(() => null);
}

export function rememberNativeOnboarding(): void {
  const bridge = nativeDesktopBridge();
  if (!bridge) return;
  void bridge.invoke<boolean>("setOnboardingSeen", { seen: true }).catch(() => undefined);
}

export function syncNativeTheme(preference: "system" | "light" | "dark"): void {
  const bridge = nativeDesktopBridge();
  if (!bridge) return;
  void bridge.invoke("setThemePreference", { preference }).catch(() => undefined);
}
