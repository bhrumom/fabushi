export {};

declare global {
  interface Window {
    fabushi: {
      invoke<T = unknown>(method: string, params?: Record<string, unknown>): Promise<T>;
      pickFile(): Promise<string | null>;
      notify(title: string, body: string): Promise<boolean>;
      openExternal(url: string): Promise<boolean>;
    };
  }
}
