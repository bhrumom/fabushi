import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import vm from "node:vm";

const source = await readFile(new URL("../chrome-platform/extension/userscript-navigation-guard.js", import.meta.url), "utf8");
const STORAGE_KEY = "fabushi.userscriptNavigation.v1";

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function fixture() {
  const listeners = { message: [], updated: [], removed: [] };
  const stored = {};
  const tab = {
    id: 7,
    url: "https://chatgpt.com/c/working",
    title: "ChatGPT",
    status: "complete",
    discarded: false,
  };
  const chrome = {
    storage: {
      session: {
        get: async () => ({ [STORAGE_KEY]: clone(stored[STORAGE_KEY]) }),
        set: async (value) => {
          stored[STORAGE_KEY] = clone(value[STORAGE_KEY]);
        },
      },
    },
    runtime: {
      onMessage: { addListener: (listener) => listeners.message.push(listener) },
    },
    tabs: {
      get: async (tabId) => {
        if (Number(tabId) !== tab.id) throw new Error("tab not found");
        return clone(tab);
      },
      onUpdated: { addListener: (listener) => listeners.updated.push(listener) },
      onRemoved: { addListener: (listener) => listeners.removed.push(listener) },
    },
  };
  const context = vm.createContext({
    chrome,
    URL,
    Set,
    Object,
    Number,
    String,
    Array,
    Date,
    Math,
    Promise,
    Error,
    Boolean,
    JSON,
    console,
    crypto: { randomUUID: () => "test-navigation-lease" },
    setTimeout,
    clearTimeout,
  });
  vm.runInContext(
    `${source}
globalThis.__test = { requestNavigationGuard };`,
    context,
  );
  return { context, listeners, stored, tab };
}

async function send(state, message, senderURL = state.tab.url) {
  return new Promise((resolve) => {
    state.listeners.message[0](
      message,
      { tab: { id: state.tab.id, url: senderURL } },
      resolve,
    );
  });
}

function request(overrides = {}) {
  return {
    type: "fabushi.userscript.navigation.request",
    pluginId: "chatgpt-auto-confirm",
    scriptId: "chatgpt-auto-confirm",
    payload: {
      capability: "tab-navigation-guard",
      ownerTabId: "workspace-owner",
      taskId: "task-1",
      taskURL: "https://chatgpt.com/c/working",
      targetURL: "https://chatgpt.com/c/review",
      phase: "review",
      round: 2,
      goalRevision: 7,
      reason: "review-route",
      ...overrides,
    },
  };
}

test("host grants scoped route changes and throttles repeated multi-task rotation", async () => {
  const state = fixture();
  const first = await send(state, request());
  assert.equal(first.ok, true);
  assert.equal(first.granted, true);
  assert.equal(first.capability, "tab-navigation-guard");
  assert.ok(first.leaseId);
  assert.equal(state.stored[STORAGE_KEY].tabs["7"].inFlight.taskId, "task-1");
  assert.equal(state.stored[STORAGE_KEY].tabs["7"].inFlight.goalRevision, 7);

  state.tab.url = "https://chatgpt.com/c/review";
  state.listeners.updated[0](7, { status: "complete", url: state.tab.url }, clone(state.tab));
  await new Promise((resolve) => setTimeout(resolve, 0));

  const second = await send(
    state,
    request({ targetURL: "https://chatgpt.com/c/next" }),
    state.tab.url,
  );
  assert.equal(second.ok, true);
  assert.equal(second.granted, false);
  assert.equal(second.reason, "cooldown");
  assert.ok(second.retryAfterMs > 0);
});

test("host refuses crash and unloaded renderer pages, then permits an explicit recovery request", async () => {
  const state = fixture();
  state.tab.url = "chrome-error://chromewebdata/";
  state.tab.title = "Aw, Snap!";
  state.tab.status = "unloaded";

  const denied = await send(state, request(), "https://chatgpt.com/c/working");
  assert.equal(denied.ok, true);
  assert.equal(denied.granted, false);
  assert.equal(denied.reason, "renderer-unavailable");

  state.tab.url = "https://chatgpt.com/c/working";
  state.tab.title = "ChatGPT";
  state.tab.status = "complete";
  const recovered = await send(
    state,
    request({
      targetURL: "https://chatgpt.com/c/review#fabushi-resume=recovery-token",
      recovery: true,
      force: true,
      reason: "renderer-recovery",
    }),
  );
  assert.equal(recovered.ok, true);
  assert.equal(recovered.granted, true);
  assert.equal(recovered.reason, "forced");
});

test("host rejects invalid identities and non-ChatGPT navigation targets", async () => {
  const state = fixture();
  const invalidTarget = await send(state, request({ targetURL: "https://example.com/" }));
  assert.equal(invalidTarget.ok, false);
  assert.equal(invalidTarget.granted, false);
  assert.equal(invalidTarget.reason, "invalid-request");

  const invalidCapability = await send(state, request({
    payload: { capability: "other-capability" },
  }));
  assert.equal(invalidCapability.ok, false);
  assert.equal(invalidCapability.granted, false);
  assert.equal(invalidCapability.reason, "invalid-request");
});
