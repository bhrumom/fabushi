import type {
  ComputerAction,
  ComputerActionResult,
  ComputerControlTarget,
  ComputerSnapshot,
  RemoteComputerClient,
  RemoteComputerRegistration,
  RemoteComputerSession,
  RemoteComputerSignal,
  RuntimeCommand,
  RuntimeEvent,
} from "../mahayana-host/contracts";
import type { MahayanaHostTransport } from "../mahayana-host/transport";

const DEVICE_ID_STORAGE_KEY = "fabushi-remote-computer-device-id-v1";
const CHANNEL_LABEL = "fabushi-computer-v1";
const SIGNAL_POLL_MS = 650;
const SESSION_POLL_MS = 1_500;
const HEARTBEAT_MS = 20_000;
const REQUEST_TIMEOUT_MS = 20_000;
const FRAME_CHUNK_CHARS = 24 * 1024;
const MAX_BUFFERED_BYTES = 384 * 1024;

export interface RemoteComputerDesktopState {
  running: boolean;
  deviceId: string;
  registration?: RemoteComputerRegistration;
  clients: RemoteComputerClient[];
  sessions: RemoteComputerSession[];
  activeSessionId?: string;
  activeClientId?: string;
  connectionState: RTCPeerConnectionState | "idle";
  channelOpen: boolean;
  error?: string;
}

type RemoteChangedEvent = Extract<RuntimeEvent, { type: "remoteComputer.changed" }>;
type ComputerSnapshotEvent = Extract<RuntimeEvent, { type: "computer.snapshot" }>;
type ComputerResultEvent = Extract<RuntimeEvent, { type: "computer.result" }>;
type RemoteRuntimeCommand = Extract<RuntimeCommand, { type:
  | "remoteComputer.register"
  | "remoteComputer.heartbeat"
  | "remoteComputer.clients"
  | "remoteComputer.clientRevoke"
  | "remoteComputer.sessions"
  | "remoteComputer.sessionActivate"
  | "remoteComputer.sessionClose"
  | "remoteComputer.signal"
  | "remoteComputer.signalDrain"
}>;

interface DesktopPeerOptions {
  transport: MahayanaHostTransport;
  label: string;
  onState?: (state: RemoteComputerDesktopState) => void;
}

interface SessionListPayload {
  deviceId?: string;
  sessions?: RemoteComputerSession[];
  iceServers?: RTCIceServer[];
}

interface SignalDrainPayload {
  sessionId?: string;
  signals?: RemoteComputerSignal[];
  lastSignalId?: number;
}

interface PeerSession {
  session: RemoteComputerSession;
  peer: RTCPeerConnection;
  channel?: RTCDataChannel;
  signalCursor: number;
  signalTimer?: number;
  activated: boolean;
  closing: boolean;
  operationQueue: Promise<void>;
  pendingRemoteCandidates: RTCIceCandidateInit[];
}

type IncomingChannelMessage =
  | { type: "ping"; id?: string }
  | { type: "disconnect"; id?: string }
  | { type: "computer.snapshot.request"; id: string }
  | { type: "computer.action"; id: string; action: ComputerAction; then?: ComputerAction[] };

function objectValue(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function remoteDeviceId(): string {
  if (typeof window === "undefined") return "fabushi-remote-desktop";
  const existing = window.localStorage.getItem(DEVICE_ID_STORAGE_KEY)?.trim();
  if (existing) return existing;
  const suffix = typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const id = `fabushi-mac-${suffix}`;
  window.localStorage.setItem(DEVICE_ID_STORAGE_KEY, id);
  return id;
}

function requestId(prefix: string): string {
  const random = typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  return `${prefix}-${random}`;
}

async function awaitEvent<T extends RuntimeEvent>(
  transport: MahayanaHostTransport,
  command: RuntimeCommand,
  matches: (event: RuntimeEvent) => event is T,
): Promise<T> {
  return await new Promise<T>((resolve, reject) => {
    let settled = false;
    const timeout = window.setTimeout(() => {
      if (settled) return;
      settled = true;
      unsubscribe();
      reject(new Error(`Host request timed out: ${command.type}`));
    }, REQUEST_TIMEOUT_MS);
    const unsubscribe = transport.subscribe((event) => {
      if (settled || !matches(event)) return;
      settled = true;
      window.clearTimeout(timeout);
      unsubscribe();
      resolve(event);
    });
    void transport.execute(command).catch((cause) => {
      if (settled) return;
      settled = true;
      window.clearTimeout(timeout);
      unsubscribe();
      reject(cause);
    });
  });
}

async function remoteRequest(
  transport: MahayanaHostTransport,
  command: RemoteRuntimeCommand,
): Promise<RemoteChangedEvent> {
  return await awaitEvent(
    transport,
    command,
    (event): event is RemoteChangedEvent => event.type === "remoteComputer.changed" && event.requestId === command.requestId,
  );
}

function remoteDesktopTarget(deviceId: string, generation: number): ComputerControlTarget {
  return { protocolVersion: 1, kind: "desktop", deviceId, generation };
}

async function computerSnapshotRequest(
  transport: MahayanaHostTransport,
  sessionId: string,
  target: ComputerControlTarget,
): Promise<ComputerSnapshot> {
  const id = requestId("remote-snapshot");
  const event = await awaitEvent(
    transport,
    { type: "computer.screenshot", requestId: id, origin: "remote-mobile", sessionId, target },
    (candidate): candidate is ComputerSnapshotEvent => candidate.type === "computer.snapshot" && candidate.requestId === id,
  );
  return event.snapshot;
}

async function computerActionRequest(
  transport: MahayanaHostTransport,
  sessionId: string,
  target: ComputerControlTarget,
  action: ComputerAction,
  then: ComputerAction[] = [],
): Promise<ComputerActionResult> {
  const id = requestId("remote-action");
  const event = await awaitEvent(
    transport,
    { type: "computer.action", requestId: id, origin: "remote-mobile", sessionId, target, action, then },
    (candidate): candidate is ComputerResultEvent => candidate.type === "computer.result" && candidate.requestId === id,
  );
  return event.result;
}

async function channelBackpressure(channel: RTCDataChannel): Promise<void> {
  if (channel.bufferedAmount <= MAX_BUFFERED_BYTES) return;
  channel.bufferedAmountLowThreshold = MAX_BUFFERED_BYTES / 2;
  await new Promise<void>((resolve, reject) => {
    const timeout = window.setTimeout(() => {
      cleanup();
      reject(new Error("Remote computer channel backpressure timed out"));
    }, 5_000);
    const onLow = () => {
      cleanup();
      resolve();
    };
    const onClose = () => {
      cleanup();
      reject(new Error("Remote computer channel closed"));
    };
    const cleanup = () => {
      window.clearTimeout(timeout);
      channel.removeEventListener("bufferedamountlow", onLow);
      channel.removeEventListener("close", onClose);
    };
    channel.addEventListener("bufferedamountlow", onLow, { once: true });
    channel.addEventListener("close", onClose, { once: true });
  });
}

async function sendJson(channel: RTCDataChannel, value: unknown): Promise<void> {
  if (channel.readyState !== "open") throw new Error("Remote computer data channel is not open");
  await channelBackpressure(channel);
  channel.send(JSON.stringify(value));
}

async function sendSnapshotFrame(
  channel: RTCDataChannel,
  requestMessageId: string,
  snapshot: ComputerSnapshot,
): Promise<void> {
  const comma = snapshot.dataUrl.indexOf(",");
  if (comma < 0) throw new Error("Computer snapshot data URL is invalid");
  const header = snapshot.dataUrl.slice(0, comma);
  const payload = snapshot.dataUrl.slice(comma + 1);
  const mime = /^data:([^;]+)/.exec(header)?.[1] ?? "image/png";
  const totalChunks = Math.max(1, Math.ceil(payload.length / FRAME_CHUNK_CHARS));
  await sendJson(channel, {
    type: "computer.frame.begin",
    id: requestMessageId,
    mime,
    width: snapshot.width,
    height: snapshot.height,
    capturedAtMs: snapshot.capturedAtMs,
    totalChunks,
  });
  for (let index = 0; index < totalChunks; index += 1) {
    await sendJson(channel, {
      type: "computer.frame.chunk",
      id: requestMessageId,
      index,
      data: payload.slice(index * FRAME_CHUNK_CHARS, (index + 1) * FRAME_CHUNK_CHARS),
    });
  }
  await sendJson(channel, { type: "computer.frame.end", id: requestMessageId });
}

export class RemoteComputerDesktopController {
  private readonly transport: MahayanaHostTransport;
  private readonly label: string;
  private readonly deviceId: string;
  private readonly onState?: DesktopPeerOptions["onState"];
  private state: RemoteComputerDesktopState;
  private sessionTimer?: number;
  private heartbeatTimer?: number;
  private peers = new Map<string, PeerSession>();
  private stopped = true;
  private polling = false;

  constructor(options: DesktopPeerOptions) {
    this.transport = options.transport;
    this.label = options.label.trim() || "This Mac";
    this.deviceId = remoteDeviceId();
    this.onState = options.onState;
    this.state = {
      running: false,
      deviceId: this.deviceId,
      clients: [],
      sessions: [],
      connectionState: "idle",
      channelOpen: false,
    };
  }

  snapshot(): RemoteComputerDesktopState {
    return {
      ...this.state,
      clients: [...this.state.clients],
      sessions: [...this.state.sessions],
    };
  }

  private update(patch: Partial<RemoteComputerDesktopState>): void {
    this.state = { ...this.state, ...patch };
    this.onState?.(this.snapshot());
  }

  async start(): Promise<void> {
    if (!this.stopped) return;
    this.stopped = false;
    this.update({ running: true, error: undefined });
    await this.refreshPairingCode();
    await this.refreshClients();
    await this.pollSessions();
    this.heartbeatTimer = window.setInterval(() => void this.heartbeat(), HEARTBEAT_MS);
    this.sessionTimer = window.setInterval(() => void this.pollSessions(), SESSION_POLL_MS);
  }

  async stop(): Promise<void> {
    if (this.stopped) return;
    this.stopped = true;
    if (this.heartbeatTimer) window.clearInterval(this.heartbeatTimer);
    if (this.sessionTimer) window.clearInterval(this.sessionTimer);
    this.heartbeatTimer = undefined;
    this.sessionTimer = undefined;
    const sessions = [...this.peers.values()];
    await Promise.allSettled(sessions.map((session) => this.closePeer(session, true)));
    this.peers.clear();
    this.update({
      running: false,
      activeSessionId: undefined,
      activeClientId: undefined,
      connectionState: "idle",
      channelOpen: false,
    });
  }

  async refreshPairingCode(): Promise<RemoteComputerRegistration> {
    const id = requestId("remote-register");
    const event = await remoteRequest(this.transport, {
      type: "remoteComputer.register",
      requestId: id,
      deviceId: this.deviceId,
      label: this.label,
    });
    const data = objectValue(event.data);
    const registration: RemoteComputerRegistration = {
      deviceId: String(data.deviceId ?? this.deviceId),
      label: String(data.label ?? this.label),
      pairingCode: String(data.pairingCode ?? ""),
      pairingExpiresAt: Number(data.pairingExpiresAt ?? 0),
    };
    if (!registration.pairingCode) throw new Error("Remote computer registration did not return a pairing code");
    this.update({ registration, error: undefined });
    return registration;
  }

  async refreshClients(): Promise<RemoteComputerClient[]> {
    const id = requestId("remote-clients");
    const event = await remoteRequest(this.transport, {
      type: "remoteComputer.clients",
      requestId: id,
      deviceId: this.deviceId,
    });
    const data = objectValue(event.data);
    const clients = Array.isArray(data.clients) ? data.clients as RemoteComputerClient[] : [];
    this.update({ clients });
    return clients;
  }

  async revokeClient(clientId: string): Promise<void> {
    const id = requestId("remote-revoke");
    await remoteRequest(this.transport, {
      type: "remoteComputer.clientRevoke",
      requestId: id,
      deviceId: this.deviceId,
      clientId,
    });
    for (const peer of [...this.peers.values()]) {
      if (peer.session.clientId === clientId) await this.closePeer(peer, false);
    }
    await this.refreshClients();
  }

  async disconnectActive(): Promise<void> {
    const active = this.state.activeSessionId ? this.peers.get(this.state.activeSessionId) : undefined;
    if (active) await this.closePeer(active, true);
  }

  private async heartbeat(): Promise<void> {
    if (this.stopped) return;
    try {
      await remoteRequest(this.transport, {
        type: "remoteComputer.heartbeat",
        requestId: requestId("remote-heartbeat"),
        deviceId: this.deviceId,
      });
      await this.refreshClients();
    } catch (cause) {
      this.update({ error: cause instanceof Error ? cause.message : String(cause) });
    }
  }

  private async pollSessions(): Promise<void> {
    if (this.stopped || this.polling) return;
    this.polling = true;
    try {
      const event = await remoteRequest(this.transport, {
        type: "remoteComputer.sessions",
        requestId: requestId("remote-sessions"),
        deviceId: this.deviceId,
      });
      const data = objectValue(event.data) as SessionListPayload & Record<string, unknown>;
      const sessions = Array.isArray(data.sessions) ? data.sessions : [];
      const iceServers = Array.isArray(data.iceServers) ? data.iceServers : [];
      this.update({ sessions, error: undefined });
      const known = new Set(sessions.map((session) => session.sessionId));
      for (const peer of [...this.peers.values()]) {
        if (!known.has(peer.session.sessionId)) await this.closePeer(peer, false);
      }
      if (![...this.peers.values()].some((peer) => !peer.closing)) {
        const pending = sessions.find((session) => session.state === "pending");
        if (pending) await this.openPeer(pending, iceServers);
      }
    } catch (cause) {
      this.update({ error: cause instanceof Error ? cause.message : String(cause) });
    } finally {
      this.polling = false;
    }
  }

  private async openPeer(session: RemoteComputerSession, iceServers: RTCIceServer[]): Promise<void> {
    if (this.peers.has(session.sessionId) || this.stopped) return;
    const peer = new RTCPeerConnection({ iceServers });
    const entry: PeerSession = {
      session,
      peer,
      signalCursor: 0,
      activated: false,
      closing: false,
      operationQueue: Promise.resolve(),
      pendingRemoteCandidates: [],
    };
    this.peers.set(session.sessionId, entry);
    this.update({
      activeSessionId: session.sessionId,
      activeClientId: session.clientId,
      connectionState: peer.connectionState,
      channelOpen: false,
    });

    peer.onicecandidate = (event) => {
      if (!event.candidate || entry.closing) return;
      void remoteRequest(this.transport, {
        type: "remoteComputer.signal",
        requestId: requestId("remote-ice"),
        deviceId: this.deviceId,
        sessionId: session.sessionId,
        kind: "ice",
        payload: event.candidate.toJSON(),
      }).catch((cause) => this.update({ error: cause instanceof Error ? cause.message : String(cause) }));
    };
    peer.ondatachannel = (event) => {
      if (event.channel.label !== CHANNEL_LABEL) {
        event.channel.close();
        return;
      }
      this.configureChannel(entry, event.channel);
    };
    peer.onconnectionstatechange = () => {
      this.update({ connectionState: peer.connectionState });
      if (["failed", "closed", "disconnected"].includes(peer.connectionState)) {
        void this.closePeer(entry, peer.connectionState !== "closed");
      }
    };

    entry.signalTimer = window.setInterval(() => void this.drainSignals(entry), SIGNAL_POLL_MS);
    await this.drainSignals(entry);
  }

  private async drainSignals(entry: PeerSession): Promise<void> {
    if (entry.closing || this.stopped) return;
    try {
      const event = await remoteRequest(this.transport, {
        type: "remoteComputer.signalDrain",
        requestId: requestId("remote-signal-drain"),
        deviceId: this.deviceId,
        sessionId: entry.session.sessionId,
        afterSignalId: entry.signalCursor,
      });
      const data = objectValue(event.data) as SignalDrainPayload & Record<string, unknown>;
      const signals = Array.isArray(data.signals) ? data.signals : [];
      entry.signalCursor = Math.max(entry.signalCursor, Number(data.lastSignalId ?? entry.signalCursor));
      for (const signal of signals) await this.applySignal(entry, signal);
    } catch (cause) {
      if (!entry.closing) this.update({ error: cause instanceof Error ? cause.message : String(cause) });
    }
  }

  private async applySignal(entry: PeerSession, signal: RemoteComputerSignal): Promise<void> {
    if (entry.closing) return;
    if (signal.kind === "offer") {
      if (entry.peer.remoteDescription) return;
      await entry.peer.setRemoteDescription(signal.payload as RTCSessionDescriptionInit);
      for (const candidate of entry.pendingRemoteCandidates.splice(0)) {
        await entry.peer.addIceCandidate(candidate);
      }
      const answer = await entry.peer.createAnswer();
      await entry.peer.setLocalDescription(answer);
      await remoteRequest(this.transport, {
        type: "remoteComputer.signal",
        requestId: requestId("remote-answer"),
        deviceId: this.deviceId,
        sessionId: entry.session.sessionId,
        kind: "answer",
        payload: entry.peer.localDescription?.toJSON() ?? answer,
      });
      const activated = await remoteRequest(this.transport, {
        type: "remoteComputer.sessionActivate",
        requestId: requestId("remote-activate"),
        deviceId: this.deviceId,
        sessionId: entry.session.sessionId,
      });
      const activation = objectValue(activated.data);
      entry.activated = activation.state === "active";
      if (!entry.activated) throw new Error("Remote control session was not activated by the desktop host");
      entry.session = {
        ...entry.session,
        state: "active",
        clientId: String(activation.clientId ?? entry.session.clientId),
        expiresAt: Number(activation.expiresAt ?? entry.session.expiresAt),
        generation: Number(activation.generation ?? entry.session.generation ?? 0),
      };
      if (entry.channel?.readyState === "open") {
        this.update({ channelOpen: true, connectionState: entry.peer.connectionState });
        await sendJson(entry.channel, {
          type: "computer.hello",
          protocol: 1,
          deviceId: this.deviceId,
          sessionId: entry.session.sessionId,
          generation: entry.session.generation ?? 0,
        });
      }
      await remoteRequest(this.transport, {
        type: "remoteComputer.signal",
        requestId: requestId("remote-ready"),
        deviceId: this.deviceId,
        sessionId: entry.session.sessionId,
        kind: "ready",
        payload: { ready: true },
      });
      return;
    }
    if (signal.kind === "ice") {
      if (!signal.payload) return;
      const candidate = signal.payload as RTCIceCandidateInit;
      if (entry.peer.remoteDescription) {
        await entry.peer.addIceCandidate(candidate);
      } else {
        entry.pendingRemoteCandidates.push(candidate);
      }
      return;
    }
    if (signal.kind === "close") {
      await this.closePeer(entry, false);
    }
  }

  private configureChannel(entry: PeerSession, channel: RTCDataChannel): void {
    entry.channel = channel;
    channel.binaryType = "arraybuffer";
    channel.onopen = () => {
      this.update({ channelOpen: entry.activated, connectionState: entry.peer.connectionState });
      if (!entry.activated) return;
      void sendJson(channel, {
        type: "computer.hello",
        protocol: 1,
        deviceId: this.deviceId,
        sessionId: entry.session.sessionId,
      }).catch((cause) => this.update({ error: cause instanceof Error ? cause.message : String(cause) }));
    };
    channel.onclose = () => {
      this.update({ channelOpen: false });
      void this.closePeer(entry, true);
    };
    channel.onerror = () => this.update({ error: "Remote computer data channel failed" });
    channel.onmessage = (event) => {
      if (typeof event.data !== "string") return;
      entry.operationQueue = entry.operationQueue
        .then(() => this.handleChannelMessage(entry, event.data))
        .catch((cause) => this.update({ error: cause instanceof Error ? cause.message : String(cause) }));
    };
  }

  private async handleChannelMessage(entry: PeerSession, raw: string): Promise<void> {
    const channel = entry.channel;
    if (!channel || channel.readyState !== "open" || !entry.activated) return;
    let message: IncomingChannelMessage;
    try {
      message = JSON.parse(raw) as IncomingChannelMessage;
    } catch {
      await sendJson(channel, { type: "computer.error", message: "Invalid remote control message" });
      return;
    }
    if (message.type === "ping") {
      await sendJson(channel, { type: "pong", id: message.id, at: Date.now() });
      return;
    }
    if (message.type === "disconnect") {
      await this.closePeer(entry, true);
      return;
    }
    if (message.type === "computer.snapshot.request") {
      try {
        const snapshot = await computerSnapshotRequest(
          this.transport,
          entry.session.sessionId,
          remoteDesktopTarget(this.deviceId, entry.session.generation ?? 0),
        );
        await sendJson(channel, { type: "computer.ack", id: message.id, actionsExecuted: 0 });
        await sendSnapshotFrame(channel, message.id, snapshot);
      } catch (cause) {
        await sendJson(channel, { type: "computer.error", id: message.id, message: cause instanceof Error ? cause.message : String(cause) });
      }
      return;
    }
    if (message.type === "computer.action") {
      try {
        const result = await computerActionRequest(
          this.transport,
          entry.session.sessionId,
          remoteDesktopTarget(this.deviceId, entry.session.generation ?? 0),
          message.action,
          Array.isArray(message.then) ? message.then : [],
        );
        await sendJson(channel, { type: "computer.ack", id: message.id, actionsExecuted: result.actionsExecuted });
        await sendSnapshotFrame(channel, message.id, result.snapshot);
      } catch (cause) {
        await sendJson(channel, { type: "computer.error", id: message.id, message: cause instanceof Error ? cause.message : String(cause) });
      }
    }
  }

  private async closePeer(entry: PeerSession, notifyServer: boolean): Promise<void> {
    if (entry.closing) return;
    entry.closing = true;
    if (entry.signalTimer) window.clearInterval(entry.signalTimer);
    entry.signalTimer = undefined;
    const channel = entry.channel;
    if (channel?.readyState === "open") {
      try { await sendJson(channel, { type: "computer.closed" }); } catch { /* peer may already be gone */ }
    }
    try { channel?.close(); } catch { /* no-op */ }
    try { entry.peer.close(); } catch { /* no-op */ }
    this.peers.delete(entry.session.sessionId);
    if (notifyServer) {
      try {
        await remoteRequest(this.transport, {
          type: "remoteComputer.signal",
          requestId: requestId("remote-close-signal"),
          deviceId: this.deviceId,
          sessionId: entry.session.sessionId,
          kind: "close",
          payload: { closed: true },
        });
      } catch {
        // The peer may have disappeared before the close signal reached it.
      }
      try {
        await remoteRequest(this.transport, {
          type: "remoteComputer.sessionClose",
          requestId: requestId("remote-close"),
          deviceId: this.deviceId,
          sessionId: entry.session.sessionId,
        });
      } catch {
        // Server-side TTL is the backstop if the network disappeared first.
      }
    }
    this.update({
      activeSessionId: undefined,
      activeClientId: undefined,
      connectionState: "idle",
      channelOpen: false,
    });
  }
}
