from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"{label} marker changed in {path}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


controller = Path("frontend/apps/web/src/lib/remote-computer/native-rustdesk-controller.ts")
marker = '''  private command(command: Record<string, unknown>): Promise<unknown> {
'''
methods = '''  async writeClipboard(text: string): Promise<boolean> {
    if (!this.active || this.grant?.clipboard !== true || typeof text !== "string") return false;
    if (new TextEncoder().encode(text).byteLength > 512 * 1024) return false;
    await this.command({ type: "clipboard", text });
    return true;
  }

  async setAudioEnabled(enabled: boolean): Promise<boolean> {
    if (!this.sessionId || !this.connected || typeof enabled !== "boolean") return false;
    if (enabled && this.grant?.audio !== true) return false;
    await this.command({ type: "audio", enabled });
    return true;
  }

  async sendFileCommand(command: Record<string, unknown>): Promise<boolean> {
    if (!this.active || this.grant?.fileTransfer !== true) return false;
    const action = typeof command.action === "string" ? command.action : "";
    const allowed = new Set(["readRemoteDir", "readEmptyDirs", "send", "add", "resume", "cancel", "createDir", "removeFile", "removeDir", "removeDirAll", "rename", "confirmOverride"]);
    if (!allowed.has(action)) return false;
    for (const key of ["path", "to", "newName"] as const) {
      const value = command[key];
      if (value !== undefined && (typeof value !== "string" || value.length > 4096 || value.includes("\\0"))) return false;
    }
    await this.command({ ...command, type: "file", action });
    return true;
  }

  async reconnect(forceRelay = false): Promise<boolean> {
    if (!this.sessionId || !this.connected) return false;
    await this.command({ type: "reconnect", forceRelay: forceRelay === true });
    return true;
  }

'''
text = controller.read_text(encoding="utf-8")
if "async writeClipboard(" not in text:
    if marker not in text:
        raise SystemExit("native controller command marker changed")
    controller.write_text(text.replace(marker, methods + marker, 1), encoding="utf-8")

mobile = Path("frontend/apps/web/src/lib/remote-computer/mobile-peer.ts")
mobile_marker = '''  sendAiRequest(request: AiComputerRequest): string {
'''
mobile_methods = '''  writeClipboard(text: string): Promise<boolean> {
    return this.nativeRustDesk.writeClipboard(text);
  }

  setAudioEnabled(enabled: boolean): Promise<boolean> {
    return this.nativeRustDesk.setAudioEnabled(enabled);
  }

  sendFileCommand(command: Record<string, unknown>): Promise<boolean> {
    return this.nativeRustDesk.sendFileCommand(command);
  }

  reconnectNative(forceRelay = false): Promise<boolean> {
    return this.nativeRustDesk.reconnect(forceRelay);
  }

'''
text = mobile.read_text(encoding="utf-8")
if "writeClipboard(text: string)" not in text:
    if mobile_marker not in text:
        raise SystemExit("mobile peer AI marker changed")
    mobile.write_text(text.replace(mobile_marker, mobile_methods + mobile_marker, 1), encoding="utf-8")

test = Path("chatgpt-vps-control/tests/rustdesk-session-permission-enforcement.test.js")
tests = test.read_text(encoding="utf-8")
addition = r'''

test("native provider parity exposes bounded clipboard file audio and reconnect operations", () => {
  const controller = source("frontend/apps/web/src/lib/remote-computer/native-rustdesk-controller.ts");
  const mobile = source("frontend/apps/web/src/lib/remote-computer/mobile-peer.ts");
  assert.match(controller, /grant\?\.clipboard !== true/);
  assert.match(controller, /512 \* 1024/);
  assert.match(controller, /grant\?\.fileTransfer !== true/);
  assert.match(controller, /value\.length > 4096/);
  assert.match(controller, /enabled && this\.grant\?\.audio !== true/);
  assert.match(controller, /type: "reconnect"/);
  assert.match(mobile, /nativeRustDesk\.writeClipboard/);
  assert.match(mobile, /nativeRustDesk\.sendFileCommand/);
  assert.match(mobile, /nativeRustDesk\.setAudioEnabled/);
  assert.match(mobile, /nativeRustDesk\.reconnect/);
});
'''
if 'native provider parity exposes bounded clipboard file audio and reconnect operations' not in tests:
    test.write_text(tests + addition, encoding="utf-8")
