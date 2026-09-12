import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { callGenerationSensitiveAction } from "../scripts/fcm-010-13-generation-sensitive-action.mjs";

const controller = await readFile(new URL("../scripts/fcm-010-13-macos-external-controller-v2.mjs", import.meta.url), "utf8");
const journey = await readFile(new URL("../scripts/fcm-010-13-macos-live-journey.mjs", import.meta.url), "utf8");
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

test("FCM-010.13.11 controller v2 is exact-source, production-account and run-owned-device only", () => {
  contains(controller, 'process.env.FROZEN_SOURCE_SHA');
  contains(controller, 'process.env.IMMUTABLE_RELEASE_TAG');
  contains(controller, 'FROZEN_SOURCE_SHA must be an exact commit SHA');
  contains(controller, 'IMMUTABLE_RELEASE_TAG must be an immutable desktop source tag');
  contains(controller, 'expectedDeviceId !== `gha-${runId}-${runAttempt}-macos-app`');
  contains(controller, '/^gha-[0-9]+-[0-9]+-macos-app$/u');
  contains(controller, 'name: "list_devices"');
  contains(controller, 'name: "device_call"');
  contains(controller, "https://fabushi-mcp.ombhrum.com");
  assert.equal(controller.includes("7ee12b790e18049d2b9509b0c29128dd2ace690b"), false);
  assert.equal(controller.includes("desktop-1.2.56-7ee12b790e18"), false);
  for (const forbidden of ["gloria-macbook-air", "KRIS", "runner-owned"]) {
    assert.equal(`${controller}\n${journey}`.includes(forbidden), false);
  }
});

test("generation-sensitive action re-finds generation 96 after deterministic 95 -> 96 stale race", async () => {
  const calls = [];
  let actionAttempts = 0;
  const agentId = "test:profile-navigation-trigger";
  const invokeDeviceCall = async (toolName, args) => {
    calls.push({ toolName, args: { ...args } });
    if (toolName === "fabushi.app.action") {
      actionAttempts += 1;
      if (actionAttempts === 1) {
        assert.equal(args.generation, 95);
        throw new Error("stale_app_surface_generation: expected 96, received 95");
      }
      assert.equal(args.generation, 96);
      assert.equal(args.agentId, agentId);
      return { ok: true, generation: 97 };
    }
    if (toolName === "fabushi.app.find") {
      assert.deepEqual(args, { agentId, limit: 2 });
      return { generation: 96, matches: [{ agentId, role: "button" }] };
    }
    if (toolName === "fabushi.app.snapshot") {
      return { generation: 96, elements: [{ agentId, role: "button", stable: true }] };
    }
    throw new Error(`unexpected tool ${toolName}`);
  };

  const result = await callGenerationSensitiveAction({
    invokeDeviceCall,
    args: { generation: 95, agentId, action: "invoke" },
    maxAttempts: 2,
  });

  assert.equal(result.ok, true);
  assert.deepEqual(
    calls.map(({ toolName, args }) => [toolName, args.generation ?? null]),
    [
      ["fabushi.app.action", 95],
      ["fabushi.app.find", null],
      ["fabushi.app.snapshot", null],
      ["fabushi.app.action", 96],
    ],
  );
});

test("query-resolvable action replaces stale generation-bound ref after deterministic 95 -> 98 race", async () => {
  const calls = [];
  let actionAttempts = 0;
  const query = { role: "button", name: "新建", limit: 5 };
  const invokeDeviceCall = async (toolName, args) => {
    calls.push({ toolName, args: { ...args } });
    if (toolName === "fabushi.app.action") {
      actionAttempts += 1;
      if (actionAttempts === 1) {
        assert.equal(args.generation, 95);
        assert.equal(args.ref, "g95:new-button");
        throw new Error("stale_app_surface_generation: expected 98, received 95");
      }
      assert.equal(args.generation, 98);
      assert.equal(args.ref, "g98:new-button");
      return { ok: true, generation: 99 };
    }
    if (toolName === "fabushi.app.find") {
      assert.deepEqual(args, query);
      return { generation: 98, matches: [{ role: "button", name: "新建", ref: "g98:new-button" }] };
    }
    throw new Error(`unexpected tool ${toolName}`);
  };

  const result = await callGenerationSensitiveAction({
    invokeDeviceCall,
    args: { generation: 95, ref: "g95:new-button", action: "invoke" },
    maxAttempts: 2,
    resolveLatestTarget: async () => {
      const found = await invokeDeviceCall("fabushi.app.find", query);
      assert.equal(found.matches.length, 1);
      return { generation: found.generation, target: found.matches[0] };
    },
  });

  assert.equal(result.ok, true);
  assert.deepEqual(
    calls.map(({ toolName, args }) => [toolName, args.generation ?? null, args.ref ?? null]),
    [
      ["fabushi.app.action", 95, "g95:new-button"],
      ["fabushi.app.find", null, null],
      ["fabushi.app.action", 98, "g98:new-button"],
    ],
  );
});

test("default generation retry budget survives the eight-stale production race and re-finds every retry", async () => {
  const calls = [];
  let actionAttempts = 0;
  let nextGeneration = 96;
  const query = { role: "button", name: "新建频道", limit: 5 };
  const invokeDeviceCall = async (toolName, args) => {
    calls.push({ toolName, args: { ...args } });
    if (toolName === "fabushi.app.action") {
      actionAttempts += 1;
      if (actionAttempts <= 8) {
        const expected = Number(args.generation) + 1;
        throw new Error(`stale_app_surface_generation: expected ${expected}, received ${args.generation}`);
      }
      assert.equal(args.generation, 103);
      assert.equal(args.ref, "g103:new-channel");
      return { ok: true, generation: 104 };
    }
    if (toolName === "fabushi.app.find") {
      assert.deepEqual(args, query);
      const generation = nextGeneration;
      nextGeneration += 1;
      return { generation, matches: [{ role: "button", name: "新建频道", ref: `g${generation}:new-channel` }] };
    }
    throw new Error(`unexpected tool ${toolName}`);
  };

  const result = await callGenerationSensitiveAction({
    invokeDeviceCall,
    args: { generation: 95, ref: "g95:new-channel", action: "invoke" },
    resolveLatestTarget: async () => {
      const found = await invokeDeviceCall("fabushi.app.find", query);
      assert.equal(found.matches.length, 1);
      return { generation: found.generation, target: found.matches[0] };
    },
  });

  assert.equal(result.ok, true);
  assert.equal(actionAttempts, 9);
  assert.deepEqual(
    calls.filter(({ toolName }) => toolName === "fabushi.app.find").map(({ args }) => args),
    Array.from({ length: 8 }, () => query),
  );
  assert.deepEqual(
    calls.filter(({ toolName }) => toolName === "fabushi.app.action").map(({ args }) => [args.generation, args.ref]),
    Array.from({ length: 9 }, (_, index) => [95 + index, `g${95 + index}:new-channel`]),
  );
});

test("generation-sensitive action remains fail-closed for a stale generation-bound ref without a semantic resolver", async () => {
  const calls = [];
  const invokeDeviceCall = async (toolName, args) => {
    calls.push({ toolName, args: { ...args } });
    throw new Error("stale_app_surface_generation: expected 96, received 95");
  };
  await assert.rejects(
    callGenerationSensitiveAction({
      invokeDeviceCall,
      args: { generation: 95, ref: "g95:volatile-target", action: "invoke" },
      maxAttempts: 2,
    }),
    /stale_app_surface_generation/u,
  );
  assert.deepEqual(calls.map(({ toolName }) => toolName), ["fabushi.app.action"]);
});

test("protected-account preflight performs real production OAuth and same-account discovery before dispatch", () => {
  for (const token of [
    "/oauth/register", "/oauth/authorize", "/api/auth/browser/password", "/oauth/fabushi/status", "/oauth/token",
    "devices.read devices.control", 'name: "list_devices"', "protected-account-preflight.json",
  ]) contains(preflight, token);
});

test("live journey executes every required semantic category and preserves readiness and final logout ordering", () => {
  for (const category of categories) contains(journey, `category("${category}"`, `category ${category}`);
  for (const token of [
    "valuePresent", "valueLength", "selfhosted-channel-created", "assistant peer unread badge", "new incoming assistant message",
    "test:peer-selfhosted:channel:", "message-action-edit", "message-action-forward", "message-action-delete",
    "callGenerationSensitiveAction", "generation-retry", "resolveLatestTarget", "chooseUniqueMatch",
  ]) contains(journey, token);

  const createChannelAction = journey.indexOf('await invokeNamed("新建频道");');
  const channelDialogReady = journey.indexOf('await waitFor({ role: "textbox", name: "名称", state: "visible" }', createChannelAction);
  const channelNameSet = journey.indexOf('await act({ role: "textbox", name: "名称" }, "setValue", name);', channelDialogReady);
  const channelDescriptionSet = journey.indexOf('await act({ role: "textbox", name: "描述" }, "setValue"', channelNameSet);
  const channelCreateCommit = journey.indexOf('await invokeNamed("创建频道");', channelDescriptionSet);
  const messengerReady = journey.indexOf('await waitFor({ agentId: "test:messenger-input", state: "visible" }', channelCreateCommit);
  const channelProjectionReady = journey.indexOf('await waitFor({ text: name, state: "present" }', messengerReady);
  const channelProjectionFind = journey.indexOf('const found = await find({ text: name, limit: 100 });', channelProjectionReady);
  assert.ok(
    createChannelAction >= 0 && channelDialogReady > createChannelAction && channelNameSet > channelDialogReady && channelDescriptionSet > channelNameSet,
    "channel creation must use App Surface label semantics: invoke -> wait 名称 -> set 名称 -> set 描述",
  );
  assert.ok(
    channelCreateCommit > channelDescriptionSet && messengerReady > channelCreateCommit && channelProjectionReady > messengerReady && channelProjectionFind > channelProjectionReady,
    "created channel projection must be explicitly present before resolving its peer row",
  );
  assert.equal(journey.includes('role: "textbox", name: "频道名称"'), false, "channel placeholder must not be used as an App Surface name selector");
  assert.equal(journey.includes('role: "textbox", name: "频道简介"'), false, "channel description placeholder must not be used as an App Surface name selector");

  const assistantOpen = journey.indexOf('async function openAssistantConversation()');
  const assistantChatProjection = journey.indexOf('await navigateSection("聊天");', assistantOpen);
  const assistantFind = journey.indexOf('const found = await find({ agentId: ASSISTANT_PEER_ID, limit: 1 });', assistantChatProjection);
  const assistantUnique = journey.indexOf('const peer = chooseUniqueMatch(found, { agentId: ASSISTANT_PEER_ID });', assistantFind);
  const assistantEvidence = journey.indexOf('record("assistant-semantic-projection-resolved"', assistantUnique);
  const assistantInvoke = journey.indexOf('agentId: ASSISTANT_PEER_ID, action: "invoke"', assistantEvidence);
  assert.ok(
    assistantOpen >= 0 && assistantChatProjection > assistantOpen && assistantFind > assistantChatProjection && assistantUnique > assistantFind && assistantEvidence > assistantUnique && assistantInvoke > assistantEvidence,
    "assistant journey must return to 聊天, resolve the exact semantic projection uniquely, record it, then invoke the exact stable id",
  );

  contains(journey, "TFI_MACOS_FULL_JOURNEY READY_FOR_LOGOUT PASS categories=");
  const ready = journey.indexOf("TFI_MACOS_FULL_JOURNEY READY_FOR_LOGOUT PASS categories=");
  const finish = journey.indexOf('callDevice("ci_session_finish"', ready);
  const freshSnapshot = journey.indexOf("const fresh = await snapshot();", finish);
  const logout = journey.indexOf('agentId: "settings-logout", action: "invoke"', freshSnapshot);
  const returned = journey.indexOf("return { categories: completedCategories", logout);
  assert.ok(
    ready >= 0 && finish > ready && freshSnapshot > finish && logout > freshSnapshot && returned > logout,
    "READY -> ci_session_finish -> fresh snapshot -> exact settings-logout order must be preserved",
  );
  assert.equal(journey.slice(logout + 1, returned).includes('callDevice("'), false, "no remote device call may occur after exact settings-logout in the successful pass path");
});

test("orchestrator auto-binds the published immutable Release, dispatches its exact source, and still requires target green evidence", () => {
  for (const token of [
    "needs: protected-account-preflight",
    "actions: write",
    "TARGET_WORKFLOW_ID: '350936009'",
    "release:\n    types: [published]",
    "Resolve immutable exact-source macOS Release binding",
    "test \"$(jq -r '.immutable' <<<\"$release\")\" = true",
    "tag_sha=\"$(gh api \"repos/$GITHUB_REPOSITORY/git/ref/tags/$release_tag\" --jq '.object.sha')\"",
    '[[ "$release_tag" == *"-$short_source" ]]',
    'actions/workflows/$TARGET_WORKFLOW_ID/dispatches',
    '-f ref="$IMMUTABLE_RELEASE_TAG"',
    'expected_device_id="gha-${target_run_id}-${target_run_attempt}-macos-app"',
    "FROZEN_SOURCE_SHA: ${{ steps.binding.outputs.source_sha }}",
    "IMMUTABLE_RELEASE_TAG: ${{ steps.binding.outputs.release_tag }}",
    "fcm-010-13-macos-external-controller-v2.mjs",
    'fcm-010.13.11.external-controller.v2',
    'test "$(jq -r \'.conclusion\' <<<"$final")" = success',
    'fabushi-macos-interactive-evidence-${TARGET_RUN_ID}-${TARGET_RUN_ATTEMPT}',
    '(.digest | startswith("sha256:"))',
  ]) contains(workflow, token);
  assert.equal(workflow.includes("FROZEN_SOURCE_SHA: 7ee12b790e18049d2b9509b0c29128dd2ace690b"), false);
  assert.equal(workflow.includes("IMMUTABLE_RELEASE_TAG: desktop-1.2.56-7ee12b790e18"), false);
});
