#!/usr/bin/env python3
from pathlib import Path

script = Path('.github/scripts/apply-tfi-multidevice-renderer.py')
text = script.read_text(encoding='utf-8')
old = "const messengerProjectionKey = 'fabushi.desktop.messenger-projection.v2';"
new = "const messengerProjectionKey = 'fabushi.desktop.messenger-projection.v1';"
count = text.count(old)
if count != 2:
    raise SystemExit(f'expected two stale projection-key markers in renderer transform, found {count}')
script.write_text(text.replace(old, new), encoding='utf-8')
exec(compile(script.read_text(encoding='utf-8'), str(script), 'exec'))
