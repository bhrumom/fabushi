import { callGenerationSensitiveAction } from "./fcm-010-13-generation-sensitive-action.mjs";

const REQUIRED_CATEGORIES = [
  "startup", "login", "main", "conversations", "search", "send", "receive", "reply", "edit", "delete",
  "forward", "draft", "pin", "mute", "unread", "contacts", "groups", "bot", "agent", "miniapp", "webmcp",
  "media", "file", "notifications", "sync", "settings", "update",
];
const ASSISTANT_PEER_ID = "test:peer-legacy:conversation:mahayana-ai:agent:assistant";
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

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
  async function snapshot() { return callDevice("fabushi.app.snapshot", { maxElements: 500, includeText: true }); }
  async function find(query) { return callDevice("fabushi.app.find", { ...query, limit: query.limit || 100 }); }
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
  function matchingTargets(found, query, predicate) {
    const matches = Array.isArray(found?.matches) ? found.matches : [];
    return matches.filter((item) => {
      if (query.agentId && item?.agentId !== query.agentId) return false;
      if (query.role && item?.role !== query.role) return false;
      if (query.name && item?.name !== query.name) return false;
      if (query.text) {
        const haystack = String(item?.text || item?.name || "");
        if (!haystack.includes(query.text)) return false;
      }
      return predicate ? Boolean(predicate(item)) : true;
    });
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
        const refreshed = await invokeDeviceCall("fabushi.app.find", { ...query, limit: query.limit || 100 });
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
    await invokeTest(ASSISTANT_PEER_ID.slice(5));
    await waitFor({ agentId: "test:messenger-input", state: "visible" });
  }
  async function openMessageMenu(text) {
    const found = await find({ text, limit: 100 });
    const match = chooseMatch(found, { text }, (item) => String(item?.agentId || "").startsWith("message-actions:") && String(item?.text || item?.name || "").includes(text));
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
    if ((found.matches || []).length) {
      const close = await find({ role: "button", name: "关闭搜索", limit: 5 });
      if ((close.matches || []).length) await act({ role: "button", name: "关闭搜索", limit: 5 }, "invoke");
    }
  }
  async function navigateSection(title) {
    await closeGlobalSearchIfOpen();
    const menu = await find({ agentId: "test:profile-navigation-menu", limit: 1 });
    if (!(menu.matches || []).length) {
      await invokeTest("profile-navigation-trigger");
      await waitFor({ agentId: "test:profile-navigation-menu", state: "visible" });
    }
    await invokeNamed(title);
  }
  async function createSelfHostedChannel(name) {
    await navigateSection("聊天");
    await invokeNamed("新建");
    await invokeNamed("新建频道");
    await act({ role: "textbox", name: "频道名称" }, "setValue", name);
    await act({ role: "textbox", name: "频道简介" }, "setValue", `FCM-010.13.11 external journey ${runId}.${runAttempt}`);
    await invokeNamed("创建频道");
    await waitFor({ agentId: "test:messenger-input", state: "visible" }, 30_000);
    const found = await find({ text: name, limit: 100 });
    const peer = chooseMatch(found, { text: name }, (item) => String(item?.agentId || "").startsWith("test:peer-selfhosted:channel:") && String(item?.text || item?.name || "").includes(name));
    record("selfhosted-channel-created", { name, agentId: peer.agentId });
    return peer.agentId;
  }
  async function openPeer(agentId) {
    await invokeTest(agentId.startsWith("test:") ? agentId.slice(5) : agentId);
    await waitFor({ agentId: "test:messenger-input", state: "visible" });
  }
  async function messageRowIds() {
    const found = await find({ role: "article", limit: 200 });
    return new Set((found.matches || []).map((item) => String(item?.agentId || "")).filter((id) => id.startsWith("message-actions:")));
  }
  async function waitForAssistantUnread(previousPeerText) {
    return poll("assistant peer unread badge", async () => {
      const found = await find({ agentId: ASSISTANT_PEER_ID, limit: 1 });
      const peer = found.matches?.[0];
      const text = String(peer?.text || peer?.name || "").trim();
      const unreadMatch = text.match(/([1-9][0-9]*)\s*$/u);
      return { ok: Boolean(peer && text !== previousPeerText && unreadMatch), value: { text, unread: unreadMatch ? Number(unreadMatch[1]) : 0 } };
    }, 90_000, 800);
  }
  async function waitForIncomingMessage(beforeIds, ownText) {
    return poll("new incoming assistant message", async () => {
      const found = await find({ role: "article", limit: 200 });
      const candidate = (found.matches || []).find((item) => {
        const id = String(item?.agentId || "");
        const text = String(item?.text || item?.name || "");
        return id.startsWith("message-actions:") && !beforeIds.has(id) && text && !text.includes(ownText);
      });
      return { ok: Boolean(candidate), value: candidate ? { agentId: candidate.agentId, text: String(candidate.text || candidate.name || "").slice(0, 240) } : null };
    }, 90_000, 800);
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
  const assistantBefore = await find({ agentId: ASSISTANT_PEER_ID, limit: 1 });
  const assistantPeerTextBefore = String(assistantBefore.matches?.[0]?.text || assistantBefore.matches?.[0]?.name || "");
  let messageIdsAfterSend = new Set();
  await category("send", async () => {
    await openAssistantConversation();
    await sendText(sendProbe);
    messageIdsAfterSend = await messageRowIds();
    const own = await find({ text: sendProbe, limit: 100 });
    if (!(own.matches || []).some((item) => String(item?.agentId || "").startsWith("message-actions:"))) throw new Error("sent probe did not resolve to a real semantic message row");
    await navigateSection("频道");
    await openPeer(channelAId);
    await navigateSection("聊天");
  });
  await category("unread", async () => {
    const unread = await waitForAssistantUnread(assistantPeerTextBefore);
    if (!(unread.unread > 0)) throw new Error(`assistant unread badge was not positive: ${JSON.stringify(unread)}`);
    record("unread-observed", unread);
  });
  await category("receive", async () => {
    await openAssistantConversation();
    const received = await waitForIncomingMessage(messageIdsAfterSend, sendProbe);
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
    const peers = await find({ role: "button", limit: 200 });
    const target = chooseMatch(peers, { role: "button", name: `${base} B` }, (item) => String(item?.agentId || "").startsWith("forward-message-peer:") && String(item?.text || item?.name || "").includes(`${base} B`));
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
