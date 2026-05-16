import json
from pathlib import Path

source_path = Path("OFFICIAL_SITE_RELEASE_STATE.json")
target_path = Path("frontend/apps/web/public/api/releases.json")

state = json.loads(source_path.read_text(encoding="utf-8"))
channels = state.get("channels", [])
incoming_beta = [channel for channel in channels if channel.get("audience") == "beta"]
incoming_stable = [channel for channel in channels if channel.get("audience") == "stable"]

existing = {}
if target_path.exists():
    try:
        existing = json.loads(target_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        existing = {}


def merge_channels(incoming, previous):
    merged = {}
    insertion_order = []
    for channel in previous:
        if not isinstance(channel, dict):
            continue
        key = f"{channel.get('audience', '')}:{channel.get('platform', '')}"
        if key not in merged:
            insertion_order.append(key)
        merged[key] = channel
    for channel in incoming:
        if not isinstance(channel, dict):
            continue
        key = f"{channel.get('audience', '')}:{channel.get('platform', '')}"
        if key not in merged:
            insertion_order.append(key)
        merged[key] = channel
    preferred_order = ["beta:Android", "beta:iOS", "stable:Android", "stable:iOS"]
    ordered_keys = [key for key in preferred_order if key in merged]
    ordered_keys.extend(key for key in insertion_order if key not in ordered_keys)
    return [merged[key] for key in ordered_keys]


previous_beta = existing.get("betaChannels", []) if isinstance(existing, dict) else []
previous_stable = existing.get("stableChannels", []) if isinstance(existing, dict) else []

api_state = {
    "betaChannels": merge_channels(incoming_beta, previous_beta),
    "stableChannels": merge_channels(incoming_stable, previous_stable),
    "screenshots": state.get("screenshots") or (existing.get("screenshots") if isinstance(existing, dict) else {}) or {},
    "releases": state.get("releases") or (existing.get("releases") if isinstance(existing, dict) else []) or [],
    "notes": state.get("notes") or (existing.get("notes") if isinstance(existing, dict) else []) or [],
}

target_path.write_text(json.dumps(api_state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
