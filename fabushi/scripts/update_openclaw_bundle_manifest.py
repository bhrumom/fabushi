#!/usr/bin/env python3
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "assets" / "openclaw" / "bundle_manifest.json"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: update_openclaw_bundle_manifest.py <platform>", file=sys.stderr)
        return 2
    platform = sys.argv[1]
    if MANIFEST_PATH.exists():
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    else:
        data = {"schema": 1, "platforms": {}}
    data["schema"] = 1
    data.setdefault("version", "openclaw-embedded-2026.06.3")
    if data["version"] == "openclaw-embedded-2026.06":
        data["version"] = "openclaw-embedded-2026.06.3"
    if data["version"] == "openclaw-embedded-2026.06.2":
        data["version"] = "openclaw-embedded-2026.06.3"
    data.setdefault("defaultPort", 18789)
    if data.get("defaultModel") in (None, "", "openclaw/default"):
        data["defaultModel"] = "deepseek/deepseek-chat"
    data.setdefault("defaultModelOverride", "")
    data["gatewayArgs"] = ["gateway", "--port", "{port}", "--force"]
    data.setdefault(
        "bundledPlugins",
        [
            {
                "id": "openclaw-weixin",
                "package": "@tencent-weixin/openclaw-weixin",
                "version": "2.4.3",
                "path": "plugins/openclaw-weixin",
                "channel": "openclaw-weixin",
            }
        ],
    )
    platforms = data.setdefault("platforms", {})
    platforms[platform] = {
        "nodeExecutable": "node/node.exe" if platform.startswith("windows-") else "node/bin/node",
        "cliEntrypoint": "openclaw/openclaw.mjs",
    }
    MANIFEST_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Updated {MANIFEST_PATH} for {platform}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
