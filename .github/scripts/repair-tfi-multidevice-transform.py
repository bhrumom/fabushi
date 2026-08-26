#!/usr/bin/env python3
from pathlib import Path

script = Path('.github/scripts/apply-tfi-multidevice-account-sync.py')
text = script.read_text(encoding='utf-8')
old = "      stored += 1;\\n    }\\n    return ok(res, 200, reqId, { pluginInstanceId, stored });\\n"
new = "      stored += 1;\\n    }\\n    return ok(res, 200, reqId, { pluginInstanceId, stored, mergedAt: now });\\n"
if text.count(old) != 1:
    raise SystemExit(f'expected one stale Mini App message marker, found {text.count(old)}')
script.write_text(text.replace(old, new, 1), encoding='utf-8')
exec(compile(script.read_text(encoding='utf-8'), str(script), 'exec'))
