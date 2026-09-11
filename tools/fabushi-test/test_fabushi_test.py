import importlib.util
import json
from pathlib import Path
import sys
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

    def test_registry_rejects_ambiguous_cargo_package_selection(self):
        commands = [
            ['cargo', 'test', '-p', 'alpha', '--package=beta'],
            ['cargo', 'test', '--workspace'],
            ['cargo', 'test', '--all'],
            ['cargo', 'test'],
        ]
        for command in commands:
            with self.subTest(command=command), tempfile.TemporaryDirectory() as d:
                p = Path(d) / 'registry.json'
                suite = {**self.suite, 'argv': command}
                p.write_text(json.dumps({'version': 1, 'suites': [suite]}))
                with self.assertRaisesRegex(ValueError, 'exactly one package'):
                    m.registry(p, Path(d))

    def test_registry_accepts_exact_single_cargo_package(self):
        for command in [['cargo', 'test', '-p', 'alpha'], ['cargo', 'test', '--package=alpha']]:
            with self.subTest(command=command), tempfile.TemporaryDirectory() as d:
                p = Path(d) / 'registry.json'
                suite = {**self.suite, 'argv': command}
                p.write_text(json.dumps({'version': 1, 'suites': [suite]}))
                self.assertEqual(m.registry(p, Path(d))[0]['argv'], command)

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

    def test_process_success_nonzero_missing_and_zero_test_proof(self):
        cases = [
            ([sys.executable, '-c', 'print("PROOF")'], 'PROOF', 'passed'),
            ([sys.executable, '-c', 'raise SystemExit(7)'], 'PROOF', 'failed'),
            ([sys.executable, '-c', 'print("zero tests")'], 'PROOF', 'failed'),
            (['/definitely-missing-fcm-command'], 'PROOF', 'blocked'),
        ]
        for argv, pattern, expected in cases:
            with self.subTest(argv=argv), tempfile.TemporaryDirectory() as d:
                suite = {**self.suite, 'argv': argv, 'pass_pattern': pattern}
                result = m.run_suite(suite, Path(d), Path(d))
                self.assertEqual(result['status'], expected)
                self.assertIn('log_sha256', result)

    def test_process_timeout_fails(self):
        with tempfile.TemporaryDirectory() as d:
            suite = {**self.suite, 'argv': [sys.executable, '-c', 'import time; time.sleep(5)'], 'timeout_seconds': 1}
            result = m.run_suite(suite, Path(d), Path(d))
            self.assertEqual(result['status'], 'timeout')
            self.assertLess(result['duration_seconds'], 4)

    def test_atomic_json_roundtrip(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'sub' / 'result.json'
            m.atomic_json(p, {'status': 'failed'})
            self.assertEqual(json.loads(p.read_text()), {'status': 'failed'})
            self.assertFalse(p.with_name(p.name + '.tmp').exists())


if __name__ == '__main__':
    unittest.main()
