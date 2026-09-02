from pathlib import Path

edge = Path('desktop/electron/native-edge.cjs')
text = edge.read_text()
marker = "  getDesktopEnvironment: { args: 'none' },\n"
additions = "  getRustDeskStatus: { args: 'none' },\n  openRustDeskSession: { args: 'object' },\n  sendRustDeskCommand: { args: 'object' },\n  closeRustDeskSession: { args: 'object' },\n"
if 'openRustDeskSession:' not in text:
    assert marker in text
    text = text.replace(marker, marker + additions, 1)
event_marker = "  'remote-desktop-user-presence',\n"
if "'rustdesk-sidecar-event'" not in text:
    assert event_marker in text
    text = text.replace(event_marker, event_marker + "  'rustdesk-sidecar-event',\n  'rustdesk-sidecar-exit',\n", 1)
edge.write_text(text)

preload = Path('desktop/electron/preload.cjs')
text = preload.read_text()
if "'rustdesk-sidecar-event'" not in text:
    assert event_marker in text
    text = text.replace(event_marker, event_marker + "  'rustdesk-sidecar-event',\n  'rustdesk-sidecar-exit',\n", 1)
preload.write_text(text)

main = Path('desktop/electron/main.cjs')
text = main.read_text()
require_marker = "const { RemoteDeviceAgentSupervisor } = require('./remote-device-agent-supervisor.cjs');\n"
if "require('./rustdesk-sidecar-process.cjs')" not in text:
    assert require_marker in text
    text = text.replace(require_marker, require_marker + "const { RustDeskSidecarProcess } = require('./rustdesk-sidecar-process.cjs');\n", 1)
host_marker = "const host = new MahayanaHostProcess({ providerEnvironment });\n"
if 'const rustDeskSidecar = new RustDeskSidecarProcess' not in text:
    assert host_marker in text
    text = text.replace(host_marker, host_marker + "const rustDeskSidecar = new RustDeskSidecarProcess({ app });\n", 1)
state_marker = "let quitting = false;\n"
hook = "rustDeskSidecar.on('event', (payload) => broadcastNativeEvent('rustdesk-sidecar-event', payload));\nrustDeskSidecar.on('exit', (payload) => broadcastNativeEvent('rustdesk-sidecar-exit', payload));\n"
if "rustDeskSidecar.on('event'" not in text:
    assert state_marker in text
    text = text.replace(state_marker, state_marker + hook, 1)
handlers_marker = "    getWindowState(_params, event) {\n"
handlers = '''    getRustDeskStatus() {
      return { available: Boolean(rustDeskSidecar.executablePath()), ready: rustDeskSidecar.ready, sessions: rustDeskSidecar.sessions.size };
    },
    openRustDeskSession(params) {
      return rustDeskSidecar.open(params);
    },
    sendRustDeskCommand(params) {
      const sessionId = String(params?.sessionId || '');
      const command = params?.command;
      if (!command || typeof command !== 'object' || Array.isArray(command)) throw new Error('RustDesk command is invalid.');
      return rustDeskSidecar.command(sessionId, command);
    },
    closeRustDeskSession(params) {
      return rustDeskSidecar.closeSession(String(params?.sessionId || ''));
    },
'''
if 'getRustDeskStatus() {' not in text:
    assert handlers_marker in text
    text = text.replace(handlers_marker, handlers + handlers_marker, 1)
quit_marker = "function requestApplicationQuit() {\n  quitting = true;\n  app.quit();\n}\n"
if 'rustDeskSidecar.close();' not in text:
    assert quit_marker in text
    text = text.replace(quit_marker, "function requestApplicationQuit() {\n  quitting = true;\n  rustDeskSidecar.close();\n  app.quit();\n}\n", 1)
main.write_text(text)
