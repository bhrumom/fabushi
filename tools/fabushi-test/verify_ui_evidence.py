#!/usr/bin/env python3
"""Fail closed unless each registered UI journey retains usable evidence."""
from __future__ import annotations

import base64
import binascii
from datetime import datetime
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
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
MAX_TRACE_MEMBER = 32 * 1024 * 1024
MAX_TRACE_TOTAL = 128 * 1024 * 1024
WEBM_SIGNATURE = b'\x1a\x45\xdf\xa3'
TRACE_ACTION_TYPES = {'before', 'after', 'input'}


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


def _validate_indexed_row(decoded: bytearray, width: int, bit_depth: int, palette_entries: int) -> None:
    """Reject indexed-color samples that do not resolve to a declared PLTE entry."""
    mask = (1 << bit_depth) - 1
    samples_per_byte = 8 // bit_depth
    for pixel in range(width):
        if bit_depth == 8:
            sample = decoded[pixel]
        else:
            byte = decoded[pixel // samples_per_byte]
            shift = 8 - bit_depth * ((pixel % samples_per_byte) + 1)
            sample = (byte >> shift) & mask
        if sample >= palette_entries:
            raise ValueError('indexed PNG sample exceeds declared palette')


def validate_png(data: bytes) -> None:
    """Parse PNG critical chunks, CRCs and zlib raster data using only the stdlib."""
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError('invalid PNG signature')
    offset = len(PNG_SIGNATURE)
    ihdr = None
    plte: bytes | None = None
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
        elif kind == b'PLTE':
            if ihdr is None or saw_idat or plte is not None:
                raise ValueError('invalid PNG PLTE ordering')
            if length < 3 or length > 768 or length % 3 != 0:
                raise ValueError('invalid PNG PLTE size')
            plte = payload
        elif kind == b'IDAT':
            if ihdr is None or idat_ended:
                raise ValueError('invalid PNG IDAT ordering')
            saw_idat = True
            idat_parts.append(payload)
        elif kind == b'IEND':
            if length != 0 or not saw_idat:
                raise ValueError('invalid PNG IEND')
            saw_iend = True
            offset = chunk_end
            break
        else:
            if len(kind) != 4 or not all(65 <= byte <= 90 or 97 <= byte <= 122 for byte in kind):
                raise ValueError('invalid PNG chunk type')
            if kind[0] & 0x20 == 0:
                raise ValueError('unknown PNG critical chunk')
            if saw_idat:
                idat_ended = True
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
    palette_entries = 0
    if color_type == 3:
        if plte is None:
            raise ValueError('indexed PNG requires PLTE')
        palette_entries = len(plte) // 3
        if palette_entries > 2 ** bit_depth:
            raise ValueError('indexed PNG palette exceeds bit-depth capacity')
    elif color_type in (0, 4) and plte is not None:
        raise ValueError('grayscale PNG must not contain PLTE')

    channels = PNG_CHANNELS[color_type]
    passes = [(width, height)] if interlace == 0 else [
        (_pass_size(width, x, dx), _pass_size(height, y, dy)) for x, y, dx, dy in ADAM7
    ]
    raster_layout: list[tuple[int, int, int]] = []
    decoded_size = 0
    for pass_width, pass_height in passes:
        if pass_width == 0 or pass_height == 0:
            continue
        row_bytes = (pass_width * channels * bit_depth + 7) // 8
        raster_layout.append((pass_width, row_bytes, pass_height))
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
    for pass_width, row_bytes, pass_height in raster_layout:
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
            if color_type == 3:
                _validate_indexed_row(decoded, pass_width, bit_depth, palette_entries)
            previous = decoded
    if position != len(raw):
        raise ValueError('PNG raster length mismatch')


def _require_bool(record: dict, name: str) -> None:
    if type(record.get(name)) is not bool:
        raise ValueError(f'invalid semantic snapshot boolean: {name}')


def _require_string(record: dict, name: str, *, nonempty: bool = False) -> str:
    value = record.get(name)
    if not isinstance(value, str) or (nonempty and not value):
        raise ValueError(f'invalid semantic snapshot string: {name}')
    return value


def validate_semantic_snapshot(data: bytes) -> dict:
    """Require the JSON attachment to be an actual AppSnapshot, not arbitrary JSON."""
    try:
        snapshot = json.loads(data)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError('invalid semantic snapshot JSON') from error
    if not isinstance(snapshot, dict):
        raise ValueError('semantic snapshot must be an object')
    if snapshot.get('version') != 1 or snapshot.get('available') is not True:
        raise ValueError('invalid semantic snapshot version/availability')
    _require_string(snapshot, 'appId', nonempty=True)
    _require_string(snapshot, 'platform', nonempty=True)
    _require_string(snapshot, 'title')
    _require_string(snapshot, 'route', nonempty=True)
    _require_string(snapshot, 'screen', nonempty=True)
    captured_at = _require_string(snapshot, 'capturedAt', nonempty=True)
    try:
        datetime.fromisoformat(captured_at.replace('Z', '+00:00'))
    except ValueError as error:
        raise ValueError('invalid semantic snapshot capturedAt') from error
    generation = snapshot.get('generation')
    element_count = snapshot.get('elementCount')
    if type(generation) is not int or generation <= 0:
        raise ValueError('invalid semantic snapshot generation')
    if type(element_count) is not int or element_count <= 0:
        raise ValueError('semantic snapshot must contain elements')
    _require_bool(snapshot, 'truncated')
    elements = snapshot.get('elements')
    if not isinstance(elements, list) or len(elements) != element_count:
        raise ValueError('semantic snapshot elementCount mismatch')
    for element in elements:
        if not isinstance(element, dict):
            raise ValueError('semantic snapshot element must be an object')
        _require_string(element, 'ref', nonempty=True)
        _require_string(element, 'role', nonempty=True)
        _require_string(element, 'name')
        _require_string(element, 'tag', nonempty=True)
        for field in ('stable', 'visible', 'enabled', 'focused', 'sensitive'):
            _require_bool(element, field)
        if 'agentId' in element:
            _require_string(element, 'agentId', nonempty=True)
        for field in ('description', 'text', 'placeholder'):
            if field in element:
                _require_string(element, field)
        for field in ('checked', 'selected', 'expanded', 'valuePresent'):
            if field in element and type(element[field]) is not bool:
                raise ValueError(f'invalid semantic snapshot element boolean: {field}')
        if 'valueLength' in element and (type(element['valueLength']) is not int or element['valueLength'] < 0):
            raise ValueError('invalid semantic snapshot valueLength')
        if element['sensitive'] and any(field in element for field in ('valuePresent', 'valueLength', 'value')):
            raise ValueError('semantic snapshot exposes sensitive value metadata')
    return snapshot


def validate_trace_archive(data: bytes) -> dict:
    """Read Playwright trace JSONL and CRCs; a filename alone is not evidence."""
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        if archive.testzip() is not None:
            raise ValueError('trace archive contains a corrupt member')
        members = [item for item in archive.infolist() if item.filename.endswith('.trace') and not item.is_dir()]
        if not members:
            raise ValueError('trace archive has no action trace')
        total = sum(item.file_size for item in archive.infolist())
        if total <= 0 or total > MAX_TRACE_TOTAL:
            raise ValueError('trace archive exceeds verification limit')
        records = 0
        action_records = 0
        for member in members:
            if member.file_size <= 0 or member.file_size > MAX_TRACE_MEMBER:
                raise ValueError('trace member exceeds verification limit')
            try:
                payload = archive.read(member).decode('utf-8')
            except (UnicodeDecodeError, RuntimeError, zipfile.BadZipFile) as error:
                raise ValueError('trace member is unreadable') from error
            for line in payload.splitlines():
                if not line.strip():
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError as error:
                    raise ValueError('trace member contains invalid JSONL') from error
                if not isinstance(record, dict) or not isinstance(record.get('type'), str) or not record['type']:
                    raise ValueError('trace member contains invalid event record')
                records += 1
                if record['type'] in TRACE_ACTION_TYPES:
                    action_records += 1
        if records < 2 or action_records < 1:
            raise ValueError('trace archive contains no reconstructable action history')
        return {'records': records, 'action_records': action_records}


def _find_ffmpeg() -> Path:
    system = shutil.which('ffmpeg')
    if system:
        return Path(system)
    roots: list[Path] = []
    configured = os.environ.get('PLAYWRIGHT_BROWSERS_PATH', '')
    if configured and configured not in {'0', '1'}:
        roots.append(Path(configured).expanduser())
    roots.append(Path.home() / '.cache' / 'ms-playwright')
    patterns = ('ffmpeg-*/ffmpeg-linux', 'ffmpeg-*/ffmpeg-mac', 'ffmpeg-*/ffmpeg-win64.exe', 'ffmpeg-*/ffmpeg')
    for root in roots:
        for pattern in patterns:
            for candidate in sorted(root.glob(pattern), reverse=True):
                if candidate.is_file() and os.access(candidate, os.X_OK):
                    return candidate
    raise ValueError('ffmpeg decoder unavailable for WebM evidence verification')


def _timecode_ms(value: str) -> float:
    match = re.fullmatch(r'(\d+):(\d{2}):(\d{2}(?:\.\d+)?)', value.strip())
    if not match:
        return 0.0
    hours, minutes, seconds = match.groups()
    return (int(hours) * 3600 + int(minutes) * 60 + float(seconds)) * 1000.0


def probe_webm(data: bytes) -> dict:
    """Decode the complete WebM with ffmpeg and return observed frame/duration proof."""
    if len(data) < 64 or not data.startswith(WEBM_SIGNATURE):
        raise ValueError('invalid WebM evidence')
    ffmpeg = _find_ffmpeg()
    path = None
    try:
        with tempfile.NamedTemporaryFile(prefix='fabushi-evidence-', suffix='.webm', delete=False) as handle:
            handle.write(data)
            path = Path(handle.name)
        completed = subprocess.run(
            [str(ffmpeg), '-nostdin', '-v', 'error', '-progress', 'pipe:1', '-i', str(path),
             '-map', '0:v:0', '-f', 'null', '-', '-nostats'],
            text=True,
            capture_output=True,
            timeout=30,
            check=False,
        )
        if completed.returncode != 0:
            detail = completed.stderr.strip().replace('\n', ' ')[-500:]
            raise ValueError(f'WebM decode failed: {detail or "ffmpeg returned failure"}')
        frames = 0
        duration_ms = 0.0
        for line in completed.stdout.splitlines():
            key, separator, value = line.partition('=')
            if not separator:
                continue
            if key == 'frame':
                try:
                    frames = max(frames, int(value))
                except ValueError:
                    pass
            elif key == 'out_time':
                duration_ms = max(duration_ms, _timecode_ms(value))
        if frames <= 0 or duration_ms <= 0:
            raise ValueError('WebM contains no decodable non-empty video duration')
        return {'frames': frames, 'duration_ms': round(duration_ms, 3)}
    except subprocess.TimeoutExpired as error:
        raise ValueError('WebM decode exceeded evidence verification timeout') from error
    finally:
        if path is not None:
            path.unlink(missing_ok=True)


def verify(report: dict, root: Path, required: dict | None = None, *, video_probe=probe_webm) -> dict:
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
        attempt_duration = attempts[0].get('duration')
        if not isinstance(attempt_duration, (int, float)) or isinstance(attempt_duration, bool) or attempt_duration <= 0:
            raise ValueError('invalid journey duration')
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
            metadata: dict[str, object] = {}
            if kind == 'image/png':
                validate_png(data)
            if kind == 'application/json':
                validate_semantic_snapshot(data)
            if name == 'trace':
                metadata.update(validate_trace_archive(data))
            if name == 'video':
                video = video_probe(data)
                duration_ms = float(video.get('duration_ms', 0))
                frames = int(video.get('frames', 0))
                coverage_tolerance = max(1000.0, float(attempt_duration) * 0.25)
                if frames <= 0 or duration_ms <= 0 or duration_ms + coverage_tolerance < float(attempt_duration):
                    raise ValueError('WebM duration does not cover the recorded journey')
                metadata.update(video)
            digests.append({'name': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), **metadata})
        result.append({'title': title, 'duration_ms': attempt_duration, 'attachments': digests})
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