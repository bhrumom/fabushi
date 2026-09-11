import base64
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('evidence', Path(__file__).with_name('verify_ui_evidence.py'))
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)


class EvidenceTests(unittest.TestCase):
    def fixture(self):
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr('test.trace', '{}\n')
        items = [('step.png', 'image/png', b'\x89PNG\r\n\x1a\nunit-fixture'),
                 ('step.json', 'application/json', b'{}'),
                 ('video', 'video/webm', b'\x1a\x45\xdf\xa3unit-fixture'),
                 ('trace', 'application/zip', archive.getvalue())]
        attachments = [{'name': n, 'contentType': t, 'body': base64.b64encode(b).decode()} for n, t, b in items]
        return {'stats': {'expected': 1, 'unexpected': 0, 'skipped': 0, 'flaky': 0}, 'errors': [],
                'suites': [{'specs': [{'title': 'fixture', 'ok': True, 'tests': [
                    {'expectedStatus': 'passed', 'status': 'expected', 'results': [
                        {'status': 'passed', 'retry': 0, 'duration': 1, 'attachments': attachments}]}]}]}]}

    def test_complete_unit_fixture(self):
        with tempfile.TemporaryDirectory() as d:
            result = evidence.verify(self.fixture(), Path(d), {'fixture': ['step']})
            self.assertFalse(result['full_product_acceptance'])
            self.assertEqual(len(result['journeys']), 1)

    def test_missing_artifact_or_step_never_passes(self):
        for index in range(4):
            data = self.fixture()
            data['suites'][0]['specs'][0]['tests'][0]['results'][0]['attachments'].pop(index)
            with self.subTest(index=index), self.assertRaises(ValueError):
                evidence.verify(data, Path('.'), {'fixture': ['step']})

    def test_required_attachment_type_mismatch_never_passes(self):
        expected_types = ['image/png', 'application/json', 'video/webm', 'application/zip']
        for index, expected in enumerate(expected_types):
            data = self.fixture()
            attachment = data['suites'][0]['specs'][0]['tests'][0]['results'][0]['attachments'][index]
            attachment['contentType'] = 'text/plain'
            with self.subTest(index=index, expected=expected), self.assertRaisesRegex(ValueError, 'invalid content type'):
                evidence.verify(data, Path('.'), {'fixture': ['step']})

    def test_duplicate_attachment_name_never_passes(self):
        data = self.fixture()
        attachments = data['suites'][0]['specs'][0]['tests'][0]['results'][0]['attachments']
        attachments.append(dict(attachments[0]))
        with self.assertRaisesRegex(ValueError, 'duplicate attachment name'):
            evidence.verify(data, Path('.'), {'fixture': ['step']})

    def test_empty_skipped_and_unexpected_reports_fail(self):
        for key in ['unexpected', 'skipped', 'flaky', 'expected']:
            data = self.fixture()
            data['stats'][key] = 0 if key == 'expected' else 1
            with self.subTest(key=key), self.assertRaises(ValueError):
                evidence.verify(data, Path('.'), {'fixture': ['step']})

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
