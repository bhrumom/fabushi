import importlib.util
import sys
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "select-mahayana-fast-tests.py"
SPEC = importlib.util.spec_from_file_location("selector", SCRIPT)
assert SPEC and SPEC.loader
selector = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = selector
SPEC.loader.exec_module(selector)


class SelectMahayanaFastTests(unittest.TestCase):
    def test_main_push_forces_full_suite(self):
        selected = selector.select(
            "push",
            ["third_party/mahayana/mahayana-rs/mahayana-test-driver-protocol/src/lib.rs"],
        )
        self.assertTrue(selected.full_suite)
        self.assertEqual(tuple(selector.GROUPS), selected.groups)

    def test_merge_group_forces_full_suite(self):
        selected = selector.select(
            "merge_group",
            ["third_party/mahayana/mahayana-rs/mahayana-test-driver-protocol/src/lib.rs"],
        )
        self.assertTrue(selected.full_suite)
        self.assertEqual(tuple(selector.GROUPS), selected.groups)

    def test_test_driver_protocol_is_leaf_selected(self):
        selected = selector.select(
            "pull_request",
            ["third_party/mahayana/mahayana-rs/mahayana-test-driver-protocol/src/lib.rs"],
        )
        self.assertFalse(selected.full_suite)
        self.assertEqual(("test_driver",), selected.groups)

    def test_protocol_change_expands_to_host_consumer_group(self):
        selected = selector.select(
            "pull_request",
            ["third_party/mahayana/mahayana-rs/mahayana-miniapp-protocol/src/lib.rs"],
        )
        self.assertFalse(selected.full_suite)
        self.assertEqual(("protocol_bridge", "host_ffi"), selected.groups)

    def test_multiple_modeled_paths_union_groups_in_stable_order(self):
        selected = selector.select(
            "pull_request",
            [
                "third_party/mahayana/mahayana-rs/mahayana-secrets/src/lib.rs",
                "third_party/mahayana/mahayana-rs/mahayana-mcp-runtime/src/lib.rs",
            ],
        )
        self.assertFalse(selected.full_suite)
        self.assertEqual(("auth_product", "mcp_agent", "host_ffi"), selected.groups)

    def test_unknown_mahayana_crate_fails_safe_to_full(self):
        selected = selector.select(
            "pull_request",
            ["third_party/mahayana/mahayana-rs/mahayana-product/src/lib.rs"],
        )
        self.assertTrue(selected.full_suite)
        self.assertIn("unmodeled Mahayana path", selected.reason)

    def test_workspace_manifest_fails_safe_to_full(self):
        selected = selector.select(
            "pull_request",
            ["third_party/mahayana/mahayana-rs/Cargo.toml"],
        )
        self.assertTrue(selected.full_suite)
        self.assertIn("shared Mahayana workspace", selected.reason)

    def test_native_messaging_fails_safe_to_full(self):
        selected = selector.select(
            "pull_request", ["native/mahayana-messaging/src/lib.rs"]
        )
        self.assertTrue(selected.full_suite)
        self.assertIn("shared native messaging", selected.reason)

    def test_source_boundary_change_fails_safe_to_full(self):
        selected = selector.select(
            "pull_request", ["scripts/check-mahayana-source-boundary.py"]
        )
        self.assertTrue(selected.full_suite)
        self.assertIn("selector/workflow", selected.reason)

    def test_selector_change_fails_safe_to_full(self):
        selected = selector.select(
            "pull_request", ["scripts/select-mahayana-fast-tests.py"]
        )
        self.assertTrue(selected.full_suite)
        self.assertIn("selector/workflow", selected.reason)

    def test_fast_suite_registry_change_fails_safe_to_full(self):
        selected = selector.select(
            "pull_request", ["tools/fabushi-test/suites.json"]
        )
        self.assertTrue(selected.full_suite)
        self.assertIn("selector/workflow", selected.reason)

    def test_unrelated_documentation_runs_no_rust_surface(self):
        selected = selector.select("pull_request", ["docs/fast-feature-testing.md"])
        self.assertFalse(selected.full_suite)
        self.assertFalse(selected.run_rust)
        self.assertEqual((), selected.groups)

    def test_paths_are_normalized_and_deduplicated(self):
        selected = selector.select(
            "pull_request",
            [
                "./third_party/mahayana/mahayana-rs/mahayana-host/src/lib.rs",
                "third_party\\mahayana\\mahayana-rs\\mahayana-host\\src\\lib.rs",
            ],
        )
        self.assertEqual(("host_ffi",), selected.groups)
        self.assertEqual(1, len(selected.relevant_files))


if __name__ == "__main__":
    unittest.main()
