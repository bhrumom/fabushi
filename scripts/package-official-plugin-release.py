#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import tarfile
import zipfile
from pathlib import Path


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def add_checksum(path: Path) -> dict[str, str | int]:
    checksum = digest(path)
    checksum_path = path.with_name(path.name + ".sha256")
    checksum_path.write_text(f"{checksum}  {path.name}\n", encoding="utf-8")
    return {"name": path.name, "sha256": checksum, "bytes": path.stat().st_size}


def archive_directory(source: Path, destination: Path, arcname: str, archive_format: str) -> None:
    if archive_format == "zip":
        with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as output:
            for path in sorted(source.rglob("*")):
                if path.is_file():
                    output.write(path, Path(arcname) / path.relative_to(source))
    else:
        with tarfile.open(destination, "w:gz") as output:
            output.add(source, arcname=arcname, recursive=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True, type=Path)
    parser.add_argument("--target", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    marketplace_path = args.bundle / "marketplace.json"
    marketplace = json.loads(marketplace_path.read_text(encoding="utf-8"))
    version = marketplace["version"]
    archive_format = "zip" if args.target == "windows-x64" else "tar.gz"
    extension = ".zip" if archive_format == "zip" else ".tar.gz"
    args.output.mkdir(parents=True, exist_ok=True)

    records: list[dict[str, str | int]] = []
    for entry in marketplace["plugins"]:
        plugin_id = entry["name"]
        source = args.bundle / "plugins" / plugin_id
        if not source.is_dir():
            raise SystemExit(f"missing packaged plugin: {source}")
        destination = args.output / f"{plugin_id}-{version}-{args.target}{extension}"
        archive_directory(source, destination, plugin_id, archive_format)
        records.append(add_checksum(destination))

    bundle_stage = args.output / f"fabushi-official-marketplace-{version}-{args.target}"
    if bundle_stage.exists():
        shutil.rmtree(bundle_stage)
    bundle_stage.mkdir()
    shutil.copy2(marketplace_path, bundle_stage / "marketplace.json")
    shutil.copytree(args.bundle / "plugins", bundle_stage / "plugins")
    bundle_archive = args.output / f"fabushi-official-marketplace-{version}-{args.target}{extension}"
    archive_directory(bundle_stage, bundle_archive, bundle_stage.name, archive_format)
    shutil.rmtree(bundle_stage)
    records.append(add_checksum(bundle_archive))

    (args.output / f"release-manifest-{args.target}.json").write_text(
        json.dumps({"schemaVersion": 1, "version": version, "target": args.target, "files": records}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"created {len(records)} release archives for {args.target}")


if __name__ == "__main__":
    main()
