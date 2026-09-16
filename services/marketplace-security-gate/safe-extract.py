#!/usr/bin/env python3
"""Safely unpack a marketplace artifact without following archive links."""

from __future__ import annotations

import os
import shutil
import stat
import sys
import tarfile
import zipfile
from pathlib import Path


MAX_FILES = 20_000
MAX_UNPACKED_BYTES = 512 * 1024 * 1024
MAX_COMPRESSION_RATIO = 1_000
CHUNK_SIZE = 1024 * 1024


def fail(message: str) -> "NoReturn":
    raise SystemExit(message)


def safe_member_path(root: Path, name: str) -> Path:
    if not name or "\x00" in name or "\\" in name:
        fail("archive contains an invalid member name")
    candidate = Path(name)
    if candidate.is_absolute() or any(part in ("", ".", "..") for part in candidate.parts):
        fail("archive contains an absolute or traversing member name")
    target = (root / candidate).resolve(strict=False)
    root_resolved = root.resolve()
    if target != root_resolved and root_resolved not in target.parents:
        fail("archive member escapes the extraction root")
    return target


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def copy_limited(source, target: Path, size: int, total: int) -> int:
    if size < 0 or total + size > MAX_UNPACKED_BYTES:
        fail("archive exceeds the unpacked size limit")
    ensure_parent(target)
    written = 0
    with target.open("wb") as output:
        while True:
            chunk = source.read(CHUNK_SIZE)
            if not chunk:
                break
            written += len(chunk)
            if written > size or total + written > MAX_UNPACKED_BYTES:
                fail("archive member exceeds the declared or total size limit")
            output.write(chunk)
    if written != size:
        fail("archive member size does not match its contents")
    os.chmod(target, 0o600)
    return total + written


def extract_tar(archive: Path, root: Path) -> None:
    total = 0
    count = 0
    try:
        with tarfile.open(archive, "r:*") as stream:
            for member in stream:
                count += 1
                if count > MAX_FILES:
                    fail("archive contains too many members")
                target = safe_member_path(root, member.name)
                if member.isdir():
                    target.mkdir(parents=True, exist_ok=True)
                    os.chmod(target, 0o700)
                    continue
                if not member.isfile() or member.issym() or member.islnk() or member.isdev():
                    fail("archive contains a link or special file")
                source = stream.extractfile(member)
                if source is None:
                    fail("archive member could not be read")
                total = copy_limited(source, target, member.size, total)
                if member.mode & 0o111:
                    os.chmod(target, 0o700)
    except (tarfile.TarError, OSError) as error:
        fail(f"tar archive is invalid: {error.__class__.__name__}")


def zip_mode(info: zipfile.ZipInfo) -> int:
    return (info.external_attr >> 16) & 0o170000


def extract_zip(archive: Path, root: Path) -> None:
    total = 0
    count = 0
    try:
        with zipfile.ZipFile(archive) as stream:
            for info in stream.infolist():
                count += 1
                if count > MAX_FILES:
                    fail("archive contains too many members")
                target = safe_member_path(root, info.filename)
                mode = zip_mode(info)
                if info.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    os.chmod(target, 0o700)
                    continue
                if mode == stat.S_IFLNK or mode in (stat.S_IFCHR, stat.S_IFBLK, stat.S_IFIFO, stat.S_IFSOCK):
                    fail("archive contains a link or special file")
                if info.file_size < 0 or info.compress_size < 0:
                    fail("archive member has an invalid size")
                if info.compress_size and info.file_size > info.compress_size * MAX_COMPRESSION_RATIO:
                    fail("archive member has an unsafe compression ratio")
                with stream.open(info, "r") as source:
                    total = copy_limited(source, target, info.file_size, total)
                if mode & stat.S_IXUSR:
                    os.chmod(target, 0o700)
    except (zipfile.BadZipFile, OSError) as error:
        fail(f"zip archive is invalid: {error.__class__.__name__}")


def copy_raw(archive: Path, root: Path) -> None:
    target = root / "payload.bin"
    size = archive.stat().st_size
    with archive.open("rb") as source:
        copy_limited(source, target, size, 0)


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: safe-extract.py <archive> <destination>")
    archive = Path(sys.argv[1]).resolve()
    root = Path(sys.argv[2]).resolve()
    if not archive.is_file() or root == Path("/"):
        fail("archive or destination is invalid")
    root.mkdir(parents=True, exist_ok=True)
    for child in root.iterdir():
        if child.is_symlink() or child.is_file():
            child.unlink()
        elif child.is_dir():
            shutil.rmtree(child)
    os.chmod(root, 0o700)
    if zipfile.is_zipfile(archive):
        extract_zip(archive, root)
    elif tarfile.is_tarfile(archive):
        extract_tar(archive, root)
    else:
        copy_raw(archive, root)


if __name__ == "__main__":
    main()
