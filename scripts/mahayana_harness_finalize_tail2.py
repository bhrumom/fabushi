from pathlib import Path
import re

root = Path("third_party/mahayana/mahayana-rs")

services = root / "mahayana-harness-services/src/lib.rs"
text = services.read_text()
text = text.replace(
    'let session = harness.create_session(None, BTreeMap::new()).unwrap();',
    'let session = harness.create_session("search").unwrap();',
)
services.write_text(text)

adapters = root / "mahayana-harness-adapters/src/lib.rs"
text = adapters.read_text()
text, count = re.subn(
    r'\nfn value_to_bytes\(value: Value\) -> HarnessResult<Vec<u8>> \{.*?\n\}\n\n#\[cfg\(test\)\]',
    '\n#[cfg(test)]',
    text,
    count=1,
    flags=re.S,
)
if count not in (0, 1):
    raise SystemExit(f"unexpected value_to_bytes removal count={count}")
adapters.write_text(text)

print("Mahayana Harness final test/clippy reconciliation applied")
