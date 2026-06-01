#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
home = root / 'fabushi/lib/screens/globe_home_screen.dart'
global_dharma = root / 'fabushi/lib/screens/global_dharma_screen.dart'
model = root / 'fabushi/lib/models/file_transfer_model.dart'
home_text = home.read_text(encoding='utf-8')
global_dharma_text = global_dharma.read_text(encoding='utf-8')
model_text = model.read_text(encoding='utf-8')

method_match = re.search(
    r"void _startSending\(FileTransferModel model\) async \{(?P<body>.*?)\n  \}",
    home_text,
    re.S,
)
if not method_match:
    print('FAIL: GlobeHomeScreen._startSending was not found')
    sys.exit(1)

body = method_match.group('body')
if 'model.startDefaultScriptureSendSequence()' in body:
    print('FAIL: homepage send must not default-download CBETA scriptures')
    sys.exit(1)

if 'startDefaultScriptureSendSequence()' in global_dharma_text:
    print('FAIL: global dharma send must not default-download CBETA scriptures')
    sys.exit(1)

for method_name in (
    'startDefaultScriptureSendSequence',
    'prepareDefaultNonR2AssetsForSending',
):
    method_match = re.search(
        rf"Future<int> {method_name}\(\) async \{{(?P<body>.*?)\n  \}}",
        model_text,
        re.S,
    )
    if not method_match:
        print(f'FAIL: FileTransferModel.{method_name} was not found')
        sys.exit(1)
    method_body = method_match.group('body')
    if 'fetchSendTextsPage' in method_body or 'fetchDefaultSendTexts' in method_body:
        print(f'FAIL: {method_name} must not download default CBETA content')
        sys.exit(1)

if '_buildChatComposer(context, model)' not in home_text:
    print('FAIL: homepage should expose the chat-style send composer')
    sys.exit(1)

if '() => _openSendContentMenu(buttonContext, model)' not in home_text:
    print('FAIL: homepage + button should open the send-content menu')
    sys.exit(1)

if "if (!model.hasFiles)" not in body:
    print('FAIL: start button should require selected content before sending')
    sys.exit(1)

pre_send_body = body.split('await model.startGlobalTransfer()', 1)[0]
if '请先点击 + 选择链接、文本、文件或素材。' not in pre_send_body:
    print('FAIL: start button should guide users to pick content from the + menu')
    sys.exit(1)

if 'await model.startGlobalTransfer()' not in body:
    print('FAIL: homepage send should send the selected files/text/link content')
    sys.exit(1)

if 'Future<void> addUrlContentForSending' not in model_text:
    print('FAIL: FileTransferModel should support link content sending')
    sys.exit(1)

if 'Future<void> addTextContentForSending' not in model_text:
    print('FAIL: FileTransferModel should support manual text sending')
    sys.exit(1)

print('PASS: homepage send uses user-selected content and does not default-download CBETA')
