import type { AnyRecord, ConfirmOptions, MainButtonOptions, PopupOptions } from "./types";
import type { HostInvoker } from "./auth";

export class UiModule {
  private readonly invoke: HostInvoker;

  constructor(invoke: HostInvoker) {
    this.invoke = invoke;
  }

  showPopup(options: PopupOptions): Promise<AnyRecord> {
    return this.invoke("ui.showPopup", options);
  }

  showConfirm(options: ConfirmOptions): Promise<{ confirmed: boolean }> {
    return this.invoke("ui.showConfirm", options);
  }

  setMainButton(options: MainButtonOptions): Promise<AnyRecord> {
    return this.invoke("ui.setMainButton", options);
  }

  setBackButton(visible: boolean): Promise<AnyRecord> {
    return this.invoke("ui.setBackButton", { visible });
  }

  hapticImpact(style: "light" | "medium" | "heavy" | "selection" = "light"): Promise<AnyRecord> {
    return this.invoke("ui.hapticImpact", { style });
  }

  openLink(url: string, options: AnyRecord = {}): Promise<AnyRecord> {
    return this.invoke("browser.open", { url, ...options });
  }

  close(reason?: string): Promise<AnyRecord> {
    return this.invoke("ui.close", { reason });
  }
}
