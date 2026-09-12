import { callGenerationSensitiveAction } from "./fcm-010-13-generation-sensitive-action.mjs";

const REQUIRED_CATEGORIES = [
  "startup", "login", "main", "conversations", "search", "send", "receive", "reply", "edit", "delete",
  "forward", "draft", "pin", "mute", "unread", "contacts", "groups", "bot", "agent", "miniapp", "webmcp",
  "media", "file", "notifications", "sync", "settings", "update",
];
const ASSISTANT_PEER_ID = "test:peer-legacy:conversation:mahayana-ai:agent:assistant";
const MESSAGE_ROW_PREFIX = "message-actions:";
const MESSENGER_INPUT_AGENT_ID = "test:messenger-input";
const PROFILE_NAVIGATION_AGENT_IDS = new Map([
  ["聊天", "profile-navigation-chats"],
  ["联系人", "profile-navigation-contacts"],
  ["Bots", "profile-navigation-bots"],
  ["群组", "profile-navigation-groups"],
  ["频道", "profile-navigation-channels"],
  ["设置", "profile-navigation-settings"],
]);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export function newestMessageRowsFromSnapshot(snapshotValue, limit = 100) {
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
    throw new Error(`message snapshot limit must be an integer in 1..100; received ${String(limit)}`);
  }
  const elements = Array.isArray(snapshotValue?.elements) ? snapshotValue.elements : [];
  const composerIndex = elements.findIndex((item) => item?.agentId === MESSENGER_INPUT_AGENT_ID);
  if (composerIndex < 0) {
    throw new Error("message_snapshot_incomplete: exact messenger input sentinel missing");
  }
  return elements
    .slice(0, composerIndex)
    .filter((item) => item?.role === "article" && String(item?.agentId || "").startsWith(MESSAGE_ROW_PREFIX))
    .slice(-limit);
}

export function peerHasUnreadBadgeFromSnapshot(snapshotValue, peerAgentId) {
  if (!String(peerAgentId || "").startsWith("test:peer-")) {
    throw new Error(`peer unread snapshot requires a stable test:peer-* id; received ${String(peerAgentId || "<empty>")}`);
  }
  const elements = Array.isArray(snapshotValue?.elements) ? snapshotValue.elements : [];
  const peerIndex = elements.findIndex((item) => item?.agentId === peerAgentId);
  if (peerIndex < 0) return false;
  let endIndex = elements.length;
  for (let index = peerIndex + 1; index < elements.length; index += 1) {
    const agentId = String(elements[index]?.agentId || "");
    if (agentId.startsWith("test:peer-") && agentId !== peerAgentId) {
      endIndex = index;
      break;
    }
  }
  return elements
    .slice(peerIndex + 1, endIndex)
    .some((item) => item?.tag === "b" && item?.visible !== false);
}

export function matchingTargets(found, query, predicate) {
  const matches = Array.isArray(found?.matches) ? found.matches : [];
  return matches.filter((item) => {
    if (query.agentId && item?.agentId !== query.agentId) return false;
    if (query.role && item?.role !== query.role) return false;
    // fabushi.app.find owns text/name matching against the unredacted App Surface.
    // Production responses intentionally redact returned text/name, so re-reading
    // those fields here would turn a genuine server-side match into a false miss.
    return predicate ? Boolean(predicate(item)) : true;
  });
}

export function createMessageReceiveTracker({
  callDevice,
  sleepFn = sleep,
  timeoutMs = 90_000,
  intervalMs = 800,
  maxAttempts = null,
}) {
  if (typeof callDevice !== "function") throw new Error("message receive tracker requires callDevice");
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) throw new Error("message receive tracker timeout must be positive");
  if (!Number.isFinite(intervalMs) || intervalMs < 0) throw new Error("message receive tracker interval must be non-negative");
  if (maxAttempts != null && (!Number.isInteger(maxAttempts) || maxAttempts < 1)) throw new Error("message receive tracker maxAttempts must be a positive integer");

  async function readNewestRows() {
    const fresh = await callDevice("fabushi.app.snapshot", { maxElements: 500, includeText: true });
    return newestMessageRowsFromSnapshot(fresh);
  }

  async function captureBeforeSend(send) {
    if (typeof send !== "function") throw new Error("message receive tracker requires a send callback");
    const beforeIds = new Set((await readNewestRows()).map((item) => String(item?.agentId || "")));
    const sentMessageRowId = String(await send() || "");
    if (!sentMessageRowId.startsWith(MESSAGE_ROW_PREFIX)) {
      throw new Error(`sent_message_identity_missing: ${sentMessageRowId || "<empty>"}`);
    }
    if (beforeIds.has(sentMessageRowId)) {
      throw new Error(`sent_message_identity_not_new: ${sentMessageRowId}`);
    }
    return { beforeIds, sentMessageRowId };
  }

  async function waitForIncoming(beforeIds, sentMessageRowId) {
    if (!(beforeIds instanceof Set)) throw new Error("message receive tracker requires a Set baseline");
    if (!String(sentMessageRowId || "").startsWith(MESSAGE_ROW_PREFIX)) throw new Error("message receive tracker requires the exact sent message row identity");
    const deadline = Date.now() + timeoutMs;
    let attempt = 0;
    let last = null;
    while (Date.now() < deadline && (maxAttempts == null || attempt < maxAttempts)) {
      attempt += 1;
      const rows = await readNewestRows();
      const candidate = rows.find((item) => {
        const id = String(item?.agentId || "");
        const text = String(item?.text || item?.name || "");
        return !beforeIds.has(id) && id !== sentMessageRowId && Boolean(text);
      });
      if (candidate) {
        return { agentId: candidate.agentId, text: String(candidate.text || candidate.name || "").slice(0, 240) };
      }
      last = rows.at(-1) ?? null;
      if (intervalMs > 0) await sleepFn(intervalMs);
    }
    throw new Error(`new incoming assistant message timed out; last=${JSON.stringify(last)}`);
  }

  return { captureBeforeSend, waitForIncoming };
}

export async function runLiveJourney({ callDevice: invokeDeviceCall, expectedDeviceId, runId, runAttempt, record }) {
  const completedCategories = [];
  async function callDevice(toolName, args = {}) {
    if (toolName !== "fabushi.app.action") return invokeDeviceCall(toolName, args);
    return callGenerationSensitiveAction({
      invokeDeviceCall,
      args,
      onRetry: ({ attempt, resolver, agentId, previousGeneration, findGeneration, refreshedGeneration }) => {
        record("generation-retry", { attempt, resolver, agentId, previousGeneration, findGeneration, refreshedGeneration });
      },
    });
  }
  const messageReceiveTracker = createMessageReceiveTracker({ callDevice });
  async function snapshot() { return callDevice("fabushi.app.snapshot", { maxElements: 500, includeText: true }); }
  async function find(query) { return callDevice("fabushi.app.find", query); }
  async function waitFor(query, timeoutMs = 30_000) {
    const result = await callDevice("fabushi.app.wait", { ...query, timeoutMs });
    if (result.passed !== true) throw new Error(`wait failed: ${JSON.stringify(query)} :: ${JSON.stringify(result.failures || [])}`);
    return result;
  }
  async function assertUi(query) {
    const result = await callDevice("fabushi.app.assert", query);
    if (result.passed !== true) throw new Error(`assert failed: ${JSON.stringify(query)} :: ${JSON.stringify(result.failures || [])}`);
    return result;
  }
  function chooseMatch(found, query, predicate) {
    const selected = matchingTargets(found, query, predicate)[0];
    if (!selected) throw new Error(`semantic target not found: ${JSON.stringify(query)}`);
    return selected;
  }
  function chooseUniqueMatch(found, query, predicate) {
    const matches = matchingTargets(found, query, predicate);
    if (matches.length !== 1) {
      throw new Error(`semantic target not uniquely resolvable: ${JSON.stringify(query)} count=${matches.length}`);
    }
    return matches[0];
  }
  async function act(query, action, value, predicate) {
    const found = await find(query);
    const target = chooseMatch(found, query, predicate);
    const args = { generation: found.generation, action, ...(target.agentId ? { agentId: target.agentId } : { ref: target.ref }), ...(value === undefined ? {} : { value }) };
    if (target.agentId) return callDevice("fabushi.app.action", args);
    if (!target.ref) throw new Error(`semantic target has neither stable agentId nor generation-bound ref: ${JSON.stringify(query)}`);
    return callGenerationSensitiveAction({
      invokeDeviceCall,
      args,
      resolveLatestTarget: async () => {
        const refreshed = await invokeDeviceCall("fabushi.app.find", query);
        return { generation: refreshed.generation, target: chooseUniqueMatch(refreshed, query, predicate) };
      },
      onRetry: ({ attempt, resolver, agentId, previousGeneration, findGeneration, refreshedGeneration }) => {
        record("generation-retry", { attempt, resolver, agentId, previousGeneration, findGeneration, refreshedGeneration, query });
      },
    });
  }
  async function poll(description, probe, timeoutMs = 60_000, intervalMs = 600) {
    const deadline = Date.now() + timeoutMs;
    let last = null;
    while (Date.now() < deadline) {
      last = await probe();
      if (last?.ok) return last.value;
      await sleep(intervalMs);
    }
    throw new Error(`${description} timed out; last=${JSON.stringify(last?.value ?? last)}`);
  }
  const testId = (id) => ({ agentId: `test:${id}` });
  const invokeTest = (id) => act(testId(id), "invoke");
  const setTest = (id, value) => act(testId(id), "setValue", value);
  const invokeNamed = (name) => act({ role: "button", name }, "invoke");
  async function category(name, fn) {
    record("category-start", { category: name });
    await fn();
    if (!completedCategories.includes(name)) completedCategories.push(name);
    record("category-pass", { category: name });
  }
  async function waitForAppReady() {
    let session = null;
    for (let attempt = 0; attempt < 180; attempt += 1) {
      session = await callDevice("ci_session_status", {});
      if (session.deviceId !== expectedDeviceId) throw new Error(`CI session switched away from exact device: ${JSON.stringify(session)}`);
      if (session.appReady === true) {
        record("app-ready", { phase: session.phase || null, updatedAt: session.updatedAt || null });
        return session;
      }
      if (attempt % 10 === 0) record("app-ready-wait", { phase: session.phase || null, message: session.message || null });
      await sleep(1000);
    }
    throw new Error(`CI session never became app-ready for exact device: ${JSON.stringify(session)}`);
  }
  async function openAssistantConversation() {
    await navigateSection("聊天");
    const found = await find({ agentId: ASSISTANT_PEER_ID, limit: 1 });
    const peer = chooseUniqueMatch(found, { agentId: ASSISTANT_PEER_ID });
    record("assistant-semantic-projection-resolved", { agentId: peer.agentId, generation: found.generation });
    await callDevice("fabushi.app.action", { generation: found.generation, agentId: ASSISTANT_PEER_ID, action: "invoke" });
    await waitFor({ agentId: "test:messenger-input", state: "visible" });
  }
  async function openMessageMenu(text) {
    const found = await find({ text, limit: 100 });
    const match = chooseMatch(found, { text }, (item) => item?.role === "article" && String(item?.agentId || "").startsWith(MESSAGE_ROW_PREFIX));
    await callDevice("fabushi.app.action", { generation: found.generation, agentId: match.agentId, action: "invoke" });
    await waitFor({ agentId: "test:message-context-menu", state: "visible" });
  }
  async function sendText(text) {
    await setTest("messenger-input", text);
    await invokeTest("messenger-send");
    await waitFor({ text, state: "present" }, 30_000);
  }
  async function closeGlobalSearchIfOpen() {
    const found = await find({ agentId: "test:global-search-surface", limit: 1 });
    if (!(found.matches || []).length) return;

    const clear = await find({ role: "button", name: "清除搜索", limit: 5 });
    if ((clear.matches || []).length) {
      await act({ role: "button", name: "清除搜索", limit: 5 }, "invoke");
    }

    const close = await find({ role: "button", name: "关闭搜索", limit: 5 });
    if (!(close.matches || []).length) {
      throw new Error("global search surface remained open without the exact close control");
    }
    await act({ role: "button", name: "关闭搜索", limit: 5 }, "invoke");
    await waitFor({ agentId: "test:global-search-surface", state: "absent" });
  }
  async function navigateSection(title) {
    await closeGlobalSearchIfOpen();
    const menu = await find({ agentId: "test:profile-navigation-menu", limit: 1 });
    if (!(menu.matches || []).length) {
      await invokeTest("profile-navigation-trigger");
      await waitFor({ agentId: "test:profile-navigation-menu", state: "visible" });
    }
    const profileAgentId = PROFILE_NAVIGATION_AGENT_IDS.get(title);
    if (!profileAgentId) throw new Error(`unsupported profile navigation section: ${title}`);
    await invokeTest(profileAgentId);
  }
  async function createSelfHostedChannel(name) {
    await navigateSection("聊天");
    await invokeNamed("新建");
    await invokeNamed("新建频道");
    await waitFor({ role: "textbox", name: "名称", state: "visible" }, 30_000);
    await act({ role: "textbox", name: "名称" }, "setValue", name);
    await act({ role: "textbox", name: "描述" }, "setValue", `FCM-010.13.11 external journey ${runId}.${runAttempt}`);
    await invokeNamed("创建频道");
    await waitFor({ agentId: "test:messenger-input", state: "visible" }, 30_000);
    await waitFor({ text: name, state: "present" }, 30_000);
    const found = await find({ text: name, limit: 100 });
    const peer = chooseMatch(found, { text: name }, (item) => String(item?.agentId || "").startsWith("test:peer-selfhosted:channel:"));
    record("selfhosted-channel-created", { name, agentId: peer.agentId });
    return peer.agentId;
  }
  async function openPeer(agentId) {
    await invokeTest(agentId.startsWith("test:") ? agentId.slice(5) : agentId);
    await waitFor({ agentId: "test:messenger-input", state: "visible" });
  }
  async function waitForAssistantUnread() {
    return poll("assistant peer unread badge", async () => {
      const fresh = await snapshot();
      const unread = peerHasUnreadBadgeFromSnapshot(fresh, ASSISTANT_PEER_ID);
      return { ok: unread, value: { unread, generation: fresh.generation } };
    }, 90_000, 800);
  }
  async function waitForIncomingMessage(beforeIds, sentMessageRowId) {
    return messageReceiveTracker.waitForIncoming(beforeIds, sentMessageRowId);
  }
  async function ensureGlobalDharmaInstalled() {
    await closeGlobalSearchIfOpen();
    await invokeTest("global-search-trigger");
    await waitFor({ agentId: "test:global-search-surface", state: "visible" });
    const appsTab = await find({ agentId: "test:global-search-tab-apps", limit: 1 });
    if ((appsTab.matches || []).length) await invokeTest("global-search-tab-apps");
    await setTest("global-search-input", "全球法布施");
    await waitFor({ agentId: "test:global-search-app-global-dharma", state: "visible" }, 30_000);
    const install = await find({ role: "button", name: "安装", limit: 10 });
    if ((install.matches || []).length) await act({ role: "button", name: "安装", limit: 10 }, "invoke");
    await waitFor({ role: "button", name: "打开", state: "visible" }, 30_000);
    await closeGlobalSearchIfOpen();
  }

  await category("startup", async () => {
    await waitForAppReady();
    const status = await callDevice("fabushi.app.status", {});
    if (status.available !== true || status.platform !== "electron") throw new Error(`Fabushi App MCP not available on Electron: ${JSON.stringify(status)}`);
    await snapshot();
  });
  await category("login", async () => {
    await assertUi({ agentId: "test:profile-navigation-trigger", state: "visible" });
    await assertUi({ agentId: "test:login-gate", state: "absent" });
  });
  await category("main", async () => {
    await waitFor({ agentId: "test:messenger-workspace", state: "visible" });
    await assertUi({ agentId: "test:messenger-workspace", state: "visible" });
  });

  const base = `FCM-010.13.11 ${runId}.${runAttempt}`;
  let channelAId = "";
  let channelBId = "";
  await category("conversations", async () => {
    await openAssistantConversation();
    channelAId = await createSelfHostedChannel(`${base} A`);
    channelBId = await createSelfHostedChannel(`${base} B`);
    await openAssistantConversation();
  });
  await category("agent", async () => assertUi({ agentId: "test:messenger-input", state: "enabled" }));
  await category("search", async () => {
    await invokeTest("global-search-trigger");
    await waitFor({ agentId: "test:global-search-surface", state: "visible" });
    await setTest("global-search-input", "全球法布施");
    await assertUi({ agentId: "test:global-search-input", state: "visible" });
    await closeGlobalSearchIfOpen();
  });

  const sendProbe = `${base} receive-unread-probe`;
  let messageIdsBeforeSend = new Set();
  let sentMessageRowId = "";
  await category("send", async () => {
    await openAssistantConversation();
    const tracking = await messageReceiveTracker.captureBeforeSend(async () => {
      await sendText(sendProbe);
      const own = await find({ text: sendProbe, limit: 100 });
      const sent = chooseUniqueMatch(own, { text: sendProbe }, (item) => (
        item?.role === "article" && String(item?.agentId || "").startsWith(MESSAGE_ROW_PREFIX)
      ));
      return String(sent.agentId || "");
    });
    messageIdsBeforeSend = tracking.beforeIds;
    sentMessageRowId = tracking.sentMessageRowId;
    record("sent-message-row-resolved", { agentId: sentMessageRowId });
    await navigateSection("频道");
    await openPeer(channelAId);
    await navigateSection("聊天");
  });
  await category("unread", async () => {
    const unread = await waitForAssistantUnread();
    if (unread.unread !== true) throw new Error(`assistant unread badge was not positive: ${JSON.stringify(unread)}`);
    record("unread-observed", unread);
  });
  await category("receive", async () => {
    await openAssistantConversation();
    const received = await waitForIncomingMessage(messageIdsBeforeSend, sentMessageRowId);
    record("incoming-message-observed", received);
  });

  await navigateSection("频道");
  await openPeer(channelAId);
  await category("reply", async () => {
    const source = `${base} reply-source`;
    await sendText(source);
    await openMessageMenu(source);
    await invokeTest("message-action-reply");
    await waitFor({ agentId: "test:reply-message-banner", state: "visible" });
    await sendText(`${base} reply-child`);
  });

  let editedText = "";
  await category("edit", async () => {
    const original = `${base} edit-source`;
    editedText = `${base} edit-pass`;
    await sendText(original);
    await openMessageMenu(original);
    await invokeTest("message-action-edit");
    await waitFor({ agentId: "test:edit-message-dialog", state: "visible" });
    await setTest("edit-message-input", editedText);
    await invokeTest("edit-message-save");
    await waitFor({ text: editedText, state: "present" }, 30_000);
  });
  await category("draft", async () => {
    const draft = `${base} draft`;
    await setTest("messenger-input", draft);
    const state = (await find({ agentId: "test:messenger-input", limit: 1 })).matches?.[0];
    if (state?.valuePresent !== true || Number(state?.valueLength) !== draft.length) throw new Error(`draft metadata did not round-trip: ${JSON.stringify(state)}`);
    await setTest("messenger-input", "");
    const clearedState = (await find({ agentId: "test:messenger-input", limit: 1 })).matches?.[0];
    if (clearedState?.valuePresent === true || Number(clearedState?.valueLength || 0) !== 0) throw new Error(`draft did not clear semantically: ${JSON.stringify(clearedState)}`);
  });
  await category("pin", async () => {
    await invokeNamed("置顶");
    await waitFor({ role: "button", name: "取消置顶", state: "visible" }, 15_000);
  });
  await category("mute", async () => {
    await invokeNamed("静音");
    await waitFor({ role: "button", name: "开启通知", state: "visible" }, 15_000);
  });
  await category("notifications", async () => {
    await invokeNamed("开启通知");
    await waitFor({ role: "button", name: "静音", state: "visible" }, 15_000);
  });
  await category("forward", async () => {
    const source = `${base} forward-source`;
    await sendText(source);
    await openMessageMenu(source);
    await invokeTest("message-action-forward");
    await waitFor({ agentId: "test:forward-message-dialog", state: "visible" });
    const peers = await find({ role: "button", name: `${base} B`, limit: 100 });
    const target = chooseMatch(peers, { role: "button", name: `${base} B` }, (item) => String(item?.agentId || "").startsWith("forward-message-peer:"));
    await callDevice("fabushi.app.action", { generation: peers.generation, agentId: target.agentId, action: "invoke" });
    await waitFor({ agentId: "test:forward-message-dialog", state: "absent" }, 30_000);
    await navigateSection("频道");
    await openPeer(channelBId);
    await waitFor({ text: source, state: "present" }, 30_000);
    await openPeer(channelAId);
  });
  await category("delete", async () => {
    const text = `${base} delete-source`;
    await sendText(text);
    await openMessageMenu(text);
    await invokeTest("message-action-delete");
    await waitFor({ text, state: "absent" }, 30_000);
  });
  await category("groups", async () => {
    await navigateSection("群组");
    await invokeNamed("新建");
    await invokeNamed("新建群组");
    await waitFor({ text: "现有 AI 群组 Host 会执行 Bot 多轮协作", state: "present" }, 15_000);
    await invokeNamed("取消");
  });
  await category("miniapp", async () => {
    await ensureGlobalDharmaInstalled();
    await invokeTest("global-search-trigger");
    await waitFor({ agentId: "test:global-search-surface", state: "visible" });
    const appsTab = await find({ agentId: "test:global-search-tab-apps", limit: 1 });
    if ((appsTab.matches || []).length) await invokeTest("global-search-tab-apps");
    await setTest("global-search-input", "全球法布施");
    await waitFor({ role: "button", name: "打开", state: "visible" }, 30_000);
    await act({ role: "button", name: "打开", limit: 10 }, "invoke");
    await waitFor({ agentId: "test:miniapp-close", state: "visible" }, 30_000);
    await invokeTest("miniapp-close");
  });
  await category("contacts", async () => {
    await navigateSection("联系人");
    const result = await find({ text: "全球法布施", limit: 100 });
    if (!(result.matches || []).length) throw new Error("contacts projection did not contain Global Dharma");
  });
  await category("bot", async () => {
    await navigateSection("Bots");
    const bots = await find({ text: "全球法布施", limit: 100 });
    const bot = (bots.matches || []).find((item) => item?.role === "button") || bots.matches?.[0];
    if (!bot) throw new Error("Global Dharma Bot was not projected after installation");
    if (!bot.agentId) throw new Error("Global Dharma Bot semantic target did not expose a stable agentId");
    await callDevice("fabushi.app.action", { generation: bots.generation, agentId: bot.agentId, action: "invoke" });
    await waitFor({ agentId: "test:miniapp-bot-open", state: "visible" }, 30_000);
  });
  await category("webmcp", async () => {
    await setTest("messenger-input", "现在运行到哪里？请查看状态");
    await invokeTest("messenger-send");
    await waitFor({ text: "已读取全球法布施状态", state: "present" }, 60_000);
    await assertUi({ agentId: "test:miniapp-bot-open", state: "enabled" });
  });
  await category("media", async () => {
    await closeGlobalSearchIfOpen();
    await invokeTest("global-search-trigger");
    await waitFor({ agentId: "test:global-search-surface", state: "visible" });
    await invokeTest("global-search-tab-images");
    await assertUi({ agentId: "test:global-search-tab-images", state: "visible" });
  });
  await category("file", async () => {
    await invokeTest("global-search-tab-files");
    await assertUi({ agentId: "test:global-search-tab-files", state: "visible" });
    await closeGlobalSearchIfOpen();
  });
  await category("sync", async () => {
    await navigateSection("频道");
    await openPeer(channelAId);
    await waitFor({ text: editedText, state: "present" }, 30_000);
    const second = await find({ agentId: channelBId, limit: 1 });
    if (!(second.matches || []).length) throw new Error("second self-hosted channel disappeared from synchronized projection");
  });
  await category("settings", async () => {
    await navigateSection("设置");
    await waitFor({ agentId: "test:settings-modal-backdrop", state: "visible" });
    await assertUi({ agentId: "test:telegram-settings-workspace", state: "visible" });
  });
  await category("update", async () => {
    await invokeTest("settings-category-updates");
    await waitFor({ agentId: "test:updates-settings", state: "visible" });
    await assertUi({ agentId: "test:settings-update-track", state: "visible" });
  });

  const missing = REQUIRED_CATEGORIES.filter((name) => !completedCategories.includes(name));
  if (missing.length) throw new Error(`full journey did not complete required categories: ${missing.join(",")}`);
  await invokeTest("settings-category-account");
  await waitFor({ agentId: "settings-logout", state: "visible" });
  await callDevice("ci_session_note", { note: `TFI_MACOS_FULL_JOURNEY READY_FOR_LOGOUT PASS categories=${REQUIRED_CATEGORIES.join(",")}` });
  await callDevice("ci_session_finish", { reason: `FCM-010.13.11 external full journey passed on ${expectedDeviceId}` });
  const fresh = await snapshot();
  const logout = (fresh.elements || []).find((item) => item?.agentId === "settings-logout");
  if (!logout) throw new Error("fresh pre-logout snapshot did not contain exact settings-logout");
  await callDevice("fabushi.app.action", { generation: fresh.generation, agentId: "settings-logout", action: "invoke" });
  return { categories: completedCategories, finalAction: { toolName: "fabushi.app.action", agentId: "settings-logout", action: "invoke" } };
}
