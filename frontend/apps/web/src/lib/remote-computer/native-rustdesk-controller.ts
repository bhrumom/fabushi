import type { ComputerAction, RemoteComputerPermissions } from "../mahayana-host/contracts";
import { invokeNativeDesktop, subscribeNativeDesktopEvents } from "../fabushi-runtime/native-desktop";

const MAX_FRAME_BYTES = 64 * 1024 * 1024;
const MAX_FRAME_CHUNKS = 512;
const MAX_HEX_CHARS = MAX_FRAME_BYTES * 2;
const PEER_ID = /^[A-Za-z0-9._:-]{1,160}$/;
const SESSION_ID = /^[A-Za-z0-9._:-]{1,160}$/;

export interface NativeRustDeskBootstrap {
  protocol: 1;
  sessionId: string;
  peerId: string;
  password: string;
  forceRelay: boolean;
  grant: RemoteComputerPermissions;
}

export interface NativeRustDeskFrame {
  dataUrl: string;
  width: number;
  height: number;
  capturedAtMs: number;
}

interface NativeRustDeskControllerOptions {
  onFrame?: (frame: NativeRustDeskFrame) => void;
  onError?: (message: string) => void;
  onReady?: () => void;
  onClosed?: () => void;
}

interface SidecarEvent {
  protocol?: unknown;
  type?: unknown;
  sessionId?: unknown;
  detail?: unknown;
}

interface PendingRgbaFrame {
  width: number;
  height: number;
  bytes: number;
  chunks: number;
  values: string[];
  receivedHexChars: number;
}

function record(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function validGrant(value: unknown): value is RemoteComputerPermissions {
  const grant = record(value);
  return grant.display === true
    && [grant.input, grant.clipboard, grant.fileTransfer, grant.audio].every((item) => typeof item === "boolean");
}

export function validateNativeRustDeskBootstrap(value: unknown, expectedSessionId: string, granted: RemoteComputerPermissions): NativeRustDeskBootstrap | null {
  const input = record(value);
  const grant = input.grant;
  if (input.protocol !== 1
    || input.sessionId !== expectedSessionId
    || typeof input.peerId !== "string"
    || !PEER_ID.test(input.peerId)
    || typeof input.password !== "string"
    || input.password.length < 6
    || input.password.length > 32
    || /\s/.test(input.password)
    || typeof input.forceRelay !== "boolean"
    || !validGrant(grant)) return null;
  const requested = grant as RemoteComputerPermissions;
  if ((requested.input && !granted.input)
    || (requested.clipboard && !granted.clipboard)
    || (requested.fileTransfer && !granted.fileTransfer)
    || (requested.audio && !granted.audio)) return null;
  return {
    protocol: 1,
    sessionId: input.sessionId as string,
    peerId: input.peerId,
    password: input.password,
    forceRelay: input.forceRelay,
    grant: requested,
  };
}

function hexToBytes(chunks: string[], expectedBytes: number): Uint8ClampedArray | null {
  const joined = chunks.join("");
  if (joined.length !== expectedBytes * 2 || joined.length > MAX_HEX_CHARS || !/^[0-9a-f]*$/i.test(joined)) return null;
  const bytes = new Uint8ClampedArray(expectedBytes);
  for (let index = 0; index < expectedBytes; index += 1) {
    bytes[index] = Number.parseInt(joined.slice(index * 2, index * 2 + 2), 16);
  }
  return bytes;
}

function rgbaDataUrl(frame: PendingRgbaFrame): string | null {
  if (typeof document === "undefined") return null;
  if (frame.width <= 0 || frame.height <= 0 || frame.width > 16_384 || frame.height > 16_384) return null;
  if (frame.bytes !== frame.width * frame.height * 4) return null;
  const pixels = hexToBytes(frame.values, frame.bytes);
  if (!pixels) return null;
  const canvas = document.createElement("canvas");
  canvas.width = frame.width;
  canvas.height = frame.height;
  const context = canvas.getContext("2d", { alpha: false });
  if (!context) return null;
  context.putImageData(new ImageData(pixels, frame.width, frame.height), 0, 0);
  return canvas.toDataURL("image/png");
}

export class NativeRustDeskController {
  private readonly options: NativeRustDeskControllerOptions;
  private sessionId?: string;
  private grant?: RemoteComputerPermissions;
  private unsubscribe?: () => void;
  private frame?: PendingRgbaFrame;
  private connected = false;

  constructor(options: NativeRustDeskControllerOptions = {}) {
    this.options = options;
  }

  get active(): boolean {
    return Boolean(this.sessionId && this.connected);
  }

  supportsAction(action: ComputerAction): boolean {
    return ["click", "move", "drag", "type", "key"].includes(action.action);
  }

  async connect(bootstrap: NativeRustDeskBootstrap): Promise<boolean> {
    if (!SESSION_ID.test(bootstrap.sessionId) || !validGrant(bootstrap.grant)) return false;
    const status = await invokeNativeDesktop<{ available?: boolean }>("getRustDeskStatus").catch(() => null);
    if (!status?.available) return false;
    await this.close();
    this.sessionId = bootstrap.sessionId;
    this.grant = Object.freeze({ ...bootstrap.grant });
    this.connected = false;
    this.unsubscribe = subscribeNativeDesktopEvents({
      "rustdesk-sidecar-event": (payload) => this.handleEvent(payload),
      "rustdesk-sidecar-exit": (payload) => this.handleExit(payload),
    } as never);
    try {
      await invokeNativeDesktop("openRustDeskSession", {
        sessionId: bootstrap.sessionId,
        peerId: bootstrap.peerId,
        password: bootstrap.password,
        forceRelay: bootstrap.forceRelay,
        grant: bootstrap.grant,
      });
      return true;
    } catch (cause) {
      await this.close();
      this.options.onError?.(cause instanceof Error ? cause.message : String(cause));
      return false;
    }
  }

  async close(): Promise<void> {
    const sessionId = this.sessionId;
    this.sessionId = undefined;
    this.grant = undefined;
    this.connected = false;
    this.frame = undefined;
    this.unsubscribe?.();
    this.unsubscribe = undefined;
    if (sessionId) {
      await invokeNativeDesktop("closeRustDeskSession", { sessionId }).catch(() => undefined);
    }
  }

  async sendComputerAction(action: ComputerAction): Promise<boolean> {
    const sessionId = this.sessionId;
    const grant = this.grant;
    if (!sessionId || !this.connected || !grant?.input || !this.supportsAction(action)) return false;
    const x = Number.isFinite(action.x) ? Math.round(Number(action.x)) : 0;
    const y = Number.isFinite(action.y) ? Math.round(Number(action.y)) : 0;
    if (action.action === "move") {
      await this.command({ type: "mouse", mask: 0, x, y });
      return true;
    }
    if (action.action === "click") {
      const mask = action.button === "right" ? 2 : action.button === "middle" ? 4 : 1;
      const count = Math.max(1, Math.min(3, Math.trunc(action.count ?? 1)));
      for (let index = 0; index < count; index += 1) {
        await this.command({ type: "mouse", mask, x, y });
        await this.command({ type: "mouse", mask: 0, x, y });
      }
      return true;
    }
    if (action.action === "drag") {
      const x2 = Number.isFinite(action.x2) ? Math.round(Number(action.x2)) : x;
      const y2 = Number.isFinite(action.y2) ? Math.round(Number(action.y2)) : y;
      const mask = action.button === "right" ? 2 : action.button === "middle" ? 4 : 1;
      await this.command({ type: "mouse", mask, x, y });
      for (const point of action.path ?? []) {
        if (Number.isFinite(point.x) && Number.isFinite(point.y)) {
          await this.command({ type: "mouse", mask, x: Math.round(point.x), y: Math.round(point.y) });
        }
      }
      await this.command({ type: "mouse", mask, x: x2, y: y2 });
      await this.command({ type: "mouse", mask: 0, x: x2, y: y2 });
      return true;
    }
    if (action.action === "type") {
      if (typeof action.text !== "string" || !action.text) return false;
      await this.command({ type: "text", text: action.text });
      return true;
    }
    if (action.action === "key") {
      if (typeof action.key !== "string" || !action.key || action.key.length > 80) return false;
      await this.command({ type: "key", name: action.key, press: true });
      return true;
    }
    return false;
  }

  private command(command: Record<string, unknown>): Promise<unknown> {
    if (!this.sessionId) return Promise.reject(new Error("RustDesk session is not active."));
    return invokeNativeDesktop("sendRustDeskCommand", { sessionId: this.sessionId, command });
  }

  private handleExit(_payload: unknown): void {
    if (!this.sessionId) return;
    this.connected = false;
    this.frame = undefined;
    this.options.onError?.("RustDesk provider exited unexpectedly; the Fabushi bootstrap channel remains available for recovery.");
  }

  private handleEvent(payload: unknown): void {
    const event = record(payload) as SidecarEvent;
    if (event.protocol !== "fabushi.rustdesk-sidecar.v1" || event.sessionId !== this.sessionId || typeof event.type !== "string") return;
    const detail = record(event.detail);
    if (event.type === "ready") {
      this.connected = true;
      this.options.onReady?.();
      return;
    }
    if (event.type === "closed" || event.type === "closeSuccess") {
      this.connected = false;
      this.frame = undefined;
      this.options.onClosed?.();
      return;
    }
    if (event.type === "error" || event.type === "status") {
      const message = typeof detail.text === "string"
        ? detail.text
        : typeof detail.code === "string"
          ? detail.code
          : "RustDesk provider reported an error.";
      this.options.onError?.(message);
      return;
    }
    if (event.type === "frameBegin") {
      const width = Number(detail.width);
      const height = Number(detail.height);
      const bytes = Number(detail.bytes);
      const chunks = Number(detail.chunks);
      if (!Number.isSafeInteger(width) || !Number.isSafeInteger(height)
        || !Number.isSafeInteger(bytes) || !Number.isSafeInteger(chunks)
        || width <= 0 || height <= 0 || width > 16_384 || height > 16_384
        || bytes <= 0 || bytes > MAX_FRAME_BYTES || bytes !== width * height * 4
        || chunks <= 0 || chunks > MAX_FRAME_CHUNKS || detail.format !== "rgba") {
        this.frame = undefined;
        this.options.onError?.("RustDesk frame metadata failed validation.");
        return;
      }
      this.frame = { width, height, bytes, chunks, values: new Array(chunks), receivedHexChars: 0 };
      return;
    }
    if (event.type === "frameChunk") {
      const frame = this.frame;
      const index = Number(detail.index);
      const hex = detail.hex;
      if (!frame || !Number.isSafeInteger(index) || index < 0 || index >= frame.chunks || typeof hex !== "string") return;
      if (hex.length > 512 * 1024 || hex.length % 2 !== 0 || !/^[0-9a-f]+$/i.test(hex)
        || frame.receivedHexChars + hex.length > MAX_HEX_CHARS) {
        this.frame = undefined;
        this.options.onError?.("RustDesk frame chunk exceeded safety limits.");
        return;
      }
      if (typeof frame.values[index] !== "string") {
        frame.values[index] = hex;
        frame.receivedHexChars += hex.length;
      }
      return;
    }
    if (event.type === "frameEnd") {
      const frame = this.frame;
      this.frame = undefined;
      if (!frame || frame.values.some((value) => typeof value !== "string")) return;
      const dataUrl = rgbaDataUrl(frame);
      if (!dataUrl) {
        this.options.onError?.("RustDesk frame could not be rendered safely.");
        return;
      }
      this.options.onFrame?.({ dataUrl, width: frame.width, height: frame.height, capturedAtMs: Date.now() });
    }
  }
}
