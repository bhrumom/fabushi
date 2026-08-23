#!/usr/bin/env python3
import json
from pathlib import Path
root=Path('.')
data=json.loads((root/'projects/grok-bot-fabushi-integration/evidence/GBF-601/canonical-data-model.json').read_text())
for name,target in data['models'].items():
    path=target.split('::',1)[0]
    if not (root/path).exists(): raise SystemExit(f'GBF canonical model missing {name}: {path}')
for path in data['forbiddenParallelAuthorities']:
    if (root/path).exists(): raise SystemExit(f'GBF parallel authority returned: {path}')
print(f"GBF canonical data model passed: {len(data['models'])} authorities, zero Grok parallel authorities.")
