import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import vm from "node:vm";

const source = await readFile(new URL("../chrome-platform/extension/userscript-recovery.js", import.meta.url), "utf8");

function fixture() {
  const listeners = { message: [], alarm: [], updated: [], removed: [] };
  const records = {};
  const tabs = new Map([[7, { id:7, url:"https://chatgpt.com/c/working", title:"ChatGPT", status:"complete" }]]);
  const updates = [];
  const creates = [];
  const chrome = {
    storage: {
      local: {
        get: async () => ({ "fabushi.userscriptRecovery.v1": structuredClone(records) }),
        set: async (value) => {
          for (const key of Object.keys(records)) delete records[key];
          Object.assign(records, structuredClone(value["fabushi.userscriptRecovery.v1"] || {}));
        },
      },
    },
    alarms: {
      create: async () => {},
      onAlarm: { addListener: (listener) => listeners.alarm.push(listener) },
    },
    runtime: { onMessage: { addListener: (listener) => listeners.message.push(listener) } },
    tabs: {
      get: async (tabId) => {
        const tab = tabs.get(Number(tabId));
        if (!tab) throw new Error("tab not found");
        return { ...tab };
      },
      update: async (tabId, details) => {
        const tab = tabs.get(Number(tabId));
        if (!tab) throw new Error("tab not found");
        Object.assign(tab, details);
        updates.push({ tabId:Number(tabId), details:{ ...details } });
        return { ...tab };
      },
      create: async (details) => {
        const id = 20 + creates.length;
        const tab = { id, ...details };
        tabs.set(id, tab);
        creates.push({ ...tab });
        return { ...tab };
      },
      onUpdated: { addListener: (listener) => listeners.updated.push(listener) },
      onRemoved: { addListener: (listener) => listeners.removed.push(listener) },
    },
  };
  const context = vm.createContext({
    chrome,
    URL,
    Set,
    Map,
    Object,
    Number,
    String,
    Array,
    Date,
    Math,
    Promise,
    Error,
    Boolean,
    structuredClone,
    console,
    crypto: { randomUUID: () => "test-random-id" },
    setTimeout,
    clearTimeout,
  });
  vm.runInContext(`${source}\nglobalThis.__test = { requestRecoveryCapability, releaseRecoveryCapability, scanRecoveryRecords };`, context);
  return { context, listeners, records, tabs, updates, creates };
}

async function send(fixtureState, message, sender) {
  return new Promise((resolve) => {
    fixtureState.listeners.message[0](message, sender, resolve);
  });
}

function payload(overrides = {}) {
  return {
    capability: "tab-recovery",
    ownerTabId: "workspace-owner",
    taskId: "task-1",
    taskState: "waiting",
    taskURL: "https://chatgpt.com/c/working",
    recoveryURL: "https://chatgpt.com/c/working#fabushi-resume=resume-token",
    attachmentIds: ["attachment-1"],
    ...overrides,
  };
}

test("host grants a scoped recovery lease and keeps task content out of storage", async () => {
  const state = fixture();
  const result = await send(state, { type:"fabushi.userscript.recovery.request", payload:payload({ goal:"must not persist" }) }, { tab:{ id:7, url:"https://chatgpt.com/c/working" } });
  assert.equal(result.ok, true);
  assert.equal(result.granted, true);
  const record = state.records["workspace-owner"];
  assert.equal(record.tabId,7);
  assert.equal(record.recoveryURL,"https://chatgpt.com/c/working#fabushi-resume=resume-token");
  assert.deepEqual(record.attachmentIds,["attachment-1"]);
  assert.equal(record.goal,undefined);
  assert.equal(record.prompt,undefined);
  assert.equal(record.file,undefined);
});

test("crashed ChatGPT tabs are recovered through the registered URL and not reopened after close", async () => {
  const state = fixture();
  await send(state, { type:"fabushi.userscript.recovery.request", payload:payload() }, { tab:{ id:7, url:"https://chatgpt.com/c/working" } });
  state.tabs.get(7).url = "chrome-error://chromewebdata/";
  state.tabs.get(7).title = "Aw, Snap!";
  state.tabs.get(7).status = "unloaded";
  await state.context.__test.scanRecoveryRecords("test");
  assert.equal(state.updates.length,1);
  assert.equal(state.updates[0].tabId,7);
  assert.equal(state.updates[0].details.url,"https://chatgpt.com/c/working#fabushi-resume=resume-token");
  assert.equal(state.records["workspace-owner"].status,"recovering");
  state.listeners.removed[0](7);
  await new Promise((resolve) => setTimeout(resolve,0));
  assert.equal(state.records["workspace-owner"],undefined);
  assert.equal(state.creates.length,0);
});

test("lease refresh keeps the bounded recovery budget and does not create repeated takeovers", async () => {
  const state = fixture();
  await send(state, { type:"fabushi.userscript.recovery.request", payload:payload() }, { tab:{ id:7, url:"https://chatgpt.com/c/working" } });
  state.records["workspace-owner"].reloadUsed = true;
  state.records["workspace-owner"].takeoverUsed = true;
  state.records["workspace-owner"].recoveryCount = 2;
  state.records["workspace-owner"].status = "recovering";
  await send(state, { type:"fabushi.userscript.recovery.request", payload:payload() }, { tab:{ id:7, url:"https://chatgpt.com/c/working" } });
  assert.equal(state.records["workspace-owner"].reloadUsed, true);
  assert.equal(state.records["workspace-owner"].takeoverUsed, true);
  assert.equal(state.records["workspace-owner"].recoveryCount, 2);
  state.tabs.delete(7);
  await state.context.__test.scanRecoveryRecords("test");
  assert.equal(state.creates.length, 0);
  assert.equal(state.records["workspace-owner"].status, "exhausted");
});

test("an unavailable original tab gets one takeover and never an unbounded tab chain", async () => {
  const state = fixture();
  await send(state, { type:"fabushi.userscript.recovery.request", payload:payload() }, { tab:{ id:7, url:"https://chatgpt.com/c/working" } });
  state.tabs.delete(7);
  await state.context.__test.scanRecoveryRecords("test");
  assert.equal(state.creates.length, 1);
  assert.equal(state.records["workspace-owner"].lastRecoveryAction, "takeover");
  const replacementId = state.creates[0].id;
  state.tabs.delete(replacementId);
  state.records["workspace-owner"].lastRecoveryAt = 0;
  await state.context.__test.scanRecoveryRecords("test");
  assert.equal(state.creates.length, 1);
  assert.equal(state.records["workspace-owner"].status, "exhausted");
});

test("host rejects unsafe recovery URLs and unsupported blocked tasks", async () => {
  const state = fixture();
  const external = await send(state, { type:"fabushi.userscript.recovery.request", payload:payload({ recoveryURL:"https://example.com/#fabushi-resume=x" }) }, { tab:{ id:7, url:"https://chatgpt.com/c/working" } });
  assert.equal(external.ok,false);
  const blocked = await send(state, { type:"fabushi.userscript.recovery.request", payload:payload({ taskState:"blocked", recoveryEligible:false }) }, { tab:{ id:7, url:"https://chatgpt.com/c/working" } });
  assert.equal(blocked.ok,false);
  assert.deepEqual(state.records,{});
});
