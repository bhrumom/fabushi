#!/usr/bin/env python3
from pathlib import Path
import re

CATALOG = Path('desktop/src/edge/contracts/native-capabilities.ts')
SOURCES = [
    Path('desktop/electron/main.cjs'),
    Path('desktop/electron/native-capability-handlers.cjs'),
]

catalog_text = CATALOG.read_text(encoding='utf-8')
methods_block = re.search(r'export const NATIVE_DESKTOP_METHODS\s*=\s*\{([\s\S]*?)\}\s*as const', catalog_text)
if not methods_block:
    raise SystemExit('native semantic gate: method catalog not found')
methods = re.findall(r'^\s*([A-Za-z][A-Za-z0-9]*):\s*\{', methods_block.group(1), re.M)

# Native handlers are object-literal methods indented four spaces. Extract by the
# next sibling method instead of parsing JavaScript braces so regex literals and
# template strings cannot confuse the guard.
handlers: dict[str, str] = {}
method_re = re.compile(r'^    (?:async\s+)?([A-Za-z][A-Za-z0-9]*)\([^\n]*\)\s*\{', re.M)
for path in SOURCES:
    text = path.read_text(encoding='utf-8')
    matches = list(method_re.finditer(text))
    for index, match in enumerate(matches):
        name = match.group(1)
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        handlers.setdefault(name, text[match.end():end])

missing = [method for method in methods if method not in handlers]
if missing:
    raise SystemExit('native semantic gate: handlers missing for ' + ', '.join(missing))

for method in methods:
    body = handlers[method]
    lowered = body.lower()
    if re.search(r'\b(todo|fixme|placeholder|not implemented|unimplemented)\b', lowered):
        raise SystemExit(f'native semantic gate: {method} contains a stub marker')
    compact = re.sub(r'\s+', ' ', body).strip().rstrip('},; ')
    if re.fullmatch(r'return\s+(true|false|null|undefined)', compact):
        raise SystemExit(f'native semantic gate: {method} is a constant-return stub')
    if re.fullmatch(r'return\s+\{[^{}]{0,160}\}', compact) and not re.search(
        r'await|app\.|process\.|readNativeState|mutateNativeState|broadcastNativeEvent|host\.|featureExecute|platformRequest|BrowserWindow|dialog\.|shell\.',
        body,
    ):
        raise SystemExit(f'native semantic gate: {method} is a static object stub')


# Marketplace APIs classify clients by product surface (desktop/mobile/web/cli),
# not by the Node OS strings (darwin/win32/linux). Passing process.platform
# silently emptied several catalog surfaces because most callers swallowed the
# resulting ProductError.
native_provider_text = Path('desktop/electron/native-capability-handlers.cjs').read_text(encoding='utf-8')
if re.search(r"marketplace\.browse[^\n]*platform:\s*process\.platform", native_provider_text):
    raise SystemExit('native semantic gate: marketplace browse must use the product platform desktop, not process.platform')

print(f'Native capability semantics gate passed for {len(methods)} methods.')
