import type { ComputerAction } from "../mahayana-host/contracts";
import type { MobileControlSession, RemoteComputerApi, RemoteSignal } from "./remote-api";

const CHANNEL_LABEL = "fabushi-computer-v1";
const SIGNAL_POLL_MS = 650;
const FRAME_TIMEOUT_MS = 15_000;

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
  onState?: (state: MobilePeerState) => void;
  onFrame?: (frame: RemoteFrame) => void;
  onError?: (message: string) => void;
}

interface PendingFrame {
  mime: string;
  width?: number;
  height?: number;
  capturedAtMs: number;
  totalChunks: number;
  chunks: string[];
  timer: number;
}

type DesktopMessage =
  | { type: "computer.hello"; protocol: number; deviceId: string; sessionId: string }
  | { type: "computer.ack"; id: string; actionsExecuted?: number }
  | { type: "computer.error"; id?: string; message: string }
  | { type: "computer.frame.begin"; id: string; mime: string; width?: number; height?: number; capturedAtMs: number; totalChunks: number }
  | { type: "computer.frame.chunk"; id: string; index: number; data: string }
  | { type: "computer.frame.end"; id: string }
  | { type: "computer.closed" }
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
  private readonly onState?: MobileRemoteComputerPeerOptions["onState"];
  private readonly onFrame?: MobileRemoteComputerPeerOptions["onFrame"];
  private readonly onError?: MobileRemoteComputerPeerOptions["onError"];
  private state: MobilePeerState = { phase: "idle" };
  private peer?: RTCPeerConnection;
  private channel?: RTCDataChannel;
  private session?: MobileControlSession;
  private signalCursor = 0;
  private signalTimer?: number;
  private closed = false;
  private serverReady = false;
  private snapshotPending = false;
  private pendingRemoteCandidates: RTCIceCandidateInit[] = [];
  private pendingFrames = new Map<string, PendingFrame>();

  constructor(options: MobileRemoteComputerPeerOptions) {
    this.api = options.api;
    this.deviceId = options.deviceId;
    this.clientId = options.clientId;
    this.onState = options.onState;
    this.onFrame = options.onFrame;
    this.onError = options.onError;
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
    this.closed = false;
    this.serverReady = false;
    this.snapshotPending = false;
    this.pendingRemoteCandidates = [];
    this.update({ phase: "connecting", error: undefined });
    const session = await this.api.createControlSession(this.deviceId, this.clientId);
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
      if (peer.connectionState === "failed") this.fail(new Error("WebRTC 连接失败"));
      if (peer.connectionState === "closed") this.update({ phase: "closed" });
    };

    const offer = await peer.createOffer();
    await peer.setLocalDescription(offer);
    await this.api.signal(session, "offer", peer.localDescription?.toJSON() ?? offer);
    this.signalTimer = window.setInterval(() => void this.drainSignals(), SIGNAL_POLL_MS);
    await this.drainSignals();
  }

  async disconnect(): Promise<void> {
    if (this.closed) return;
    this.closed = true;
    if (this.signalTimer) window.clearInterval(this.signalTimer);
    this.signalTimer = undefined;
    for (const frame of this.pendingFrames.values()) window.clearTimeout(frame.timer);
    this.pendingFrames.clear();
    const session = this.session;
    const channel = this.channel;
    if (channel?.readyState === "open") {
      try { channel.send(JSON.stringify({ type: "disconnect", id: messageId("disconnect") })); } catch { /* peer may already be gone */ }
    }
    try { channel?.close(); } catch { /* no-op */ }
    try { this.peer?.close(); } catch { /* no-op */ }
    this.channel = undefined;
    this.peer = undefined;
    this.session = undefined;
    this.serverReady = false;
    this.snapshotPending = false;
    this.pendingRemoteCandidates = [];
    if (session) {
      try { await this.api.signal(session, "close", { closed: true }); } catch { /* TTL backstop */ }
      try { await this.api.closeSession(session); } catch { /* TTL backstop */ }
    }
    this.update({ phase: "closed", channelState: "closed", peerState: "closed", session: undefined });
  }

  requestSnapshot(): string {
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
    this.send({ type: "computer.action", id, action, then });
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
      this.update({ phase: this.closed ? "closed" : "failed", channelState: channel.readyState });
      if (!this.closed) this.fail(new Error("远程控制通道已断开"));
    };
    channel.onerror = () => this.fail(new Error("远程控制 DataChannel 出错"));
    channel.onmessage = (event) => {
      if (typeof event.data !== "string") return;
      let message: DesktopMessage;
      try { message = JSON.parse(event.data) as DesktopMessage; } catch { return; }
      this.handleDesktopMessage(message);
    };
  }

  private handleDesktopMessage(message: DesktopMessage): void {
    if (message.type === "computer.error") {
      this.snapshotPending = false;
      this.onError?.(message.message);
      return;
    }
    if (message.type === "computer.closed") {
      void this.disconnect();
      return;
    }
    if (message.type === "computer.frame.begin") {
      const previous = this.pendingFrames.get(message.id);
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
        totalChunks: Math.max(1, message.totalChunks),
        chunks: new Array(Math.max(1, message.totalChunks)),
        timer,
      });
      return;
    }
    if (message.type === "computer.frame.chunk") {
      const frame = this.pendingFrames.get(message.id);
      if (!frame || message.index < 0 || message.index >= frame.totalChunks) return;
      frame.chunks[message.index] = message.data;
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
    if (!session || !peer || this.closed) return;
    try {
      const drained = await this.api.drainSignals(session, this.signalCursor);
      this.signalCursor = Math.max(this.signalCursor, drained.lastSignalId ?? this.signalCursor);
      for (const signal of drained.signals) await this.applySignal(signal);
    } catch (cause) {
      if (!this.closed) this.fail(cause);
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

  private fail(cause: unknown): void {
    const message = cause instanceof Error ? cause.message : String(cause);
    this.update({ phase: "failed", error: message });
    this.onError?.(message);
  }
}
