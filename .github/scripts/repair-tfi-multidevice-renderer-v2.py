#!/usr/bin/env python3
from pathlib import Path

script = Path('.github/scripts/apply-tfi-multidevice-renderer.py')
text = script.read_text(encoding='utf-8')
projection_old = "const messengerProjectionKey = 'fabushi.desktop.messenger-projection.v2';"
projection_new = "const messengerProjectionKey = 'fabushi.desktop.messenger-projection.v1';"
if text.count(projection_old) != 2:
    raise SystemExit(f'expected two stale projection-key markers, found {text.count(projection_old)}')
text = text.replace(projection_old, projection_new)
old = '''    """      let installed = installedMiniApps[id] ?? await transport.pluginActive(id);\n      if (!installed) {\n        await reconcileAccountMiniApps().catch(() => undefined);\n        installed = await transport.pluginActive(id);\n      }\n      if (!installed) throw new Error('请先从在线 Mini App 市场安装此应用');\n""",'''
new = '''    """      const installed = installedMiniApps[id] ?? await transport.pluginActive(id);\n      if (!installed) await reconcileAccountMiniApps().catch(() => undefined);\n      const reconciledInstalled = installed ?? await transport.pluginActive(id);\n      if (!reconciledInstalled) throw new Error('请先从在线 Mini App 市场安装此应用');\n""",'''
if text.count(old) != 1:
    raise SystemExit(f'expected one mutable install replacement block, found {text.count(old)}')
script.write_text(text.replace(old, new, 1), encoding='utf-8')
exec(compile(script.read_text(encoding='utf-8'), str(script), 'exec'))
