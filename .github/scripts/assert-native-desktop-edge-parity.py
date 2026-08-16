#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import re, sys

ROOT = Path(__file__).resolve().parents[2]
ts = (ROOT / 'desktop/src/edge/contracts/native-capabilities.ts').read_text(encoding='utf-8')
cjs = (ROOT / 'desktop/electron/native-edge.cjs').read_text(encoding='utf-8')
preload = (ROOT / 'desktop/electron/preload.cjs').read_text(encoding='utf-8')
main = (ROOT / 'desktop/electron/main.cjs').read_text(encoding='utf-8')

mm = re.search(r'export const NATIVE_DESKTOP_METHODS\s*=\s*\{([\s\S]*?)\}\s*as const', ts)
em = re.search(r'export const NATIVE_DESKTOP_EVENTS\s*=\s*\[([\s\S]*?)\]\s*as const', ts)
cm = re.search(r'const methods = \{([\s\S]*?)\n\};', cjs)
ce = re.search(r"defineEdge\('native-desktop', methods, \[([\s\S]*?)\]\);", cjs)
pe = re.search(r'const NATIVE_EVENTS = new Set\(\[([\s\S]*?)\]\);', preload)
if not all((mm, em, cm, ce, pe)):
    print('native desktop parity guard: unable to parse one or more catalogs', file=sys.stderr)
    raise SystemExit(1)

ts_methods = re.findall(r'^\s*([A-Za-z][A-Za-z0-9]*):\s*\{', mm.group(1), re.M)
cjs_methods = re.findall(r'^\s*([A-Za-z][A-Za-z0-9]*):\s*\{', cm.group(1), re.M)
ts_events = re.findall(r"'([^']+)'", em.group(1))
cjs_events = re.findall(r"'([^']+)'", ce.group(1))
preload_events = re.findall(r"'([^']+)'", pe.group(1))

if ts_methods != cjs_methods:
    print('native desktop parity guard: TS/CJS method catalogs differ', file=sys.stderr)
    raise SystemExit(1)
if ts_events != cjs_events or ts_events != preload_events:
    print('native desktop parity guard: TS/CJS/preload event catalogs differ', file=sys.stderr)
    raise SystemExit(1)

# Main may compose its handlers from the core object plus the extended provider.
core = set(re.findall(r'^\s{4}(?:async\s+)?([A-Za-z][A-Za-z0-9]*)\([^\n]*\)\s*\{', main, re.M))
ext_path = ROOT / 'desktop/electron/native-capability-handlers.cjs'
extended = set()
if ext_path.is_file():
    extended = set(re.findall(r'^\s{4}(?:async\s+)?([A-Za-z][A-Za-z0-9]*)\([^\n]*\)\s*\{', ext_path.read_text(encoding='utf-8'), re.M))
missing = [name for name in ts_methods if name not in core and name not in extended]
if missing:
    print('native desktop parity guard: missing handlers: ' + ', '.join(missing), file=sys.stderr)
    raise SystemExit(1)
print(f'Native desktop edge parity passed: {len(ts_methods)} methods, {len(ts_events)} events.')
