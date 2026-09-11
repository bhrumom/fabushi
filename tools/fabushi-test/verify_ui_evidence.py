#!/usr/bin/env python3
"""Fail closed unless each registered UI journey retains its own evidence."""
from __future__ import annotations

import base64
import binascii
import hashlib
import io
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import zipfile
import zlib

CHECKPOINTS = {
    'real renderer hydrates and exposes masked semantic state without an App package': ['01-hydrated-real-renderer'],
    'semantic actions reach the actual profile UI and stale actions fail closed': ['01-before-profile', '02-profile-open'],
    'missing semantic targets and unmet conditions never report success': ['01-negative-semantics'],
}
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'
PNG_CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}
PNG_DEPTHS = {0: {1, 2, 4, 8, 16}, 2: {8, 16}, 3: {1, 2, 4, 8}, 4: {8, 16}, 6: {8, 16}}
ADAM7 = ((0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4),
         (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2))
MAX_DECODED_PNG = 256 * 1024 * 1024


def specs(suites):
    for suite in suites:
        yield from suite.get('specs', [])
        yield from specs(suite.get('suites', []))


def attachment_bytes(attachment: dict, root: Path) -> bytes:
    if attachment.get('path'):
        path = Path(attachment['path'])
        if not path.is_absolute():
            raise ValueError('attachment must use an absolute path from this CI run')
        path = path.resolve()
        if not path.is_relative_to(root.resolve()) or not path.is_file():
            raise ValueError('attachment missing or outside evidence root')
        if path.stat().st_size > 64 * 1024 * 1024:
            raise ValueError('attachment exceeds evidence verification limit')
        value = path.read_bytes()
    else:
        value = base64.b64decode(attachment.get('body', ''), validate=True)
    if not value:
        raise ValueError('empty evidence attachment')
    return value


def require_attachment(by_name: dict[str, dict], name: str, content_type: str) -> dict:
    attachment = by_name.get(name)
    if attachment is None:
        raise ValueError(f'missing required attachment: {name}')
    if attachment.get('contentType') != content_type:
        raise ValueError(f'invalid content type for {name}: expected {content_type}')
    return attachment


def _pass_size(total: int, start: int, step: int) -> int:
    return 0 if total <= start else (total - start + step - 1) // step


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if pa <= pb and pa <= pc else b if pb <= pc else c


def validate_png(data: bytes) -> None:
    """Parse PNG chunks, CRCs and zlib raster data using only the stdlib."""
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError('invalid PNG signature')
    offset = len(PNG_SIGNATURE)
    ihdr = None
    idat_parts: list[bytes] = []
    saw_idat = False
    idat_ended = False
    saw_iend = False
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError('truncated PNG chunk')
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload_start = offset + 8
        payload_end = payload_start + length
        chunk_end = payload_end + 4
        if chunk_end > len(data):
            raise ValueError('truncated PNG payload')
        payload = data[payload_start:payload_end]
        expected_crc = struct.unpack('>I', data[payload_end:chunk_end])[0]
        actual_crc = binascii.crc32(kind)
        actual_crc = binascii.crc32(payload, actual_crc) & 0xffffffff
        if actual_crc != expected_crc:
            raise ValueError('invalid PNG chunk CRC')
        if ihdr is None and kind != b'IHDR':
            raise ValueError('PNG must start with IHDR')
        if kind == b'IHDR':
            if ihdr is not None or length != 13 or offset != len(PNG_SIGNATURE):
                raise ValueError('invalid PNG IHDR')
            ihdr = struct.unpack('>IIBBBBB', payload)
        elif kind == b'IDAT':
            if ihdr is None or idat_ended:
                raise ValueError('invalid PNG IDAT ordering')
            saw_idat = True
            idat_parts.append(payload)
        else:
            if saw_idat:
                idat_ended = True
            if kind == b'IEND':
                if length != 0 or not saw_idat:
                    raise ValueError('invalid PNG IEND')
                saw_iend = True
                offset = chunk_end
                break
        offset = chunk_end
    if ihdr is None or not saw_iend or offset != len(data):
        raise ValueError('incomplete PNG image')

    width, height, bit_depth, color_type, compression, filter_method, interlace = ihdr
    if not 0 < width <= 32768 or not 0 < height <= 32768:
        raise ValueError('invalid PNG dimensions')
    if color_type not in PNG_CHANNELS or bit_depth not in PNG_DEPTHS[color_type]:
        raise ValueError('unsupported PNG color/depth combination')
    if compression != 0 or filter_method != 0 or interlace not in (0, 1):
        raise ValueError('unsupported PNG encoding')

    channels = PNG_CHANNELS[color_type]
    passes = [(width, height)] if interlace == 0 else [
        (_pass_size(width, x, dx), _pass_size(height, y, dy)) for x, y, dx, dy in ADAM7
    ]
    raster_layout: list[tuple[int, int]] = []
    decoded_size = 0
    for pass_width, pass_height in passes:
        if pass_width == 0 or pass_height == 0:
            continue
        row_bytes = (pass_width * channels * bit_depth + 7) // 8
        raster_layout.append((row_bytes, pass_height))
        decoded_size += (row_bytes + 1) * pass_height
    if decoded_size <= 0 or decoded_size > MAX_DECODED_PNG:
        raise ValueError('PNG decoded raster exceeds verification limit')

    inflater = zlib.decompressobj()
    raw = inflater.decompress(b''.join(idat_parts), decoded_size + 1)
    if inflater.unconsumed_tail or len(raw) > decoded_size:
        raise ValueError('PNG raster exceeds declared dimensions')
    raw += inflater.flush()
    if not inflater.eof or inflater.unused_data or len(raw) != decoded_size:
        raise ValueError('corrupt or truncated PNG raster')

    position = 0
    bytes_per_pixel = max(1, (channels * bit_depth + 7) // 8)
    for row_bytes, pass_height in raster_layout:
        previous = bytearray(row_bytes)
        for _ in range(pass_height):
            filter_type = raw[position]
            position += 1
            if filter_type > 4:
                raise ValueError('invalid PNG row filter')
            encoded = raw[position:position + row_bytes]
            position += row_bytes
            decoded = bytearray(row_bytes)
            for index, value in enumerate(encoded):
                left = decoded[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
                above = previous[index]
                upper_left = previous[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
                if filter_type == 0:
                    decoded[index] = value
                elif filter_type == 1:
                    decoded[index] = (value + left) & 0xff
                elif filter_type == 2:
                    decoded[index] = (value + above) & 0xff
                elif filter_type == 3:
                    decoded[index] = (value + ((left + above) // 2)) & 0xff
                else:
                    decoded[index] = (value + _paeth(left, above, upper_left)) & 0xff
            previous = decoded
    if position != len(raw):
        raise ValueError('PNG raster length mismatch')


def verify(report: dict, root: Path, required: dict | None = None) -> dict:
    required = CHECKPOINTS if required is None else required
    stats = report['stats']
    if report.get('errors') or any(stats.get(k) != 0 for k in ('unexpected', 'skipped', 'flaky')):
        raise ValueError('report contains errors, skipped tests or retries')
    items = list(specs(report['suites']))
    if not required or len(items) != len(required) or stats.get('expected') != len(required):
        raise ValueError('registered journey count mismatch')
    seen = set()
    result = []
    for spec in items:
        title = spec['title']
        if title not in required or title in seen or spec.get('ok') is not True:
            raise ValueError('unknown, duplicate or unsuccessful journey')
        seen.add(title)
        tests = spec['tests']
        if len(tests) != 1 or tests[0].get('expectedStatus') != 'passed' or tests[0].get('status') != 'expected':
            raise ValueError('unexpected test outcome')
        attempts = tests[0]['results']
        if len(attempts) != 1 or attempts[0].get('status') != 'passed' or attempts[0].get('retry') != 0:
            raise ValueError('not a first-attempt pass')
        attachments = attempts[0]['attachments']
        by_name: dict[str, dict] = {}
        for attachment in attachments:
            name = attachment.get('name')
            if not isinstance(name, str) or not name or name in by_name:
                raise ValueError('invalid or duplicate attachment name')
            by_name[name] = attachment
        for checkpoint in required[title]:
            require_attachment(by_name, checkpoint + '.png', 'image/png')
            require_attachment(by_name, checkpoint + '.json', 'application/json')
        require_attachment(by_name, 'video', 'video/webm')
        require_attachment(by_name, 'trace', 'application/zip')
        digests = []
        for attachment in attachments:
            data = attachment_bytes(attachment, root)
            kind = attachment['contentType']
            name = attachment['name']
            if kind == 'image/png':
                validate_png(data)
            if kind == 'application/json':
                json.loads(data)
            if name == 'trace':
                with zipfile.ZipFile(io.BytesIO(data)) as archive:
                    if not any(n.endswith('.trace') for n in archive.namelist()):
                        raise ValueError('trace archive has no action trace')
            if name == 'video' and not data.startswith(b'\x1a\x45\xdf\xa3'):
                raise ValueError('invalid WebM evidence')
            digests.append({'name': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        result.append({'title': title, 'duration_ms': attempts[0]['duration'], 'attachments': digests})
    return {'schema': 'fabushi.ui-evidence.v1', 'status': 'passed', 'journeys': result,
            'scope': 'registered real-renderer presentation journeys only', 'full_product_acceptance': False}


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    evidence = root / '.fast-ui-evidence'
    try:
        sha = os.environ.get('EXPECTED_SHA', '')
        if os.environ.get('GITHUB_ACTIONS') != 'true' or not re.fullmatch(r'[0-9a-f]{40}', sha):
            raise ValueError('exact-source GitHub Actions context required')
        if subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip() != sha:
            raise ValueError('source mismatch')
        report = json.loads((evidence / 'results.json').read_text())
        result = verify(report, evidence)
        result.update(source_sha=sha, run_id=os.environ.get('GITHUB_RUN_ID'))
        (evidence / 'evidence-manifest.json').write_text(json.dumps(result, indent=2) + '\n')
        print('FABUSHI_UI_EVIDENCE_VERIFIED', len(result['journeys']))
        return 0
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile, zlib.error, subprocess.SubprocessError) as error:
        print('UI evidence incomplete:', type(error).__name__, str(error))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
