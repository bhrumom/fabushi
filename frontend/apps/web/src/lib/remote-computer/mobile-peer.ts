import type { ComputerAction } from "../mahayana-host/contracts";
import type { MobileControlSession, RemoteComputerApi, RemoteSignal } from "./remote-api";
import { NativeRustDeskController, validateNativeRustDeskBootstrap } from "./native-rustdesk-controller";

const CHANNEL_LABEL = "fabushi-computer-v1";
const SIGNAL_POLL_MS = 650;
const FRAME_TIMEOUT_MS = 15_000;
const MAX_FRAME_CHUNKS = 2_048;
const MAX_FRAME_CHUNK_CHARS = 64 * 1024;
const MAX_FRAME_BASE64_CHARS = 32 * 1024 * 1024;
const MAX_PENDING_REMOTE_CANDIDATES = 256;
const MAX_AI_PROMPT_CHARS = 20_000;
const MAX_PENDING_AI_REQUESTS = 16;
const AI_ACK_TIMEOUT_MS = 30_000;
const MAX_PENDING_FRAMES = 4;
const MAX_DESKTOP_MESSAGE_CHARS = 128 * 1024;

export interface RemoteFrame {
  dataUrl: string;
  width?: number;
  height?: number;
  capturedAtMs: number;
}

export interface MobilePeerState {
  phase: "idle" | "connecting" | "connected" | "closed" | "failed";
  session?: MobileControlSession;
  peerState?: RTCPeerConnectionState;
  channelState?: RTCDataChannelState;
  error?: string;
}

export interface MobileRemoteComputerPeerOptions {
  api: RemoteComputerApi;
  deviceId: string;
  clientId: string;
  clientToken: string;
  onState?: (state: MobilePeerState) => void;
  onFrame?: (frame: RemoteFrame) => void;
  onError?: (message: string) => void;
  onAiAck?: (accepted: boolean, message?: string) => void;
}

interface PendingFrame {
  mime: string;
  width?: number;
  height?: number;
  capturedAtMs: number;
  totalChunks: number;
  chunks: string[];
  receivedChars: number;
  timer: number;
}

type DesktopMessage =
  | { type: "computer.hello"; protocol: number; deviceId: string; sessionId: string; generation?: number }
  | { type: "computer.ack"; id: string; actionsExecuted?: number }
  | { type: "computer.ai.ack"; requestId: string; accepted: boolean; operationId?: string; agentId?: string; error?: string }
  | { type: "computer.error"; id?: string; message: string }
  | { type: "computer.frame.begin"; id: string; mime: string; width?: number; height?: number; capturedAtMs: number; totalChunks: number }
  | { type: "computer.frame.chunk"; id: string; index: number; data: string }
  | { type: "computer.frame.end"; id: string }
  | { type: "computer.closed" }
  | { type: "rustdesk.bootstrap"; protocol: 1; sessionId: string; peerId: string; password: string; forceRelay: boolean; grant: MobileControlSession["permissions"] }
  | { type: "pong"; id?: string; at: number };

function messageId(prefix: string): string {
  const suffix = typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  return `${prefix}-${suffix}`;
}

export class MobileRemoteComputerPeer {
  private readonly api: RemoteComputerApi;
  private readonly deviceId: string;
  private readonly clientId: string;
  private readonly clientToken: string;
  private readonly onState?: MobileRemoteComputerPeerOptions["onState"];
  private readonly onFrame?: MobileRemoteComputerPeerOptions["onFrame"];
  private readonly onError?: MobileRemoteComputerPeerOptions["onError"];
  private readonly onAiAck?: MobileRemoteComputerPeerOptions["onAiAck"];
  private state: MobilePeerState = { phase: "idle" };
  private peer?: RTCPeerConnection;
  private channel?: RTCDataChannel;
  private session?: MobileControlSession;
  private signalCursor = 0;
  private signalTimer?: number;
  private closePromise?: Promise<void>;
  private closed = false;
  private drainingSignals = false;
  private serverReady = false;
  private snapshotPending = false;
  private pendingRemoteCandidates: RTCIceCandidateInit[] = [];
  private pendingFrames = new Map<string, PendingFrame>();
  private pendingAiRequests = new Map<string, number>();
  private readonly nativeRustDesk: NativeRustDeskController;

  constructor(options: MobileRemoteComputerPeerOptions) {
    this.api = options.api;
    this.deviceId = options.deviceId;
    this.clientId = options.clientId;
    this.clientToken = options.clientToken;
    this.onState = options.onState;
    this.onFrame = options.onFrame;
    this.onError = options.onError;
    this.onAiAck = options.onAiAck;
    this.nativeRustDesk = new NativeRustDeskController({
      onFrame: (frame) => this.onFrame?.(frame),
      onError: (message) => this.onError?.(message),
      onReady: () => this.update({ phase: "connected", session: this.session }),
    });
  }

  snapshot(): MobilePeerState {
    return { ...this.state };
  }

  private update(patch: Partial<MobilePeerState>): void {
    this.state = { ...this.state, ...patch };
    this.onState?.(this.snapshot());
  }

  async connect(): Promise<void> {
    if (this.state.phase === "connecting" || this.state.phase === "connected") return;
    if (this.closePromise) await this.closePromise;
    this.closed = false;
    this.closePromise = undefined;
    this.drainingSignals = false;
    this.serverReady = false;
    this.snapshotPending = false;
    this.signalCursor = 0;
    this.pendingRemoteCandidates = [];
    for (const timer of this.pendingAiRequests.values()) window.clearTimeout(timer);
    this.pendingAiRequests.clear();
    this.update({ phase: "connecting", error: undefined });
    try {
      const session = await this.api.createControlSession(this.deviceId, this.clientId, this.clientToken);
      this.session = session;
      const peer = new RTCPeerConnection({ iceServers: session.iceServers });
      this.peer = peer;
      const channel = peer.createDataChannel(CHANNEL_LABEL, { ordered: true });
      this.channel = channel;
      this.configureChannel(channel);

      peer.onicecandidate = (event) => {
        if (!event.candidate || this.closed || !this.session) return;
        void this.api.signal(this.session, "ice", event.candidate.toJSON()).catch((cause) => this.fail(cause));
      };
      peer.onconnectionstatechange = () => {
        this.update({ peerState: peer.connectionState });
        if (["failed", "disconnected"].includes(peer.connectionState)) this.fail(new Error("WebRTC 连接失败"));
        if (peer.connectionState === "closed" && !this.closed) this.fail(new Error("WebRTC 连接已关闭"));
      };

      const offer = await peer.createOffer();
      await peer.setLocalDescription(offer);
      await this.api.signal(session, "offer", peer.localDescription?.toJSON() ?? offer);
      this.signalTimer = window.setInterval(() => void this.drainSignals(), SIGNAL_POLL_MS);
      await this.drainSignals();
    } catch (cause) {
      this.fail(cause);
      await this.closePromise;
      throw cause;
    }
  }

  async disconnect(): Promise<void> {
    if (this.closed) {
      await this.closePromise;
      return;
    }
    this.closed = true;
    const session = this.releaseTransport(true);
    this.closePromise = this.closeServerSession(session);
    await this.closePromise;
    this.update({ phase: "closed", channelState: "closed", peerState: "closed", session: undefined });
  }

  private releaseTransport(sendDisconnect: boolean): MobileControlSession | undefined {
    if (this.signalTimer) window.clearInterval(this.signalTimer);
    this.signalTimer = undefined;
    for (const frame of this.pendingFrames.values()) window.clearTimeout(frame.timer);
    this.pendingFrames.clear();
    for (const timer of this.pendingAiRequests.values()) window.clearTimeout(timer);
    this.pendingAiRequests.clear();
    const session = this.session;
    const channel = this.channel;
    if (sendDisconnect && channel?.readyState === "open") {
      try { channel.send(JSON.stringify({ type: "disconnect", id: messageId("disconnect") })); } catch { /* peer may already be gone */ }
    }
    try { channel?.close(); } catch { /* no-op */ }
    try { this.peer?.close(); } catch { /* no-op */ }
    this.channel = undefined;
    this.peer = undefined;
    this.session = undefined;
    this.serverReady = false;
    this.snapshotPending = false;
    this.drainingSignals = false;
    this.pendingRemoteCandidates = [];
    void this.nativeRustDesk.close();
    return session;
  }

  private async closeServerSession(session?: MobileControlSession): Promise<void> {
    if (!session) return;
    try { await this.api.signal(session, "close", { closed: true }); } catch { /* TTL backstop */ }
    try { await this.api.closeSession(session); } catch { /* TTL backstop */ }
  }

  requestSnapshot(): string {
    if (this.nativeRustDesk.active) return "rustdesk-streaming";
    if (this.snapshotPending) return "snapshot-pending";
    const id = messageId("snapshot");
    this.snapshotPending = true;
    try {
      this.send({ type: "computer.snapshot.request", id });
    } catch (cause) {
      this.snapshotPending = false;
      throw cause;
    }
    return id;
  }

  sendAction(action: ComputerAction, then: ComputerAction[] = []): string {
    const id = messageId("action");
    if (this.nativeRustDesk.active && then.length === 0 && this.nativeRustDesk.supportsAction(action)) {
      void this.nativeRustDesk.sendComputerAction(action).catch((cause) => this.onError?.(cause instanceof Error ? cause.message : String(cause)));
      return id;
    }
    this.send({ type: "computer.action", id, action, then });
    return id;
  }

  sendAiRequest(prompt: string, agentId?: string): string {
    const normalized = prompt.trim();
    if (!normalized) throw new Error("请输入要交给 AI 的任务");
    if (normalized.length > MAX_AI_PROMPT_CHARS) throw new Error("AI 任务内容过长");
    if (this.pendingAiRequests.size >= MAX_PENDING_AI_REQUESTS) throw new Error("等待确认的 AI 任务过多");
    const id = messageId("ai");
    const timer = window.setTimeout(() => {
      if (!this.pendingAiRequests.delete(id)) return;
      this.onError?.("AI 任务确认超时，请检查电脑连接后重试。");
    }, AI_ACK_TIMEOUT_MS);
    this.pendingAiRequests.set(id, timer);
    try {
      this.send({ type: "computer.ai.request", requestId: id, prompt: normalized, agentId });
    } catch (cause) {
      window.clearTimeout(timer);
      this.pendingAiRequests.delete(id);
      throw cause;
    }
    return id;
  }

  ping(): void {
    this.send({ type: "ping", id: messageId("ping") });
  }

  private send(value: unknown): void {
    const channel = this.channel;
    if (!channel || channel.readyState !== "open") throw new Error("远程控制通道尚未连接");
    channel.send(JSON.stringify(value));
  }

  private configureChannel(channel: RTCDataChannel): void {
    channel.onopen = () => {
      this.update({
        phase: this.serverReady ? "connected" : "connecting",
        channelState: channel.readyState,
        session: this.session,
      });
      if (this.serverReady) this.requestSnapshot();
    };
    channel.onclose = () => {
      if (!this.closed) this.fail(new Error("远程控制通道已断开"));
    };
    channel.onerror = () => this.fail(new Error("远程控制 DataChannel 出错"));
    channel.onmessage = (event) => {
      if (typeof event.data !== "string") return;
      if (event.data.length > MAX_DESKTOP_MESSAGE_CHARS) {
        this.fail(new Error("桌面端消息超过安全大小限制"));
        return;
      }
      let message: DesktopMessage;
      try {
        const decoded: unknown = JSON.parse(event.data);
        if (!decoded || typeof decoded !== "object" || Array.isArray(decoded) || typeof (decoded as { type?: unknown }).type !== "string") {
          throw new Error("invalid desktop message");
        }
        message = decoded as DesktopMessage;
      } catch {
        this.fail(new Error("桌面端发送了无效的远程控制消息"));
        return;
      }
      this.handleDesktopMessage(message);
    };
  }

  private handleDesktopMessage(message: DesktopMessage): void {
    if (message.type === "computer.hello") {
      const expectedSessionId = this.session?.sessionId;
      if (message.protocol !== 1 || message.deviceId !== this.deviceId || !expectedSessionId || message.sessionId !== expectedSessionId) {
        this.fail(new Error("桌面端远程会话身份不匹配"));
      }
      return;
    }
    if (message.type === "rustdesk.bootstrap") {
      const session = this.session;
      if (!session) return;
      const bootstrap = validateNativeRustDeskBootstrap(message, session.sessionId, session.permissions);
      if (!bootstrap) {
        this.onError?.("RustDesk bootstrap failed session or permission validation");
        return;
      }
      void this.nativeRustDesk.connect(bootstrap).catch((cause) => {
        this.onError?.(cause instanceof Error ? cause.message : String(cause));
      });
      return;
    }
    if (message.type === "computer.ai.ack") {
      if (typeof message.requestId !== "string" || typeof message.accepted !== "boolean") return;
      const timer = this.pendingAiRequests.get(message.requestId);
      if (timer === undefined) return;
      window.clearTimeout(timer);
      this.pendingAiRequests.delete(message.requestId);
      this.onAiAck?.(message.accepted, typeof message.error === "string" ? message.error : undefined);
      return;
    }
    if (message.type === "computer.error") {
      this.snapshotPending = false;
      this.onError?.(typeof message.message === "string" ? message.message : "桌面端返回了无效错误消息");
      return;
    }
    if (message.type === "computer.closed") {
      void this.disconnect();
      return;
    }
    if (message.type === "computer.frame.begin") {
      const totalChunks = Number.isInteger(message.totalChunks) ? message.totalChunks : 0;
      const validMime = typeof message.mime === "string" && /^(image\/(png|jpeg|webp))$/i.test(message.mime);
      const validDimensions = [message.width, message.height].every((value) => value === undefined || (Number.isFinite(value) && Number(value) > 0 && Number(value) <= 16_384));
      const validCapturedAt = Number.isFinite(message.capturedAtMs) && message.capturedAtMs >= 0;
      if (typeof message.id !== "string" || !message.id || message.id.length > 200 || !validMime || !validDimensions || !validCapturedAt || totalChunks < 1 || totalChunks > MAX_FRAME_CHUNKS) {
        if (typeof message.id === "string") this.discardFrame(message.id, "远程屏幕帧元数据无效");
        else {
          this.snapshotPending = false;
          this.onError?.("远程屏幕帧元数据无效");
        }
        return;
      }
      const previous = this.pendingFrames.get(message.id);
      if (!previous && this.pendingFrames.size >= MAX_PENDING_FRAMES) {
        this.fail(new Error("等待处理的远程屏幕帧过多"));
        return;
      }
      if (previous) window.clearTimeout(previous.timer);
      const timer = window.setTimeout(() => {
        this.pendingFrames.delete(message.id);
        this.snapshotPending = false;
        this.onError?.("远程屏幕帧接收超时");
      }, FRAME_TIMEOUT_MS);
      this.pendingFrames.set(message.id, {
        mime: message.mime,
        width: message.width,
        height: message.height,
        capturedAtMs: message.capturedAtMs,
        totalChunks,
        chunks: new Array(totalChunks),
        receivedChars: 0,
        timer,
      });
      return;
    }
    if (message.type === "computer.frame.chunk") {
      const frame = this.pendingFrames.get(message.id);
      if (!frame || !Number.isInteger(message.index) || message.index < 0 || message.index >= frame.totalChunks || typeof message.data !== "string") return;
      if (message.data.length > MAX_FRAME_CHUNK_CHARS || frame.receivedChars + message.data.length > MAX_FRAME_BASE64_CHARS) {
        this.discardFrame(message.id, "远程屏幕帧超过安全大小限制");
        return;
      }
      if (typeof frame.chunks[message.index] !== "string") {
        frame.chunks[message.index] = message.data;
        frame.receivedChars += message.data.length;
      }
      return;
    }
    if (message.type === "computer.frame.end") {
      const frame = this.pendingFrames.get(message.id);
      if (!frame || frame.chunks.some((chunk) => typeof chunk !== "string")) return;
      window.clearTimeout(frame.timer);
      this.pendingFrames.delete(message.id);
      this.snapshotPending = false;
      this.onFrame?.({
        dataUrl: `data:${frame.mime};base64,${frame.chunks.join("")}`,
        width: frame.width,
        height: frame.height,
        capturedAtMs: frame.capturedAtMs,
      });
    }
  }

  private async drainSignals(): Promise<void> {
    const session = this.session;
    const peer = this.peer;
    if (!session || !peer || this.closed || this.drainingSignals) return;
    this.drainingSignals = true;
    try {
      const drained = await this.api.drainSignals(session, this.signalCursor);
      const nextCursor = Math.max(this.signalCursor, drained.lastSignalId ?? this.signalCursor);
      for (const signal of drained.signals) await this.applySignal(signal);
      this.signalCursor = nextCursor;
    } catch (cause) {
      if (!this.closed) this.fail(cause);
    } finally {
      this.drainingSignals = false;
    }
  }

  private async applySignal(signal: RemoteSignal): Promise<void> {
    const peer = this.peer;
    if (!peer || this.closed) return;
    if (signal.kind === "answer") {
      if (!peer.remoteDescription) {
        await peer.setRemoteDescription(signal.payload as RTCSessionDescriptionInit);
        for (const candidate of this.pendingRemoteCandidates.splice(0)) {
          await peer.addIceCandidate(candidate);
        }
      }
      return;
    }
    if (signal.kind === "ice") {
      const candidate = signal.payload as RTCIceCandidateInit;
      if (peer.remoteDescription) {
        await peer.addIceCandidate(candidate);
      } else {
        if (this.pendingRemoteCandidates.length >= MAX_PENDING_REMOTE_CANDIDATES) {
          throw new Error("等待处理的 ICE candidate 过多");
        }
        this.pendingRemoteCandidates.push(candidate);
      }
      return;
    }
    if (signal.kind === "ready") {
      this.serverReady = true;
      const channel = this.channel;
      this.update({
        phase: channel?.readyState === "open" ? "connected" : "connecting",
        channelState: channel?.readyState,
        session: this.session,
      });
      if (channel?.readyState === "open") this.requestSnapshot();
      return;
    }
    if (signal.kind === "close") {
      await this.disconnect();
    }
  }

  private discardFrame(id: string, message: string): void {
    const frame = this.pendingFrames.get(id);
    if (frame) window.clearTimeout(frame.timer);
    this.pendingFrames.delete(id);
    this.snapshotPending = false;
    this.onError?.(message);
  }

  private fail(cause: unknown): void {
    if (this.closed || this.state.phase === "failed") return;
    const message = cause instanceof Error ? cause.message : String(cause);
    this.closed = true;
    const session = this.releaseTransport(false);
    this.closePromise = this.closeServerSession(session);
    this.update({ phase: "failed", error: message, channelState: "closed", peerState: "closed", session: undefined });
    this.onError?.(message);
  }
}
