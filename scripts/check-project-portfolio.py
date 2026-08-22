#!/usr/bin/env python3
"""Validate Fabushi portfolio Project IDs without third-party dependencies."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PROJECTS_ROOT = ROOT / "projects"
REGISTRY_PATH = PROJECTS_ROOT / "PORTFOLIO.json"
ID_RE = re.compile(r"^FAB-P([0-9]{4})$")
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
KEY_RE = re.compile(r"^[A-Z][A-Z0-9]{1,11}$")


class ValidationError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise ValidationError(message)


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValidationError(f"missing required registry: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValidationError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        fail(f"registry root must be an object: {path}")
    return data


def top_level_yaml_scalars(path: Path) -> dict[str, str]:
    """Read simple top-level scalar fields from PROJECT.yaml.

    Fabushi PROJECT.yaml files contain nested YAML, but portfolio validation only needs
    top-level identity scalars. Keeping this parser intentionally narrow avoids adding a
    PyYAML dependency to a repository-governance gate.
    """

    result: dict[str, str] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError as exc:
        raise ValidationError(f"missing project metadata: {path}") from exc

    for raw in lines:
        if not raw or raw[0].isspace() or raw.lstrip().startswith("#") or ":" not in raw:
            continue
        key, value = raw.split(":", 1)
        key = key.strip()
        value = value.strip()
        if not value or value in {"|", ">"}:
            continue
        if value.startswith(("'", '"')) and value.endswith(("'", '"')) and len(value) >= 2:
            value = value[1:-1]
        result[key] = value
    return result


def validate_registry(registry: dict[str, Any]) -> list[dict[str, Any]]:
    if registry.get("schema_version") != 1:
        fail("PORTFOLIO.json schema_version must be 1")
    if registry.get("portfolio") != "FAB":
        fail("PORTFOLIO.json portfolio must be FAB")
    if registry.get("allocation_policy") != "monotonic-no-reuse":
        fail("allocation_policy must be monotonic-no-reuse")

    projects = registry.get("projects")
    if not isinstance(projects, list) or not projects:
        fail("registry projects must be a non-empty array")

    seen_ids: set[str] = set()
    seen_keys: set[str] = set()
    seen_slugs: set[str] = set()
    seen_paths: set[str] = set()
    sequences: list[int] = []

    for index, item in enumerate(projects, start=1):
        if not isinstance(item, dict):
            fail(f"projects[{index}] must be an object")
        project_id = item.get("project_id")
        project_key = item.get("project_key")
        slug = item.get("slug")
        path = item.get("authoritative_path")
        first_commit = item.get("first_canonical_main_commit")

        if not isinstance(project_id, str):
            fail(f"projects[{index}].project_id must be a string")
        match = ID_RE.fullmatch(project_id)
        if not match:
            fail(f"malformed Project ID {project_id!r}; expected FAB-P0001 style")
        sequence = int(match.group(1))
        if sequence == 0:
            fail("FAB-P0000 is reserved and may not be allocated")
        sequences.append(sequence)

        if not isinstance(project_key, str) or not KEY_RE.fullmatch(project_key):
            fail(f"invalid project_key for {project_id}: {project_key!r}")
        if not isinstance(slug, str) or not slug or slug.lower() != slug:
            fail(f"invalid lowercase project slug for {project_id}: {slug!r}")
        if not isinstance(path, str) or path != f"projects/{slug}":
            fail(f"authoritative_path mismatch for {project_id}: {path!r}")
        if not isinstance(first_commit, str) or not SHA_RE.fullmatch(first_commit):
            fail(f"first_canonical_main_commit must be a 40-char lowercase SHA for {project_id}")

        for value, seen, label in (
            (project_id, seen_ids, "project_id"),
            (project_key, seen_keys, "project_key"),
            (slug, seen_slugs, "slug"),
            (path, seen_paths, "authoritative_path"),
        ):
            if value in seen:
                fail(f"duplicate {label}: {value}")
            seen.add(value)

        legacy_ids = item.get("legacy_project_ids", [])
        if not isinstance(legacy_ids, list) or any(not isinstance(x, str) or not x for x in legacy_ids):
            fail(f"legacy_project_ids must be an array of non-empty strings for {project_id}")

    expected = list(range(1, len(projects) + 1))
    if sorted(sequences) != expected:
        fail(f"Project ID sequences must be contiguous and never removed: expected {expected}, got {sorted(sequences)}")

    next_sequence = registry.get("next_sequence")
    if not isinstance(next_sequence, int) or next_sequence != max(sequences) + 1:
        fail(f"next_sequence must equal max allocated sequence + 1 ({max(sequences) + 1})")

    return projects


def validate_project_folders(projects: list[dict[str, Any]]) -> None:
    actual_slugs = sorted(
        path.name
        for path in PROJECTS_ROOT.iterdir()
        if path.is_dir() and (path / "PROJECT.yaml").is_file()
    )
    registry_slugs = sorted(str(project["slug"]) for project in projects)
    if actual_slugs != registry_slugs:
        fail(
            "registry/project-folder mismatch:\n"
            f"  registry={registry_slugs}\n"
            f"  folders={actual_slugs}"
        )

    for project in projects:
        slug = str(project["slug"])
        metadata_path = PROJECTS_ROOT / slug / "PROJECT.yaml"
        metadata = top_level_yaml_scalars(metadata_path)
        expected = {
            "project_id": str(project["project_id"]),
            "project_key": str(project["project_key"]),
            "slug": slug,
            "authoritative_path": str(project["authoritative_path"]),
        }
        for key, value in expected.items():
            actual = metadata.get(key)
            if actual != value:
                fail(f"{metadata_path}: {key}={actual!r}, expected {value!r}")


def validate_immutability(current: dict[str, Any], baseline_path: Path | None) -> None:
    if baseline_path is None or not baseline_path.exists() or baseline_path.stat().st_size == 0:
        return

    baseline = load_json(baseline_path)
    baseline_projects = baseline.get("projects", [])
    current_projects = current.get("projects", [])
    if not isinstance(baseline_projects, list) or not isinstance(current_projects, list):
        fail("baseline/current projects must be arrays")

    current_by_id = {item.get("project_id"): item for item in current_projects if isinstance(item, dict)}
    baseline_ids: set[str] = set()
    for old in baseline_projects:
        if not isinstance(old, dict):
            continue
        project_id = old.get("project_id")
        if not isinstance(project_id, str):
            continue
        baseline_ids.add(project_id)
        new = current_by_id.get(project_id)
        if new is None:
            fail(f"registered Project ID {project_id} was removed; IDs are permanent")
        if new.get("project_key") != old.get("project_key"):
            fail(f"project_key mutation is forbidden for {project_id}: {old.get('project_key')} -> {new.get('project_key')}")
        if new.get("first_canonical_main_commit") != old.get("first_canonical_main_commit"):
            fail(f"first_canonical_main_commit mutation is forbidden for {project_id}")
        old_legacy = set(old.get("legacy_project_ids", []))
        new_legacy = set(new.get("legacy_project_ids", []))
        if not old_legacy.issubset(new_legacy):
            fail(f"legacy aliases may not be removed for {project_id}")

    baseline_next = baseline.get("next_sequence")
    if isinstance(baseline_next, int):
        new_ids = [
            item.get("project_id")
            for item in current_projects
            if isinstance(item, dict) and item.get("project_id") not in baseline_ids
        ]
        new_sequences = sorted(
            int(match.group(1))
            for value in new_ids
            if isinstance(value, str) and (match := ID_RE.fullmatch(value))
        )
        if new_sequences:
            expected = list(range(baseline_next, baseline_next + len(new_sequences)))
            if new_sequences != expected:
                fail(f"new projects must allocate from baseline next_sequence {baseline_next}: expected {expected}, got {new_sequences}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, default=None, help="Optional base-branch PORTFOLIO.json")
    args = parser.parse_args()

    try:
        registry = load_json(REGISTRY_PATH)
        projects = validate_registry(registry)
        validate_project_folders(projects)
        validate_immutability(registry, args.baseline)
    except ValidationError as exc:
        print(f"project portfolio validation failed: {exc}", file=sys.stderr)
        return 1

    print(
        f"project portfolio validation passed: {len(projects)} projects, "
        f"next={registry['project_id_format'] % registry['next_sequence']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
