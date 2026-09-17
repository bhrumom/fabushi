from pathlib import Path

worker = Path('third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs')
text = worker.read_text()
old = '''    if session.state == "closed" || session.expires_at <= now {
        return false;
    }
'''
new = '''    // Pending sessions are only consent requests. Neither controller nor target may
    // negotiate transport or exchange signaling until the target device explicitly
    // activates the session with its device secret.
    if session.state != "active" || session.expires_at <= now {
        return false;
    }
'''
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit('remote_session_actor_allowed marker changed')
worker.write_text(text)

test_file = Path('chatgpt-vps-control/tests/rustdesk-session-permission-enforcement.test.js')
tests = test_file.read_text()
marker = '''test("desktop transport enforces display and input grants before host actions", () => {
'''
addition = '''test("pending consent cannot negotiate transport or signaling", () => {
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");
  assert.match(worker, /session\.state != "active" \|\| session\.expires_at <= now/);
  assert.match(worker, /remote_computer_session_activate/);
  assert.match(worker, /state = 'pending'/);
});

'''
if 'pending consent cannot negotiate transport or signaling' not in tests:
    if marker not in tests:
        raise SystemExit('permission test marker changed')
    tests = tests.replace(marker, addition + marker, 1)
test_file.write_text(tests)
