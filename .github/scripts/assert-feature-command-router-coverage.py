#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
PROTOCOL = ROOT / "third_party/mahayana/mahayana-rs/mahayana-host-protocol/src/lib.rs"
IMPLEMENTATION = ROOT / "third_party/mahayana/mahayana-rs/mahayana-feature-host/src/implementation.rs"

protocol = PROTOCOL.read_text(encoding="utf-8")
try:
    enum_body = protocol.split("pub enum FeatureCommand {", 1)[1].split(
        "\n}\n\nimpl FeatureCommand", 1
    )[0]
except IndexError as error:
    raise SystemExit(f"unable to locate FeatureCommand enum: {error}")

variants = re.findall(r"\n    ([A-Z][A-Za-z0-9_]*)\s*\{", enum_body)
serde_names = re.findall(r'#\[serde\(rename = "([^"]+)"\)\]\s*\n    [A-Z]', enum_body)
implementation = IMPLEMENTATION.read_text(encoding="utf-8")
implemented = set(re.findall(r"FeatureCommand::([A-Z][A-Za-z0-9_]+)", implementation))
missing = [variant for variant in variants if variant not in implemented]

if not variants:
    raise SystemExit("FeatureCommand enum contains no variants")
if len(serde_names) != len(variants):
    raise SystemExit(
        f"FeatureCommand serde coverage mismatch: {len(serde_names)} names for {len(variants)} variants"
    )
if len(set(serde_names)) != len(serde_names):
    raise SystemExit("FeatureCommand contains duplicate serialized command names")
if missing:
    print("FeatureHost is missing command routing for:", file=sys.stderr)
    for variant in missing:
        print(f"  - {variant}", file=sys.stderr)
    raise SystemExit(1)

print(f"FeatureCommand router coverage: {len(variants)}/{len(variants)} variants")
print(f"Serialized command names are unique: {len(serde_names)}/{len(serde_names)}")
