from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"{label} marker changed in {path}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


mobile = Path("frontend/apps/web/src/lib/remote-computer/mobile-peer.ts")
replace_once(
    mobile,
    'import type { MobileControlSession, RemoteComputerApi, RemoteSignal } from "./remote-api";\n',
    'import type { MobileControlSession, RemoteComputerApi, RemoteControlPermissions, RemoteSignal } from "./remote-api";\n',
    "mobile permission type import",
)
replace_once(
    mobile,
    '''  clientToken: string;\n  onState?: (state: MobilePeerState) => void;\n''',
    '''  clientToken: string;\n  permissions?: RemoteControlPermissions;\n  onState?: (state: MobilePeerState) => void;\n''',
    "mobile permission option",
)
replace_once(
    mobile,
    '''  private readonly clientToken: string;\n  private readonly onState?: MobileRemoteComputerPeerOptions["onState"];\n''',
    '''  private readonly clientToken: string;\n  private readonly permissions: RemoteControlPermissions;\n  private readonly onState?: MobileRemoteComputerPeerOptions["onState"];\n''',
    "mobile permission field",
)
replace_once(
    mobile,
    '''    this.clientToken = options.clientToken;\n    this.onState = options.onState;\n''',
    '''    this.clientToken = options.clientToken;\n    this.permissions = Object.freeze({\n      display: true,\n      input: options.permissions?.input === true,\n      clipboard: options.permissions?.clipboard === true,\n      fileTransfer: options.permissions?.fileTransfer === true,\n      audio: options.permissions?.audio === true,\n    });\n    this.onState = options.onState;\n''',
    "mobile immutable requested grant",
)
replace_once(
    mobile,
    '''      const session = await this.api.createControlSession(this.deviceId, this.clientId, this.clientToken);\n''',
    '''      const session = await this.api.createControlSession(this.deviceId, this.clientId, this.clientToken, this.permissions);\n''',
    "mobile permission request",
)
replace_once(
    mobile,
    '''  private pendingAiRequests = new Map<string, number>();\n''',
    '''  private pendingAiRequests = new Map<string, number>();\n  private disconnectTimer?: number;\n''',
    "mobile disconnect grace timer",
)
replace_once(
    mobile,
    '''      peer.onconnectionstatechange = () => {\n        this.update({ peerState: peer.connectionState });\n        if (["failed", "disconnected"].includes(peer.connectionState)) this.fail(new Error("WebRTC 连接失败"));\n        if (peer.connectionState === "closed" && !this.closed) this.fail(new Error("WebRTC 连接已关闭"));\n      };\n''',
    '''      peer.onconnectionstatechange = () => {\n        this.update({ peerState: peer.connectionState });\n        if (peer.connectionState === "connected") {\n          if (this.disconnectTimer) window.clearTimeout(this.disconnectTimer);\n          this.disconnectTimer = undefined;\n          return;\n        }\n        if (peer.connectionState === "disconnected") {\n          if (!this.disconnectTimer) {\n            this.disconnectTimer = window.setTimeout(() => {\n              this.disconnectTimer = undefined;\n              if (!this.closed && this.peer === peer && peer.connectionState === "disconnected") {\n                this.fail(new Error("WebRTC 连接中断且未能在恢复窗口内重连"));\n              }\n            }, 8_000);\n          }\n          return;\n        }\n        if (this.disconnectTimer) window.clearTimeout(this.disconnectTimer);\n        this.disconnectTimer = undefined;\n        if (peer.connectionState === "failed") this.fail(new Error("WebRTC 连接失败"));\n        if (peer.connectionState === "closed" && !this.closed) this.fail(new Error("WebRTC 连接已关闭"));\n      };\n''',
    "mobile bounded transport recovery",
)
replace_once(
    mobile,
    '''    if (this.signalTimer) window.clearInterval(this.signalTimer);\n    this.signalTimer = undefined;\n''',
    '''    if (this.signalTimer) window.clearInterval(this.signalTimer);\n    this.signalTimer = undefined;\n    if (this.disconnectTimer) window.clearTimeout(this.disconnectTimer);\n    this.disconnectTimer = undefined;\n''',
    "mobile recovery timer cleanup",
)

desktop = Path("frontend/apps/web/src/lib/remote-computer/desktop-peer.ts")
replace_once(
    desktop,
    '''  pendingRemoteCandidates: RTCIceCandidateInit[];\n  rustDeskBootstrapped: boolean;\n}\n''',
    '''  pendingRemoteCandidates: RTCIceCandidateInit[];\n  rustDeskBootstrapped: boolean;\n  disconnectTimer?: number;\n}\n''',
    "desktop disconnect grace state",
)
replace_once(
    desktop,
    '''    peer.onconnectionstatechange = () => {\n      this.update({ connectionState: peer.connectionState });\n      if (["failed", "closed", "disconnected"].includes(peer.connectionState)) {\n        void this.closePeer(entry, peer.connectionState !== "closed");\n      }\n    };\n''',
    '''    peer.onconnectionstatechange = () => {\n      this.update({ connectionState: peer.connectionState });\n      if (peer.connectionState === "connected") {\n        if (entry.disconnectTimer) window.clearTimeout(entry.disconnectTimer);\n        entry.disconnectTimer = undefined;\n        return;\n      }\n      if (peer.connectionState === "disconnected") {\n        if (!entry.disconnectTimer) {\n          entry.disconnectTimer = window.setTimeout(() => {\n            entry.disconnectTimer = undefined;\n            if (!entry.closing && entry.peer.connectionState === "disconnected") void this.closePeer(entry, true);\n          }, 8_000);\n        }\n        return;\n      }\n      if (entry.disconnectTimer) window.clearTimeout(entry.disconnectTimer);\n      entry.disconnectTimer = undefined;\n      if (["failed", "closed"].includes(peer.connectionState)) {\n        void this.closePeer(entry, peer.connectionState !== "closed");\n      }\n    };\n''',
    "desktop bounded transport recovery",
)
replace_once(
    desktop,
    '''    entry.closing = true;\n    if (entry.rustDeskBootstrapped) {\n''',
    '''    entry.closing = true;\n    if (entry.disconnectTimer) window.clearTimeout(entry.disconnectTimer);\n    entry.disconnectTimer = undefined;\n    if (entry.rustDeskBootstrapped) {\n''',
    "desktop recovery timer cleanup",
)

page = Path("frontend/apps/web/src/app/remote-computer/page.tsx")
replace_once(
    page,
    '''import { RemoteComputerApi, type PairedClientRecord, type RemoteAuthSession, type RemoteComputerInfo } from "../../lib/remote-computer/remote-api";\n''',
    '''import { RemoteComputerApi, type PairedClientRecord, type RemoteAuthSession, type RemoteComputerInfo, type RemoteControlPermissions } from "../../lib/remote-computer/remote-api";\n''',
    "page permission import",
)
replace_once(
    page,
    '''  const [boundAgentId, setBoundAgentId] = useState<string | undefined>();\n  const [error, setError] = useState<string | null>(null);\n''',
    '''  const [boundAgentId, setBoundAgentId] = useState<string | undefined>();\n  const [requestedPermissions, setRequestedPermissions] = useState<RemoteControlPermissions>({\n    display: true, input: true, clipboard: false, fileTransfer: false, audio: false,\n  });\n  const [error, setError] = useState<string | null>(null);\n''',
    "page requested permissions state",
)
replace_once(
    page,
    '''    peer = new MobileRemoteComputerPeer({\n      api,\n      deviceId,\n      clientId: record.clientId,\n      clientToken: record.clientToken,\n''',
    '''    const target = computers.find((computer) => computer.deviceId === deviceId);\n    const permissions: RemoteControlPermissions = {\n      display: true,\n      input: requestedPermissions.input && Boolean(target?.capabilities.includes("input")),\n      clipboard: requestedPermissions.clipboard && Boolean(target?.capabilities.includes("clipboard")),\n      fileTransfer: requestedPermissions.fileTransfer && Boolean(target?.capabilities.includes("file-transfer")),\n      audio: requestedPermissions.audio && Boolean(target?.capabilities.includes("audio")),\n    };\n    peer = new MobileRemoteComputerPeer({\n      api,\n      deviceId,\n      clientId: record.clientId,\n      clientToken: record.clientToken,\n      permissions,\n''',
    "page explicit permission request",
)
replace_once(
    page,
    '''            <div className={styles.computerList}>\n''',
    '''            <div aria-label="本次远控权限" style={{ display: "flex", flexWrap: "wrap", gap: 12, margin: "12px 0" }}>\n              <label><input type="checkbox" checked disabled /> 屏幕</label>\n              <label><input type="checkbox" checked={requestedPermissions.input} onChange={(event) => setRequestedPermissions((current) => ({ ...current, input: event.target.checked }))} /> 输入控制</label>\n              <label><input type="checkbox" checked={requestedPermissions.clipboard} onChange={(event) => setRequestedPermissions((current) => ({ ...current, clipboard: event.target.checked }))} /> 剪贴板</label>\n              <label><input type="checkbox" checked={requestedPermissions.fileTransfer} onChange={(event) => setRequestedPermissions((current) => ({ ...current, fileTransfer: event.target.checked }))} /> 文件传输</label>\n              <label><input type="checkbox" checked={requestedPermissions.audio} onChange={(event) => setRequestedPermissions((current) => ({ ...current, audio: event.target.checked }))} /> 音频</label>\n              <small>权限只对下一次会话生效，默认仅屏幕与输入；电脑端仍需逐次确认，可随时断开。</small>\n            </div>\n            <div className={styles.computerList}>\n''',
    "page least privilege controls",
)
replace_once(
    page,
    '''            <span><i /> 端到端 WebRTC · {peerState.peerState ?? "connected"}</span>\n''',
    '''            <span><i /> {selectedComputer?.provider === "rustdesk-sidecar" ? "Fabushi 授权通道 + RustDesk 原生数据面" : "端到端 WebRTC"} · {peerState.peerState ?? "connected"}</span>\n''',
    "truthful active transport label",
)

test = Path("chatgpt-vps-control/tests/rustdesk-session-permission-enforcement.test.js")
tests = test.read_text(encoding="utf-8")
addition = r'''

test("controller requests explicit least-privilege grants and tolerates brief disconnects without widening them", () => {
  const api = source("frontend/apps/web/src/lib/remote-computer/remote-api.ts");
  const mobile = source("frontend/apps/web/src/lib/remote-computer/mobile-peer.ts");
  const desktop = source("frontend/apps/web/src/lib/remote-computer/desktop-peer.ts");
  const page = source("frontend/apps/web/src/app/remote-computer/page.tsx");
  assert.match(api, /JSON\.stringify\(\{ clientId, clientToken, permissions \}\)/);
  assert.match(mobile, /this\.permissions = Object\.freeze/);
  assert.match(mobile, /createControlSession\(this\.deviceId, this\.clientId, this\.clientToken, this\.permissions\)/);
  assert.match(page, /本次远控权限/);
  assert.match(page, /fileTransfer: requestedPermissions\.fileTransfer/);
  assert.match(mobile, /8_000/);
  assert.match(desktop, /disconnectTimer/);
  assert.doesNotMatch(mobile, /permissions\s*=\s*\{[^}]*clipboard:\s*true[^}]*fileTransfer:\s*true/s);
});
'''
if 'controller requests explicit least-privilege grants' not in tests:
    test.write_text(tests + addition, encoding="utf-8")
