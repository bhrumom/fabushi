from pathlib import Path

path = Path("third_party/mahayana/mahayana-rs/mahayana-mcp-runtime/src/lib.rs")
text = path.read_text()
old = '''fn platform_name(platform: HostPlatform) -> &'static str {
    match platform {
        HostPlatform::Desktop => "desktop",
        HostPlatform::Mobile => "mobile",
        HostPlatform::Web => "web",
    }
}
'''
new = '''fn platform_name(platform: HostPlatform) -> &'static str {
    match platform {
        HostPlatform::Cli => "cli",
        HostPlatform::Desktop => "desktop",
        HostPlatform::Mobile => "mobile",
        HostPlatform::Web => "web",
    }
}
'''
if old not in text:
    if new in text:
        raise SystemExit(0)
    raise SystemExit("platform_name guard did not match")
path.write_text(text.replace(old, new, 1))
