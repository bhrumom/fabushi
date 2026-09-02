from pathlib import Path

path = Path('third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/lib.rs')
text = path.read_text(encoding='utf-8')
marker = '''pub const REMOTE_COMPUTER_AUDIT_GRANTS_SCHEMA_V19: &str =
    include_str!("../migrations/0019_remote_computer_audit_grants.sql");
'''
addition = marker + '''pub const REMOTE_COMPUTER_REQUESTED_GRANTS_SCHEMA_V20: &str =
    include_str!("../migrations/0020_remote_computer_requested_grants.sql");
'''
if 'REMOTE_COMPUTER_REQUESTED_GRANTS_SCHEMA_V20' not in text:
    if marker not in text:
        raise SystemExit('remote-computer migration registry marker changed')
    text = text.replace(marker, addition, 1)
path.write_text(text, encoding='utf-8')
