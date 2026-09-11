import base64
import binascii
import importlib.util
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile
import zlib

spec = importlib.util.spec_from_file_location('evidence', Path(__file__).with_name('verify_ui_evidence.py'))
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    crc = binascii.crc32(kind)
    crc = binascii.crc32(payload, crc) & 0xffffffff
    return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', crc)


def valid_png() -> bytes:
    ihdr = struct.pack('>IIBBBBB', 1, 1, 8, 6, 0, 0, 0)
    raster = b'\x00\x11\x22\x33\x44'
    return (evidence.PNG_SIGNATURE + png_chunk(b'IHDR', ihdr) +
            png_chunk(b'IDAT', zlib.compress(raster)) + png_chunk(b'IEND', b''))


def indexed_png(with_palette: bool, *, pixel_index: int = 0, palette_entries: int = 1) -> bytes:
    ihdr = struct.pack('>IIBBBBB', 1, 1, 1, 3, 0, 0, 0)
    chunks = [evidence.PNG_SIGNATURE, png_chunk(b'IHDR', ihdr)]
    if with_palette:
        palette = b''.join(bytes((index, index, index)) for index in range(palette_entries))
        chunks.append(png_chunk(b'PLTE', palette))
    chunks.append(png_chunk(b'IDAT', zlib.compress(bytes((0, (pixel_index & 1) << 7)))))
    chunks.append(png_chunk(b'IEND', b''))
    return b''.join(chunks)


def semantic_snapshot() -> bytes:
    return json.dumps({
        'version': 1,
        'appId': 'fabushi.desktop',
        'available': True,
        'platform': 'desktop',
        'title': 'Fabushi',
        'route': '/',
        'screen': 'home',
        'generation': 1,
        'capturedAt': '2026-09-11T13:00:00.000Z',
        'elementCount': 1,
        'truncated': False,
        'elements': [{
            'ref': 'agent:test:messenger-workspace',
            'agentId': 'test:messenger-workspace',
            'stable': True,
            'role': 'main',
            'name': 'Messenger',
            'visible': True,
            'enabled': True,
            'focused': False,
            'sensitive': False,
            'tag': 'main',
        }],
    }).encode()


def trace_archive(payload: str | None = None) -> bytes:
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, 'w') as z:
        z.writestr('test.trace', payload or (
            '{"type":"before","callId":"call@1","apiName":"page.goto"}\n'
            '{"type":"after","callId":"call@1"}\n'
        ))
    return archive.getvalue()


def stub_video_probe(_data: bytes) -> dict:
    return {'frames': 3, 'duration_ms': 1000.0}


class EvidenceTests(unittest.TestCase):
    def fixture(self):
        items = [('step.png', 'image/png', valid_png()),
                 ('step.json', 'application/json', semantic_snapshot()),
                 ('video', 'video/webm', evidence.WEBM_SIGNATURE + b'unit-fixture'),
                 ('trace', 'application/zip', trace_archive())]
        attachments = [{'name': n, 'contentType': t, 'body': base64.b64encode(b).decode()} for n, t, b in items]
        return {'stats': {'expected': 1, 'unexpected': 0, 'skipped': 0, 'flaky': 0}, 'errors': [],
                'suites': [{'specs': [{'title': 'fixture', 'ok': True, 'tests': [
                    {'expectedStatus': 'passed', 'status': 'expected', 'results': [
                        {'status': 'passed', 'retry': 0, 'duration': 100, 'attachments': attachments}]}]}]}]}

    def verify_fixture(self, data=None):
        return evidence.verify(data or self.fixture(), Path('.'), {'fixture': ['step']}, video_probe=stub_video_probe)

    def test_complete_unit_fixture(self):
        with tempfile.TemporaryDirectory():
            result = self.verify_fixture()
            self.assertFalse(result['full_product_acceptance'])
            self.assertEqual(len(result['journeys']), 1)

    def test_missing_artifact_or_step_never_passes(self):
        for index in range(4):
            data = self.fixture()
            data['suites'][0]['specs'][0]['tests'][0]['results'][0]['attachments'].pop(index)
            with self.subTest(index=index), self.assertRaises(ValueError):
                self.verify_fixture(data)

    def test_required_attachment_type_mismatch_never_passes(self):
        expected_types = ['image/png', 'application/json', 'video/webm', 'application/zip']
        for index, expected in enumerate(expected_types):
            data = self.fixture()
            attachment = data['suites'][0]['specs'][0]['tests'][0]['results'][0]['attachments'][index]
            attachment['contentType'] = 'text/plain'
            with self.subTest(index=index, expected=expected), self.assertRaisesRegex(ValueError, 'invalid content type'):
                self.verify_fixture(data)

    def test_truncated_png_never_passes(self):
        data = self.fixture()
        png = data['suites'][0]['specs'][0]['tests'][0]['results'][0]['attachments'][0]
        png['body'] = base64.b64encode(evidence.PNG_SIGNATURE + b'unit-fixture').decode()
        with self.assertRaises(ValueError):
            self.verify_fixture(data)

    def test_corrupt_png_raster_never_passes(self):
        image = bytearray(valid_png())
        image[-8] ^= 1
        with self.assertRaises(ValueError):
            evidence.validate_png(bytes(image))

    def test_indexed_png_requires_palette(self):
        evidence.validate_png(indexed_png(True))
        with self.assertRaisesRegex(ValueError, 'PLTE'):
            evidence.validate_png(indexed_png(False))

    def test_indexed_png_rejects_sample_outside_declared_palette(self):
        evidence.validate_png(indexed_png(True, pixel_index=0, palette_entries=1))
        with self.assertRaisesRegex(ValueError, 'sample exceeds declared palette'):
            evidence.validate_png(indexed_png(True, pixel_index=1, palette_entries=1))

    def test_arbitrary_json_is_not_a_semantic_snapshot(self):
        with self.assertRaisesRegex(ValueError, 'semantic snapshot'):
            evidence.validate_semantic_snapshot(b'{}')
        snapshot = evidence.validate_semantic_snapshot(semantic_snapshot())
        self.assertEqual(snapshot['elementCount'], 1)

    def test_sensitive_snapshot_cannot_expose_value_metadata(self):
        data = json.loads(semantic_snapshot())
        data['elements'][0]['sensitive'] = True
        data['elements'][0]['valueLength'] = 3
        with self.assertRaisesRegex(ValueError, 'sensitive value metadata'):
            evidence.validate_semantic_snapshot(json.dumps(data).encode())

    def test_trace_requires_real_jsonl_action_records(self):
        parsed = evidence.validate_trace_archive(trace_archive())
        self.assertGreaterEqual(parsed['action_records'], 1)
        with self.assertRaisesRegex(ValueError, 'event record'):
            evidence.validate_trace_archive(trace_archive('{}\n'))

    def test_magic_only_webm_is_rejected_before_decoder_lookup(self):
        with self.assertRaisesRegex(ValueError, 'invalid WebM'):
            evidence.probe_webm(evidence.WEBM_SIGNATURE + b'unit-fixture')

    def test_video_duration_must_cover_recorded_journey(self):
        data = self.fixture()
        attempt = data['suites'][0]['specs'][0]['tests'][0]['results'][0]
        attempt['duration'] = 10_000
        with self.assertRaisesRegex(ValueError, 'does not cover'):
            evidence.verify(
                data,
                Path('.'),
                {'fixture': ['step']},
                video_probe=lambda _data: {'frames': 10, 'duration_ms': 100.0},
            )

    def test_duplicate_attachment_name_never_passes(self):
        data = self.fixture()
        attachments = data['suites'][0]['specs'][0]['tests'][0]['results'][0]['attachments']
        attachments.append(dict(attachments[0]))
        with self.assertRaisesRegex(ValueError, 'duplicate attachment name'):
            self.verify_fixture(data)

    def test_empty_skipped_and_unexpected_reports_fail(self):
        for key in ['unexpected', 'skipped', 'flaky', 'expected']:
            data = self.fixture()
            data['stats'][key] = 0 if key == 'expected' else 1
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.verify_fixture(data)

    def test_external_attachment_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d) / 'evidence'
            root.mkdir()
            outside = Path(d) / 'outside'
            outside.write_text('unit fixture')
            with self.assertRaises(ValueError):
                evidence.attachment_bytes({'path': str(outside)}, root)


if __name__ == '__main__':
    unittest.main()