import json
from pathlib import Path

main_path = Path('desktop/electron/main.cjs')
main = main_path.read_text()
require_marker = "const { RustDeskSidecarProcess } = require('./rustdesk-sidecar-process.cjs');\n"
require_line = "const { RustDeskHostDaemonProcess } = require('./rustdesk-host-daemon-process.cjs');\n"
if require_line not in main:
    assert require_marker in main
    main = main.replace(require_marker, require_marker + require_line, 1)
instance_marker = "const rustDeskSidecar = new RustDeskSidecarProcess({ app });\n"
instance_line = "const rustDeskHostDaemon = new RustDeskHostDaemonProcess({ app });\n"
if instance_line not in main:
    assert instance_marker in main
    main = main.replace(instance_marker, instance_marker + instance_line, 1)
status_old = "return { available: Boolean(rustDeskSidecar.executablePath()), ready: rustDeskSidecar.ready, sessions: rustDeskSidecar.sessions.size };"
status_new = "return { available: Boolean(rustDeskSidecar.executablePath()), ready: rustDeskSidecar.ready, sessions: rustDeskSidecar.sessions.size, host: rustDeskHostDaemon.status() };"
if status_old in main:
    main = main.replace(status_old, status_new, 1)
quit_old = "  rustDeskSidecar.close();\n  app.quit();"
quit_new = "  rustDeskSidecar.close();\n  rustDeskHostDaemon.close();\n  app.quit();"
if quit_new not in main:
    assert quit_old in main
    main = main.replace(quit_old, quit_new, 1)
ready_marker = "app.whenReady().then(async () => {\n"
ready_line = "  const rustDeskHostStatus = rustDeskHostDaemon.start();\n  if (rustDeskHostStatus.available) console.info(JSON.stringify({ type: 'fabushi.rustdesk-host.started', ...rustDeskHostStatus }));\n"
if ready_line not in main:
    assert ready_marker in main
    main = main.replace(ready_marker, ready_marker + ready_line, 1)
main_path.write_text(main)

package_path = Path('desktop/package.json')
package = json.loads(package_path.read_text())
resources = package['build']['extraResources']
entry = {'from': 'resources/rustdesk-sidecar', 'to': 'rustdesk-sidecar', 'filter': ['**/*']}
if not any(item.get('from') == 'resources/rustdesk-sidecar' for item in resources):
    resources.append(entry)
package_path.write_text(json.dumps(package, ensure_ascii=False, indent=2) + '\n')

readme_path = Path('integrations/rustdesk-sidecar/README.md')
readme = readme_path.read_text()
needle = '- The sidecar is a separately built and distributable AGPL-3.0-only derivative of the pinned RustDesk upstream source in `UPSTREAM.lock`.\n'
addition = '- Fabushi packages a dedicated `fabushi-host-daemon` from the same pinned corresponding source, so remote hosting does not depend on a separately installed RustDesk application. Electron owns its lifetime and launches it with Fabushi account credentials stripped from the environment.\n'
if addition not in readme:
    assert needle in readme
    readme = readme.replace(needle, needle + addition, 1)
readme_path.write_text(readme)
