from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"{label} marker changed in {path}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


main = Path("desktop/electron/main.cjs")
replace_once(
    main,
    "const { RustDeskHostDaemonProcess } = require('./rustdesk-host-daemon-process.cjs');\n",
    "const { RustDeskHostDaemonProcess } = require('./rustdesk-host-daemon-process.cjs');\nconst { rotateTemporaryPassword } = require('./rustdesk-host-bootstrap.cjs');\n",
    "host bootstrap import",
)
replace_once(
    main,
    "const rustDeskSidecar = new RustDeskSidecarProcess({ app });\nconst rustDeskHostDaemon = new RustDeskHostDaemonProcess({ app });\n",
    "const rustDeskSidecar = new RustDeskSidecarProcess({ app });\nconst rustDeskHostDaemon = new RustDeskHostDaemonProcess({ app });\nconst rustDeskIssuedHostSessions = new Set();\n",
    "host credential session set",
)
replace_once(
    main,
    '''    getRustDeskStatus() {
      return { available: Boolean(rustDeskSidecar.executablePath()), ready: rustDeskSidecar.ready, sessions: rustDeskSidecar.sessions.size, host: rustDeskHostDaemon.status() };
    },
    openRustDeskSession(params) {
''',
    '''    getRustDeskStatus() {
      return { available: Boolean(rustDeskSidecar.executablePath()), ready: rustDeskSidecar.ready, sessions: rustDeskSidecar.sessions.size, host: rustDeskHostDaemon.status() };
    },
    async createRustDeskHostSessionCredential(params) {
      const sessionId = String(params?.sessionId || '');
      if (!/^[A-Za-z0-9._:-]{1,160}$/.test(sessionId)) throw new Error('RustDesk host session id is invalid.');
      if (rustDeskIssuedHostSessions.has(sessionId)) throw new Error('RustDesk host credential was already issued for this session.');
      const credential = await rotateTemporaryPassword({ app });
      rustDeskIssuedHostSessions.add(sessionId);
      return credential;
    },
    async revokeRustDeskHostSessionCredential(params) {
      const sessionId = String(params?.sessionId || '');
      if (!rustDeskIssuedHostSessions.delete(sessionId)) return false;
      // Rotate again and discard the value so the credential previously sent over
      // the authenticated DTLS data channel becomes unusable immediately.
      await rotateTemporaryPassword({ app });
      return true;
    },
    openRustDeskSession(params) {
''',
    "host credential handlers",
)

for file_name in ["desktop/electron/native-edge.cjs", "desktop/src/edge/contracts/native-capabilities.ts"]:
    path = Path(file_name)
    replace_once(
        path,
        "  getRustDeskStatus: { args: 'none' },\n  openRustDeskSession: { args: 'object' },\n",
        "  getRustDeskStatus: { args: 'none' },\n  createRustDeskHostSessionCredential: { args: 'object' },\n  revokeRustDeskHostSessionCredential: { args: 'object' },\n  openRustDeskSession: { args: 'object' },\n",
        "native host credential methods",
    )

native_desktop = Path("frontend/apps/web/src/lib/fabushi-runtime/native-desktop.ts")
replace_once(
    native_desktop,
    '''  | "remote-desktop-user-presence"
  | "dev-compute-pull-progress"
''',
    '''  | "remote-desktop-user-presence"
  | "rustdesk-sidecar-event"
  | "rustdesk-sidecar-exit"
  | "dev-compute-pull-progress"
''',
    "native RustDesk event types",
)

desktop_peer = Path("frontend/apps/web/src/lib/remote-computer/desktop-peer.ts")
replace_once(
    desktop_peer,
    '''import type { MahayanaHostTransport } from "../mahayana-host/transport";
''',
    '''import type { MahayanaHostTransport } from "../mahayana-host/transport";
import { invokeNativeDesktop } from "../fabushi-runtime/native-desktop";
''',
    "desktop native bridge import",
)
replace_once(
    desktop_peer,
    '''  pendingRemoteCandidates: RTCIceCandidateInit[];
}
''',
    '''  pendingRemoteCandidates: RTCIceCandidateInit[];
  rustDeskBootstrapped: boolean;
}
''',
    "peer RustDesk bootstrap state",
)
replace_once(
    desktop_peer,
    '''      drainingSignals: false,
      pendingRemoteCandidates: [],
    };
''',
    '''      drainingSignals: false,
      pendingRemoteCandidates: [],
      rustDeskBootstrapped: false,
    };
''',
    "peer RustDesk bootstrap initializer",
)

hello_block = '''        await sendJson(entry.channel, {
          type: "computer.hello",
          protocol: 1,
          deviceId: this.deviceId,
          sessionId: entry.session.sessionId,
          generation: entry.session.generation ?? 0,
        });
'''
hello_with_bootstrap = hello_block + '''        await this.maybeSendRustDeskBootstrap(entry);
'''
replace_once(desktop_peer, hello_block, hello_with_bootstrap, "activated RustDesk bootstrap")

onopen_block = '''      void sendJson(channel, {
        type: "computer.hello",
        protocol: 1,
        deviceId: this.deviceId,
        sessionId: entry.session.sessionId,
        generation: entry.session.generation ?? 0,
      }).catch((cause) => this.update({ error: cause instanceof Error ? cause.message : String(cause) }));
'''
onopen_with_bootstrap = '''      void (async () => {
        await sendJson(channel, {
          type: "computer.hello",
          protocol: 1,
          deviceId: this.deviceId,
          sessionId: entry.session.sessionId,
          generation: entry.session.generation ?? 0,
        });
        await this.maybeSendRustDeskBootstrap(entry);
      })().catch((cause) => this.update({ error: cause instanceof Error ? cause.message : String(cause) }));
'''
replace_once(desktop_peer, onopen_block, onopen_with_bootstrap, "data channel RustDesk bootstrap")

configure_marker = '''  private configureChannel(entry: PeerSession, channel: RTCDataChannel): void {
'''
bootstrap_method = '''  private async maybeSendRustDeskBootstrap(entry: PeerSession): Promise<void> {
    const channel = entry.channel;
    if (this.provider !== "rustdesk-sidecar" || entry.rustDeskBootstrapped || entry.closing || !entry.activated
      || !channel || channel.readyState !== "open") return;
    try {
      const credential = await invokeNativeDesktop<{ peerId?: unknown; temporaryPassword?: unknown }>(
        "createRustDeskHostSessionCredential",
        { sessionId: entry.session.sessionId },
      );
      const peerId = typeof credential?.peerId === "string" ? credential.peerId : "";
      const password = typeof credential?.temporaryPassword === "string" ? credential.temporaryPassword : "";
      if (!/^[A-Za-z0-9._:-]{1,160}$/.test(peerId) || password.length < 6 || password.length > 32 || /\\s/.test(password)) {
        throw new Error("RustDesk host bootstrap returned invalid credentials");
      }
      entry.rustDeskBootstrapped = true;
      await sendJson(channel, {
        type: "rustdesk.bootstrap",
        protocol: 1,
        sessionId: entry.session.sessionId,
        peerId,
        password,
        forceRelay: false,
        grant: entry.session.permissions,
      });
    } catch (cause) {
      // Browser/mobile and native sessions keep the already-authorized WebRTC path
      // when a native provider is unavailable. Never fail open by fabricating a
      // RustDesk credential or widening the session grant.
      this.update({ error: cause instanceof Error ? cause.message : String(cause) });
    }
  }

'''
text = desktop_peer.read_text(encoding="utf-8")
if "private async maybeSendRustDeskBootstrap" not in text:
    if configure_marker not in text:
        raise SystemExit("configure channel marker changed")
    desktop_peer.write_text(text.replace(configure_marker, bootstrap_method + configure_marker, 1), encoding="utf-8")

close_marker = '''    entry.closing = true;
    if (entry.signalTimer) window.clearInterval(entry.signalTimer);
'''
close_revoke = '''    entry.closing = true;
    if (entry.rustDeskBootstrapped) {
      entry.rustDeskBootstrapped = false;
      await invokeNativeDesktop("revokeRustDeskHostSessionCredential", { sessionId: entry.session.sessionId }).catch(() => undefined);
    }
    if (entry.signalTimer) window.clearInterval(entry.signalTimer);
'''
replace_once(desktop_peer, close_marker, close_revoke, "revoke target RustDesk credential")

mobile_peer = Path("frontend/apps/web/src/lib/remote-computer/mobile-peer.ts")
replace_once(
    mobile_peer,
    '''import type { MobileControlSession, RemoteComputerApi, RemoteSignal } from "./remote-api";
''',
    '''import type { MobileControlSession, RemoteComputerApi, RemoteSignal } from "./remote-api";
import { NativeRustDeskController, validateNativeRustDeskBootstrap } from "./native-rustdesk-controller";
''',
    "mobile native controller import",
)
replace_once(
    mobile_peer,
    '''  | { type: "computer.closed" }
  | { type: "pong"; id?: string; at: number };
''',
    '''  | { type: "computer.closed" }
  | { type: "rustdesk.bootstrap"; protocol: 1; sessionId: string; peerId: string; password: string; forceRelay: boolean; grant: MobileControlSession["permissions"] }
  | { type: "pong"; id?: string; at: number };
''',
    "mobile RustDesk bootstrap message",
)
replace_once(
    mobile_peer,
    '''  private pendingAiRequests = new Map<string, number>();

  constructor(options: MobileRemoteComputerPeerOptions) {
''',
    '''  private pendingAiRequests = new Map<string, number>();
  private readonly nativeRustDesk: NativeRustDeskController;

  constructor(options: MobileRemoteComputerPeerOptions) {
''',
    "mobile native controller field",
)
replace_once(
    mobile_peer,
    '''    this.onError = options.onError;
    this.onAiAck = options.onAiAck;
  }
''',
    '''    this.onError = options.onError;
    this.onAiAck = options.onAiAck;
    this.nativeRustDesk = new NativeRustDeskController({
      onFrame: (frame) => this.onFrame?.(frame),
      onError: (message) => this.onError?.(message),
      onReady: () => this.update({ phase: "connected", session: this.session }),
    });
  }
''',
    "mobile native controller construction",
)
replace_once(
    mobile_peer,
    '''  requestSnapshot(): string {
    if (this.snapshotPending) return "snapshot-pending";
''',
    '''  requestSnapshot(): string {
    if (this.nativeRustDesk.active) return "rustdesk-streaming";
    if (this.snapshotPending) return "snapshot-pending";
''',
    "native snapshot streaming",
)
replace_once(
    mobile_peer,
    '''  sendAction(action: ComputerAction, then: ComputerAction[] = []): string {
    const id = messageId("action");
    this.send({ type: "computer.action", id, action, then });
    return id;
  }
''',
    '''  sendAction(action: ComputerAction, then: ComputerAction[] = []): string {
    const id = messageId("action");
    if (this.nativeRustDesk.active && then.length === 0 && this.nativeRustDesk.supportsAction(action)) {
      void this.nativeRustDesk.sendComputerAction(action).catch((cause) => this.onError?.(cause instanceof Error ? cause.message : String(cause)));
      return id;
    }
    this.send({ type: "computer.action", id, action, then });
    return id;
  }
''',
    "native action routing",
)
replace_once(
    mobile_peer,
    '''    this.pendingRemoteCandidates = [];
    return session;
''',
    '''    this.pendingRemoteCandidates = [];
    void this.nativeRustDesk.close();
    return session;
''',
    "native session close",
)
bootstrap_handler_marker = '''    if (message.type === "computer.ai.ack") {
'''
bootstrap_handler = '''    if (message.type === "rustdesk.bootstrap") {
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
'''
text = mobile_peer.read_text(encoding="utf-8")
if 'message.type === "rustdesk.bootstrap"' not in text:
    if bootstrap_handler_marker not in text:
        raise SystemExit("mobile bootstrap handler marker changed")
    mobile_peer.write_text(text.replace(bootstrap_handler_marker, bootstrap_handler + bootstrap_handler_marker, 1), encoding="utf-8")

shell = Path("desktop/src/messaging-shell-v2.tsx")
replace_once(
    shell,
    '''      controlEnabled: remoteControlEnabledRef.current,
      resolveAgentId: (requestedAgentId) => requestedAgentId === 'mahayana-assistant'
''',
    '''      controlEnabled: remoteControlEnabledRef.current,
      provider: 'rustdesk-sidecar',
      platform: navigator.platform.toLowerCase().includes('mac') ? 'macos'
        : navigator.platform.toLowerCase().includes('win') ? 'windows'
          : navigator.platform.toLowerCase().includes('linux') ? 'linux' : 'unknown',
      capabilities: ['remote-desktop', 'input', 'clipboard', 'file-transfer', 'display', 'audio', 'session-management'],
      resolveAgentId: (requestedAgentId) => requestedAgentId === 'mahayana-assistant'
''',
    "desktop RustDesk provider registration",
)

contract_test = Path("chatgpt-vps-control/tests/rustdesk-session-permission-enforcement.test.js")
tests = contract_test.read_text(encoding="utf-8")
addition = r'''

test("native RustDesk provider is reachable only after explicit active-session bootstrap", () => {
  const desktop = source("frontend/apps/web/src/lib/remote-computer/desktop-peer.ts");
  const mobile = source("frontend/apps/web/src/lib/remote-computer/mobile-peer.ts");
  const shell = source("desktop/src/messaging-shell-v2.tsx");
  const main = source("desktop/electron/main.cjs");
  assert.match(desktop, /entry\.activated/);
  assert.match(desktop, /createRustDeskHostSessionCredential/);
  assert.match(desktop, /type: "rustdesk\.bootstrap"/);
  assert.match(desktop, /revokeRustDeskHostSessionCredential/);
  assert.match(mobile, /validateNativeRustDeskBootstrap/);
  assert.match(mobile, /nativeRustDesk\.connect/);
  assert.match(shell, /provider: 'rustdesk-sidecar'/);
  assert.match(main, /rotateTemporaryPassword/);
  assert.match(main, /rustDeskIssuedHostSessions/);
});

test("RustDesk temporary credentials never enter cloud signaling or audit persistence", () => {
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");
  const audit = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0019_remote_computer_audit_grants.sql");
  assert.doesNotMatch(worker, /temporaryPassword|rustdeskPassword|providerPassword/);
  assert.doesNotMatch(audit, /temporary_password|rustdesk_password|provider_password/);
});
'''
if 'native RustDesk provider is reachable only after explicit active-session bootstrap' not in tests:
    contract_test.write_text(tests + addition, encoding="utf-8")
