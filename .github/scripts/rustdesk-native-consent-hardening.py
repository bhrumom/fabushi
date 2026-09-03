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
    '''    async createRustDeskHostSessionCredential(params) {
      const sessionId = String(params?.sessionId || '');
      if (!/^[A-Za-z0-9._:-]{1,160}$/.test(sessionId)) throw new Error('RustDesk host session id is invalid.');
      if (rustDeskIssuedHostSessions.has(sessionId)) throw new Error('RustDesk host credential was already issued for this session.');
      const credential = await rotateTemporaryPassword({ app });
      rustDeskIssuedHostSessions.add(sessionId);
      return credential;
    },
''',
    '''    async createRustDeskHostSessionCredential(params) {
      const sessionId = String(params?.sessionId || '');
      if (!/^[A-Za-z0-9._:-]{1,160}$/.test(sessionId)) throw new Error('RustDesk host session id is invalid.');
      if (rustDeskIssuedHostSessions.has(sessionId)) throw new Error('RustDesk host credential was already issued for this session.');
      const grant = params?.grant && typeof params.grant === 'object' && !Array.isArray(params.grant) ? params.grant : null;
      if (!grant || grant.display !== true || ['input', 'clipboard', 'fileTransfer', 'audio'].some((key) => typeof grant[key] !== 'boolean')) {
        throw new Error('RustDesk host session grant is invalid.');
      }
      const clientLabel = String(params?.clientLabel || '已配对设备').trim().slice(0, 80) || '已配对设备';
      const capabilities = [
        '屏幕',
        grant.input ? '输入控制' : null,
        grant.clipboard ? '剪贴板' : null,
        grant.fileTransfer ? '文件传输' : null,
        grant.audio ? '音频' : null,
      ].filter(Boolean).join('、');
      const owner = BrowserWindow.getFocusedWindow() || BrowserWindow.getAllWindows().find((window) => !window.isDestroyed());
      const confirmation = await dialog.showMessageBox(owner || undefined, {
        type: 'warning',
        title: '允许 RustDesk 原生远程连接？',
        message: `${clientLabel} 请求切换到 RustDesk 原生数据通道`,
        detail: `会话 ${sessionId.slice(0, 24)}…\n本次权限：${capabilities}\n\n只有点击“允许”后才会生成一次性 RustDesk 凭据；关闭或撤销会话会立即轮换失效。`,
        buttons: ['拒绝', '允许'],
        defaultId: 0,
        cancelId: 0,
        noLink: true,
      });
      if (confirmation.response !== 1) throw new Error('RustDesk native session was denied by local user presence.');
      const credential = await rotateTemporaryPassword({ app });
      rustDeskIssuedHostSessions.add(sessionId);
      return credential;
    },
''',
    "native user-presence consent",
)

desktop = Path("frontend/apps/web/src/lib/remote-computer/desktop-peer.ts")
replace_once(
    desktop,
    '''        "createRustDeskHostSessionCredential",
        { sessionId: entry.session.sessionId },
''',
    '''        "createRustDeskHostSessionCredential",
        { sessionId: entry.session.sessionId, clientLabel: entry.session.clientLabel ?? entry.session.clientId, grant: entry.session.permissions },
''',
    "native consent context",
)

test = Path("chatgpt-vps-control/tests/rustdesk-session-permission-enforcement.test.js")
tests = test.read_text(encoding="utf-8")
addition = r'''

test("native RustDesk credentials require an Electron main-process user-presence confirmation", () => {
  const main = source("desktop/electron/main.cjs");
  const desktop = source("frontend/apps/web/src/lib/remote-computer/desktop-peer.ts");
  assert.match(main, /dialog\.showMessageBox/);
  assert.match(main, /confirmation\.response !== 1/);
  assert.match(main, /grant\.display !== true/);
  assert.match(main, /RustDesk native session was denied by local user presence/);
  assert.match(desktop, /clientLabel: entry\.session\.clientLabel/);
  assert.match(desktop, /grant: entry\.session\.permissions/);
});
'''
if 'native RustDesk credentials require an Electron main-process user-presence confirmation' not in tests:
    test.write_text(tests + addition, encoding="utf-8")
