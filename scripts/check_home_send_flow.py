#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
home = root / 'fabushi/lib/screens/globe_home_screen.dart'
model = root / 'fabushi/lib/models/file_transfer_model.dart'
home_text = home.read_text(encoding='utf-8')
model_text = model.read_text(encoding='utf-8')

method_match = re.search(r"void _startSending\(FileTransferModel model\) async \{(?P<body>.*?)\n  \}", home_text, re.S)
if not method_match:
    print('FAIL: GlobeHomeScreen._startSending was not found')
    sys.exit(1)
body = method_match.group('body')
call = 'model.startDefaultScriptureSendSequence()'
call_index = body.find(call)
if call_index == -1:
    print(f'FAIL: _startSending does not call {call}')
    sys.exit(1)

pre_call_body = body[:call_index]
if 'beginPreparingSend(' in pre_call_body:
    print('FAIL: _startSending calls beginPreparingSend before startDefaultScriptureSendSequence')
    print('This reintroduces the bug where isPreparingSend is set before the model guard runs.')
    sys.exit(1)

if 'if (model.isPreparingSend || model.isTransferring) return;' not in body:
    print('FAIL: _startSending no longer guards duplicate send taps')
    sys.exit(1)
sequence_match = re.search(r"Future<int> startDefaultScriptureSendSequence\(\) async \{(?P<body>.*?)\n  \}", model_text, re.S)
if not sequence_match:
    print('FAIL: FileTransferModel.startDefaultScriptureSendSequence was not found')
    sys.exit(1)
sequence_body = sequence_match.group('body')
if 'if (_isPreparingSend || _isTransferring) return 0;' not in sequence_body:
    print('FAIL: startDefaultScriptureSendSequence guard changed; update this regression test intentionally')
    sys.exit(1)
if 'beginPreparingSend(' not in sequence_body:
    print('FAIL: startDefaultScriptureSendSequence should own the preparing state')
    sys.exit(1)

print('PASS: homepage send flow calls startDefaultScriptureSendSequence without pre-setting preparing state')
