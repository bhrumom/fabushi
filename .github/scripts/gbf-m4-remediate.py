#!/usr/bin/env python3
from pathlib import Path

computer = Path('third_party/mahayana/mahayana-rs/mahayana-computer/src/lib.rs')
text = computer.read_text(encoding='utf-8')
text = text.replace('action.duration_ms.unwrap_or(300)', 'action.wait_ms.unwrap_or(300)')
text = text.replace('action.scroll_amount.unwrap_or(1)', 'action.amount.unwrap_or(1)')
if 'action.duration_ms' in text or 'action.scroll_amount' in text:
    raise SystemExit('stale portable ComputerAction field remains')
if 'action.wait_ms.unwrap_or(300)' not in text or 'action.amount.unwrap_or(1)' not in text:
    raise SystemExit('canonical portable ComputerAction fields were not installed')
computer.write_text(text, encoding='utf-8')

protocol = Path('third_party/mahayana/mahayana-rs/mahayana-host-protocol/src/lib.rs')
text = protocol.read_text(encoding='utf-8')
if 'computer_action_duration_and_scroll_amount_match_the_react_contract' not in text:
    anchor = '    #[test]\n    fn event_json_uses_camel_case_fields() {\n'
    test = '''    #[test]
    fn computer_action_duration_and_scroll_amount_match_the_react_contract() {
        let action: ComputerAction = serde_json::from_str(
            r#"{\"action\":\"drag\",\"x\":1,\"y\":2,\"x2\":3,\"y2\":4,\"durationMs\":375,\"amount\":7}"#,
        )
        .expect("decode computer action");
        assert_eq!(action.wait_ms, Some(375));
        assert_eq!(action.amount, Some(7));
        let value = serde_json::to_value(&action).expect("encode computer action");
        assert_eq!(value["durationMs"], 375);
        assert_eq!(value["amount"], 7);
        assert!(value.get("waitMs").is_none());
    }

    #[test]
    fn legacy_wait_ms_alias_remains_accepted() {
        let action: ComputerAction = serde_json::from_str(
            r#"{\"action\":\"wait\",\"waitMs\":250}"#,
        )
        .expect("decode legacy wait action");
        assert_eq!(action.wait_ms, Some(250));
    }

'''
    if text.count(anchor) != 1:
        raise SystemExit(f'protocol test anchor count is {text.count(anchor)}, expected 1')
    text = text.replace(anchor, test + anchor, 1)
protocol.write_text(text, encoding='utf-8')

fast = Path('.github/workflows/mahayana-fast-checks.yml')
text = fast.read_text(encoding='utf-8')
if 'Install Linux native capture/input dependencies' not in text:
    marker = '      - name: Restore targeted Cargo cache\n'
    step = '''      - name: Install Linux native capture/input dependencies
        shell: bash
        run: |
          sudo apt-get update
          sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \\
            pkg-config libclang-dev libxcb1-dev libxrandr-dev libxfixes-dev \\
            libdbus-1-dev libpipewire-0.3-dev libwayland-dev libxkbcommon-dev

'''
    if text.count(marker) != 1:
        raise SystemExit(f'Mahayana cache anchor count is {text.count(marker)}, expected 1')
    text = text.replace(marker, step + marker, 1)
fast.write_text(text, encoding='utf-8')

print('GBF M4 remediation patch applied: canonical fields, protocol tests, Linux native CI dependencies.')
