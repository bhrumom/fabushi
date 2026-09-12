import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const controller = await readFile(new URL("../scripts/fcm-010-13-macos-external-controller.mjs", import.meta.url), "utf8");
const preflight = await readFile(new URL("../scripts/fcm-010-13-protected-account-preflight.mjs", import.meta.url), "utf8");
const workflow = await readFile(new URL("../../.github/workflows/fcm-010-13-11-macos-external-controller.yml", import.meta.url), "utf8");

const categories = [
  "startup", "login", "main", "conversations", "search", "send", "receive", "reply", "edit", "delete",
  "forward", "draft", "pin", "mute", "unread", "contacts", "groups", "bot", "agent", "miniapp", "webmcp",
  "media", "file", "notifications", "sync", "settings", "update",
];

function contains(text, literal, label = literal) {
  assert.ok(text.includes(literal), `missing required contract token: ${label}`);
}

test("FCM-010.13.11 external controller is exact-source, production-account and run-owned-device only", () => {
  contains(controller, "7ee12b790e18049d2b9509b0c29128dd2ace690b");
  contains(controller, "desktop-1.2.56-7ee12b790e18");
  contains(controller, 'expectedDeviceId !== `gha-${runId}-${runAttempt}-macos-app`');
  contains(controller, '/^gha-[0-9]+-[0-9]+-macos-app$/u');
  contains(controller, 'name: "list_devices"');
  contains(controller, 'name: "device_call"');
  contains(controller, "https://fabushi-mcp.ombhrum.com");
  assert.equal(controller.includes("gloria-macbook-air"), false);
  assert.equal(controller.includes("KRIS"), false);
  assert.equal(controller.includes("runner-owned"), false);
});

test("protected-account preflight performs real production OAuth and same-account discovery before dispatch", () => {
  for (const token of [
    "/oauth/register", "/oauth/authorize", "/api/auth/browser/password", "/oauth/fabushi/status", "/oauth/token",
    "devices.read devices.control", 'name: "list_devices"', "protected-account-preflight.json",
  ]) contains(preflight, token);
});

test("controller executes every frozen macOS full-journey category and preserves logout ordering", () => {
  for (const category of categories) contains(controller, `category("${category}"`, `category ${category}`);
  contains(controller, "TFI_MACOS_FULL_JOURNEY READY_FOR_LOGOUT PASS categories=");
  const ready = controller.indexOf("TFI_MACOS_FULL_JOURNEY READY_FOR_LOGOUT PASS categories=");
  const finish = controller.indexOf('callDevice("ci_session_finish"', ready);
  const logout = controller.indexOf('agentId: "settings-logout", action: "invoke"', finish);
  const catchBoundary = controller.indexOf("} catch (error) {", logout);
  assert.ok(ready >= 0 && finish > ready && logout > finish && catchBoundary > logout, "READY -> ci_session_finish -> exact settings-logout order must be preserved");
  const remainingPassPath = controller.slice(logout + 1, catchBoundary);
  assert.equal(remainingPassPath.includes('callDevice("'), false, "no remote device call may occur after exact settings-logout in the successful pass path");
});

test("orchestrator gates dispatch on account preflight and dispatches only the immutable frozen tag", () => {
  for (const token of [
    "needs: protected-account-preflight",
    "actions: write",
    "TARGET_WORKFLOW_ID: '350936009'",
    "FROZEN_SOURCE_SHA: 7ee12b790e18049d2b9509b0c29128dd2ace690b",
    "IMMUTABLE_RELEASE_TAG: desktop-1.2.56-7ee12b790e18",
    'actions/workflows/$TARGET_WORKFLOW_ID/dispatches',
    '-f ref="$IMMUTABLE_RELEASE_TAG"',
    'expected_device_id="gha-${target_run_id}-${target_run_attempt}-macos-app"',
    'test "$(jq -r \'.conclusion\' <<<"$final")" = success',
    'fabushi-macos-interactive-evidence-${TARGET_RUN_ID}-${TARGET_RUN_ATTEMPT}',
  ]) contains(workflow, token);
});
