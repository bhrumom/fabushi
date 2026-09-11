import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('controller', Path(__file__).with_name('fabushi_test.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class ControllerTests(unittest.TestCase):
    def setUp(self):
        self.suite = {'id': 'sample-test', 'layer': 'core', 'coverage': 'sample', 'argv': ['python3', '-V'],
                      'cwd': '.', 'timeout_seconds': 5}

    def test_empty_registry_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'registry.json'
            p.write_text('{"version":1,"suites":[]}')
            with self.assertRaises(ValueError):
                m.registry(p, Path(d))

    def test_registry_validates_ids_paths_timeouts(self):
        for delta in [{'id': '../bad'}, {'cwd': '..'}, {'timeout_seconds': 0}, {'layer': 'unknown'}, {'argv': []}]:
            with self.subTest(delta=delta), tempfile.TemporaryDirectory() as d:
                p = Path(d) / 'registry.json'
                p.write_text(json.dumps({'version': 1, 'suites': [{**self.suite, **delta}]}))
                with self.assertRaises(ValueError):
                    m.registry(p, Path(d))

    def test_unknown_or_empty_or_wrong_layer_selection_fails(self):
        for layer, selected in [('core', ['absent']), ('ui', []), ('ui', ['sample-test']), ('unknown', [])]:
            with self.assertRaises(ValueError):
                m.make_plan([self.suite], layer, selected)

    def test_selected_pass_never_claims_full_platform(self):
        plan = m.make_plan([self.suite], 'fast', [])
        self.assertFalse(plan['full_product_acceptance'])
        self.assertTrue(all(g['status'] == 'not-run' for g in plan['external_gates']))

    def test_local_product_execution_rejected(self):
        with patch.dict(m.os.environ, {'GITHUB_ACTIONS': 'false'}):
            with self.assertRaisesRegex(ValueError, 'GitHub Actions'):
                m.verify_ci(Path('.'), 'a' * 40)

    def test_repair_repeat_and_budget_are_bounded(self):
        report = {'source_sha': 'a' * 40, 'results': [{'id': 'sample-test', 'status': 'failed', 'exit_code': 1}]}
        request = m.repair_request(report)
        self.assertEqual(request['status'], 'awaiting-authorized-executor')
        self.assertFalse(request['automatic_fix_executed'])
        self.assertEqual(m.repair_request(report, request)['status'], 'blocked')
        self.assertEqual(m.repair_request(report, {'attempt': 3})['status'], 'blocked')
        self.assertEqual(m.repair_request({'results': []})['status'], 'blocked')

    def test_redacts_common_credentials(self):
        value = m.redact('Bearer abcdef password=hunter token: key123')
        for secret in ['abcdef', 'hunter', 'key123']:
            self.assertNotIn(secret, value)

    def test_path_escape_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(ValueError):
                m.contained(Path(d), '../outside')

    def test_atomic_json_roundtrip(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'sub' / 'result.json'
            m.atomic_json(p, {'status': 'failed'})
            self.assertEqual(json.loads(p.read_text()), {'status': 'failed'})
            self.assertFalse(p.with_name(p.name + '.tmp').exists())


if __name__ == '__main__':
    unittest.main()
