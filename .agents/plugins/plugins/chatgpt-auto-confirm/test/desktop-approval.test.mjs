import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import worker from '../worker/src/index.ts';

const nativeSource = readFileSync(new URL(
  '../native/chatgpt_auto_confirm.swift', import.meta.url), 'utf8');

const call = async (name, args = {}) => {
  const response = await worker.fetch(new Request('https://example.test/mcp', {
    method: 'POST', body: JSON.stringify({ jsonrpc: '2.0', id: 9, method: 'tools/call',
      params: { name, arguments: args } }),
  }));
  return response.json();
};

test('start emits a scoped desktop host request', async () => {
  const result = await call('start', { rules: [{
    application: 'GitHub', action: 'Enable auto-merge', resource: 'bhrumom/fabushi',
  }] });
  assert.equal(result.result.structuredContent.hostRequest.capability,
    'desktop.chatgpt-approvals.start');
  assert.equal(result.result.structuredContent.hostRequest.approval, 'required');
});

test('start rejects broad wildcard rules', async () => {
  const result = await call('start', { rules: [{ application: 'GitHub', action: '*', resource: 'all' }] });
  assert.equal(result.error.code, -32602);
});

test('start supports every recognized approval card without chat titles', async () => {
  const chatUrl = 'https://chatgpt.com/c/hidden-task-101';
  const result = await call('start', { approveAll: true, intervalMs: 750, chatUrls: [chatUrl] });
  const request = result.result.structuredContent.hostRequest;
  assert.equal(request.capability, 'desktop.chatgpt-approvals.start');
  assert.equal(request.params.approveAll, true);
  assert.deepEqual(request.params.chatTitles, []);
  assert.deepEqual(request.params.chatUrls, [chatUrl]);
});

test('status is a read-only host request', async () => {
  const result = await call('status');
  assert.equal(result.result.structuredContent.hostRequest.approval, 'none');
});

test('outbound sends discard old chat URLs while read-only reply requests keep them', async () => {
  const chatUrl = 'https://chatgpt.com/c/hidden-task-202';
  const sent = await call('send_and_watch', {
    message: '检查隐藏任务', connector: 'devspace1', chatUrl,
  });
  assert.equal(sent.result.structuredContent.hostRequest.params.chatUrl, null);
  assert.equal(sent.result.structuredContent.hostRequest.params.newChat, true);
  const reply = await call('get_reply', { chatUrl });
  assert.equal(reply.result.structuredContent.hostRequest.params.chatUrl, chatUrl);
});

test('every outbound message creates a new Chat and old conversations are read-only resume targets', async () => {
  const conversationId = '6a5f93ae-5118-83e8-a96a-2a7f321dd0e8';
  const sent = await call('send_and_watch', {
    message: '继续同一会话', connector: 'devspace1', conversationId, newChat: true,
  });
  const params = sent.result.structuredContent.hostRequest.params;
  assert.equal(params.conversationId, null);
  assert.equal(params.newChat, true);
  const resumed = await call('send_and_watch', {
    message: '只读监视', conversationId, resumeExisting: true,
  });
  const resumeParams = resumed.result.structuredContent.hostRequest.params;
  assert.equal(resumeParams.conversationId, conversationId);
  assert.equal(resumeParams.newChat, false);
  assert.match(nativeSource, /selectBackgroundConversationJS/);
  assert.match(nativeSource, /conversation_sidebar_row_not_found/);
  assert.match(nativeSource, /conversationFingerprint/);
  assert.match(nativeSource, /conversation_body_not_ready/);
  assert.match(nativeSource, /messagesReady: true/);
  assert.match(nativeSource, /新建任务/);
  assert.match(nativeSource, /New task/);
  assert.match(nativeSource, /activityCharCount >= 80/);
  assert.match(nativeSource, /do not treat that regression as/);
  assert.match(nativeSource, /__reactFiber\$/);
  assert.match(nativeSource, /new_chat_conversation_not_created/);
  assert.match(nativeSource, /new_chat_creation_not_confirmed/);
});

test('send_and_watch streams visible thinking and uses bounded 20-minute new-Chat recovery', async () => {
  const sent = await call('send_and_watch', {
    message: '继续完成任务', connector: 'devspace1',
  });
  const params = sent.result.structuredContent.hostRequest.params;
  assert.equal(params.newChat, true);
  assert.equal(params.timeout, 3600);
  assert.equal(params.stagnationTimeout, 1200);
  assert.equal(params.maxRecoveryAttempts, 5);
  assert.equal(params.autoContinueIncomplete, true);
  assert.equal(params.maxTaskContinuations, 0);
  assert.match(nativeSource, /"thinking_progress"/);
  assert.match(nativeSource, /stopCurrentResponseJS/);
  assert.match(nativeSource, /stopConfirmed/);
  assert.match(nativeSource, /old_chat_stop_not_confirmed/);
  assert.match(nativeSource, /stop_confirmation_timeout/);
  assert.match(nativeSource, /sendMessageJS\(message: continuationMessage, connector: connector, newChat: true\)/);
  assert.doesNotMatch(nativeSource, /private func stopAndContinueJS/);
  assert.match(nativeSource, /"createdNewChat": stopConfirmed/);
  assert.match(nativeSource, /DEVSPACE_TOOL_TIMEOUT|devspace_timeout/);
  assert.match(nativeSource, /继续在此聊天/);
  assert.match(nativeSource, /autoConfirmChatContinuationJS/);
  assert.match(nativeSource, /surface: 'chat'/);
  assert.doesNotMatch(nativeSource, /expression: autoConfirmWorkHandoffJS\(\)/);
  assert.match(nativeSource, /REDACTED_API_KEY/);
  assert.match(nativeSource, /connector_selection_not_confirmed/);
  assert.match(nativeSource, /isInComposerBand/);
  assert.match(nativeSource, /message_input_not_confirmed/);
  assert.match(nativeSource, /message_send_not_confirmed/);
  assert.match(nativeSource, /containsFullSubmittedMessage/);
  assert.match(nativeSource, /sendJS, timeout: 35\.0/);
  assert.match(nativeSource, /verifySentMessageJS/);
  assert.match(nativeSource, /recoveredAfterExecutionContextLoss/);
  assert.match(nativeSource, /never send the message a second time here/);
  assert.match(nativeSource, /baselineUserIdentities/);
  assert.match(nativeSource, /isNewBubble/);
  assert.match(nativeSource, /virtualizationAware/);
  assert.match(nativeSource, /sendVerification/);
  assert.match(nativeSource, /approval_watcher_start_failed/);
  assert.match(nativeSource, /completionCandidate/);
  assert.match(nativeSource, /completedThinkingToggles/);
  assert.match(nativeSource, /completedSectionText/);
  assert.match(nativeSource, /completedActivity\.length > 0/);
  assert.match(nativeSource, /toolOnlyCompletedActivity/);
  assert.match(nativeSource, /explicitlyIncomplete/);
  assert.match(nativeSource, /terminalIncomplete/);
  assert.match(nativeSource, /chat_finished_incomplete/);
  assert.match(nativeSource, /MAHAYANA_TASK_REPORT_V1_BEGIN/);
  assert.match(nativeSource, /hasClosedTaskReport/);
  assert.match(nativeSource, /structuredIncomplete/);
  assert.match(nativeSource, /mahayana\.task-report\.v1/);
  assert.match(nativeSource, /relayFreshChatContinuation/);
  assert.match(nativeSource, /task_continuation_limit_reached/);
  assert.match(nativeSource, /task_continuation_started/);
  assert.match(nativeSource, /chat_surface_drift/);
  assert.match(nativeSource, /liveSurface\["chatMode"\]/);
  assert.match(nativeSource, /never approve or type on Work/);
  assert.match(nativeSource, /explicitFinalResult/);
  assert.match(nativeSource, /&& !explicitlyIncomplete\s*&& explicitFinalResult/);
  assert.match(nativeSource, /尚未\.\{0,12\}完成/);
  assert.match(nativeSource, /Date\(\)\.timeIntervalSince\(candidateSince\) >= 4\.0/);
  assert.doesNotMatch(nativeSource,
    /devspaceWaiting[^\n]*\n\s*\|\|[^\n]*devspaceActivity/);
});

test('task queue tools preserve dependencies, resource locks, review gate and concurrency', async () => {
  const queued = await call('enqueue_tasks', {
    tasks: [{
      id: 'release', title: '发布', prompt: '完成发布', connector: 'devspace1',
      dependsOn: [], resourceLocks: ['repo:fabushi'],
    }],
    maxConcurrent: 2,
    reviewGate: true,
  });
  const request = queued.result.structuredContent.hostRequest;
  assert.equal(request.capability, 'desktop.chatgpt-approvals.queue-enqueue');
  assert.equal(request.params.maxConcurrent, 2);
  assert.deepEqual(request.params.tasks[0].resourceLocks, ['repo:fabushi']);
  const wait = await call('wait_for_review', { timeout: 60 });
  assert.equal(wait.result.structuredContent.hostRequest.capability,
    'desktop.chatgpt-approvals.queue-wait-review');
  assert.equal(wait.result.structuredContent.hostRequest.approval, 'none');
  const reviewed = await call('review_task', {
    taskId: 'release', accepted: false, feedback: '补充安装包验证',
  });
  assert.equal(reviewed.result.structuredContent.hostRequest.capability,
    'desktop.chatgpt-approvals.queue-review');
  const retried = await call('retry_task', {
    taskId: 'release', feedback: '从最新落盘进度继续', connector: 'GitHub',
  });
  assert.equal(retried.result.structuredContent.hostRequest.capability,
    'desktop.chatgpt-approvals.queue-retry');
  assert.equal(retried.result.structuredContent.hostRequest.params.connector, 'GitHub');
  assert.match(nativeSource, /case "queue_retry"/);
  assert.match(nativeSource, /operator_recovery/);
  assert.match(nativeSource, /case "queue_watch"/);
  assert.match(nativeSource, /resourceLocks/);
  assert.match(nativeSource, /dependsOn/);
  assert.match(nativeSource, /awaiting_review/);
  assert.match(nativeSource, /reviewFeedback/);
  assert.match(nativeSource, /worker_exited_without_result/);
  assert.match(nativeSource, /monitorAutomationTask/);
  assert.match(nativeSource, /virtual-list parent/);
  assert.match(nativeSource, /maxTaskContinuations > 0/);
  assert.match(nativeSource, /activeConversationId is shared by every visible row/);
  assert.match(nativeSource, /getAttribute\('aria-current'\) === 'page'/);
  assert.match(nativeSource, /activeRowConversationIds/);
  assert.match(nativeSource, /userContent: userContent\.substring/);
  assert.match(nativeSource, /identitySource == "portal"/);
  assert.match(nativeSource, /conversationSource/);
  assert.match(nativeSource, /portalConversationId\s*\n\s*\|\| activeConversationId/);
  assert.match(nativeSource, /freshly prepared blank Chat owns a stable local id/);
  assert.match(nativeSource, /never replace a local id with/);
  assert.match(nativeSource, /appendTextPreservingConnector/);
  assert.match(nativeSource, /createQueueWorkerTarget/);
  assert.match(nativeSource, /queueWorkerProfilePath/);
  assert.match(nativeSource, /single-authenticated-process-hidden-prewarm-serialized/);
  assert.match(nativeSource, /single-process-hidden-prewarm/);
  assert.match(nativeSource, /isolated-dedicated-process/);
  assert.match(nativeSource, /stopQueueWorker/);
  assert.match(nativeSource, /startAutomationReview/);
  assert.match(nativeSource, /reviewConversationId/);
  assert.match(nativeSource, /chat_review_\\\(report\.status\)/);
  assert.match(nativeSource, /app:\/\/-\/index\.html/);
  assert.doesNotMatch(nativeSource, /existing-process-hidden-target/);
  assert.match(nativeSource, /quickChatPrewarmServiceJS/);
  assert.match(nativeSource, /reset-prewarm/);
  assert.match(nativeSource, /renderer-ready/);
  assert.match(nativeSource, /quick-chat-prewarm/);
  assert.match(nativeSource, /Page\.setWebLifecycleState/);
  assert.match(nativeSource, /Emulation\.setFocusEmulationEnabled/);
  assert.match(nativeSource, /Emulation\.setIdleOverride/);
  assert.match(nativeSource, /eventLoopDelayMs/);
  assert.match(nativeSource, /setTimeout\(resolve, 50\)/);
  assert.match(nativeSource, /eventLoopDelayMs < 2_500/);
  assert.match(nativeSource, /wakeHiddenRenderer/);
  assert.match(nativeSource, /document\.dispatchEvent\(new Event\('visibilitychange'\)\)/);
  assert.match(nativeSource, /window\.dispatchEvent\(new Event\('focus'\)\)/);
  assert.match(nativeSource, /document\.visibilityState remains hidden/);
  assert.match(nativeSource, /for _ in 0\.\.<3/);
  assert.match(nativeSource, /Discard that page and retry the official/);
  assert.match(nativeSource, /ChatGPT's show:false prewarm path/);
  assert.match(nativeSource, /visibility == "hidden"/);
  assert.match(nativeSource, /queueTargetIsHidden/);
  assert.match(nativeSource, /queue_worker_visibility_not_hidden/);
  assert.match(nativeSource, /Missing, suspended, and hidden-but-not-Chat renderers are disposable/);
  assert.match(nativeSource, /queue_monitor_hidden_target_rebuild_failed/);
  assert.match(nativeSource, /queue_monitor_hidden_target_recovery_failed/);
  assert.match(nativeSource, /queue_monitor_hidden_target_recreated_without_durable_conversation/);
  assert.match(nativeSource, /runtimeState == \.hiddenNonChat/);
  assert.match(nativeSource, /expression: clickChatJS\(\)/);
  assert.match(nativeSource, /if runtimeState == \.visible/);
  assert.match(nativeSource, /stopQueueWorker\(&state\)[\s\S]*createQueueWorkerTarget\(&state\)/);
  assert.match(nativeSource, /hiddenWorkerLastHeartbeatAt/);
  assert.match(nativeSource, /hiddenWorkerRecoveryCount/);
  assert.match(nativeSource, /"runtimeState": workerRuntimeState\.map\(queueTargetRuntimeStateName\)/);
  assert.match(nativeSource, /"visibilityVerified": workerIsHidden/);
  assert.doesNotMatch(nativeSource, /openNewWindowUsingApplicationMenu/);
  assert.doesNotMatch(nativeSource, /kAXMinimizedAttribute/);
  assert.match(nativeSource, /state\.queueWorkerTargetId/);
  assert.match(nativeSource, /queue_worker_background_window_migration/);
  assert.match(nativeSource, /queue_monitor_requires_background_window/);
  assert.match(nativeSource, /stopLegacyQueueResponseIfStillOwned/);
  assert.match(nativeSource, /pageContent\.contains\(dispatchMarker\)/);
  assert.match(nativeSource, /not stop, select, focus/);
  assert.match(nativeSource, /closeDedicatedAutomationTarget/);
  assert.match(nativeSource, /page where the user is composing a new task/);
  assert.match(nativeSource, /实际工作只允许在 Chat 页面完成/);
  assert.match(nativeSource, /chatOnlyInstruction/);
  assert.match(nativeSource, /app:\/\/\-\/index\.html/);
  assert.match(nativeSource, /queue_monitor_conversation_drift/);
  assert.match(nativeSource, /fresh_chat_body_pending_timeout/);
  assert.match(nativeSource, /Wait for the dispatch marker instead of pausing every queued/);
  assert.match(nativeSource, /selectBackgroundConversationJS\(conversationId\)/);
  assert.match(nativeSource, /parse a stale page as the active task/);
  assert.match(nativeSource, /任务发送轮次/);
  assert.match(nativeSource, /验收 Chat 标识/);
  assert.match(nativeSource, /dispatchMarker/);
  assert.match(nativeSource, /resolveDispatchedConversationJS/);
  assert.match(nativeSource, /expectedLocalId/);
  assert.match(nativeSource, /local-row-mapping/);
  assert.match(nativeSource, /exact local->durable mapping/);
  assert.match(nativeSource, /first id absent from the baseline.*is unsafe/);
  assert.doesNotMatch(nativeSource, /source: 'new-sidebar-row'/);
  assert.match(nativeSource, /durable_conversation_id_pending/);
  assert.doesNotMatch(nativeSource, /selectBackgroundConversationJS\(resolvedConversationId\)/);
  assert.match(nativeSource, /navigateHiddenConversation/);
  assert.match(nativeSource, /backgroundConversationURL/);
  assert.match(nativeSource, /initialRoute/);
  assert.match(nativeSource, /云端 GitHub 的代码、仓库、PR、Actions、构件、发布和合并状态必须使用 GitHub 连接器/);
  assert.match(nativeSource, /本地 checkout、Git\/gh 元数据与安全同步必须使用 bhrum2/);
  assert.match(nativeSource, /重复卡点时不要只重复同一条失败命令/);
  assert.match(nativeSource, /具体所需权限、账号、工具/);
  assert.match(nativeSource, /项目的测试、构建、打包、安装、发布验证和安装包生成一律在 GitHub Actions/);
  assert.match(nativeSource, /禁止 git add -A/);
  assert.match(nativeSource, /wait_seconds/);
  assert.match(nativeSource, /waiting_for_external_result/);
  assert.match(nativeSource, /waiting_for_network_recovery/);
  assert.match(nativeSource, /queueNetworkRecovery/);
  assert.match(nativeSource, /SCNetworkReachabilityCreateWithName/);
  assert.match(nativeSource, /next_connector/);
  assert.match(nativeSource, /云端 GitHub 状态必须通过 GitHub 连接器核验/);
  assert.match(nativeSource, /本地 checkout、Git\/gh 元数据与安全同步必须使用 bhrum2/);
  assert.match(nativeSource, /the prompt can never trigger a false network outage/);
  assert.match(nativeSource, /chat_start_no_reply/);
  assert.match(nativeSource, /currentDate >= waitingUntil/);
  assert.match(nativeSource, /Confirm it before restoring a task through its exact hidden-page route/);
  assert.match(nativeSource, /Do not restore the background queue renderer before its current page is read/);
});

test('native runtime stays in the background and never takes over the UI', () => {
  assert.match(nativeSource, /AXUIElementPerformAction\(candidate\.element, kAXPressAction/);
  assert.match(nativeSource, /AXPress 已发送，等待授权卡消失/);
  assert.match(nativeSource, /reconcilePendingApprovals/);
  assert.match(nativeSource, /"AXVisibleOnly": true/);
  assert.doesNotMatch(nativeSource, /"AXVisibleOnly": false/);
  assert.match(nativeSource, /where application\.isActive/);
  assert.match(nativeSource, /isActuallyVisible\(button, inside: activeWindow\)/);
  assert.match(nativeSource, /axPressVisibleForegroundOnly/);
  assert.match(nativeSource, /axPressNeverTargetsHiddenElements/);
  assert.match(nativeSource, /dismissHistoryOverlay\(covering: candidate\)/);
  assert.doesNotMatch(nativeSource, /CGWarpMouseCursorPosition|CGEvent\s*\(|postToPid/);
  assert.doesNotMatch(nativeSource, /\.activate\s*\(|postToPid|kAXFocusedAttribute/);
  assert.doesNotMatch(nativeSource,
    /navigateChat|scanTargetChats|sweepHiddenChats|sidebarTaskButton|switchApplicationMode/);
  assert.doesNotMatch(nativeSource, /sensitiveTerms|blockedSensitive/);
  assert.match(nativeSource, /Target\.createTarget/);
  assert.match(nativeSource, /Target\.getTargetInfo/);
  assert.match(nativeSource, /browserContextId/);
  assert.match(nativeSource, /\\"background\\":true/);
  assert.match(nativeSource, /invokeInternalApproval/);
  assert.match(nativeSource, /__reactProps\$/);
  assert.match(nativeSource, /"internalActionIsPrimary": true/);
  assert.match(nativeSource, /"operatesHiddenPages": true/);
  assert.match(nativeSource, /loadedApprovalTargets/);
  assert.match(nativeSource, /"scansEveryLoadedRenderer": true/);
  assert.match(nativeSource, /Runtime\.evaluate does not activate the app/);
  assert.match(nativeSource, /withWatcherLifecycleLock/);
  assert.match(nativeSource, /idleSystemSleepDisabled/);
  assert.match(nativeSource, /userInitiatedAllowingIdleSystemSleep/);
  assert.match(nativeSource, /flock\(descriptor, LOCK_EX\)/);
});

test('approval decisions do not inspect or block card contents', () => {
  assert.match(nativeSource, /allRecognizedApprovalsEnabled/);
  assert.match(nativeSource, /自动确认所有 ChatGPT 授权卡/);
  assert.doesNotMatch(nativeSource, /sensitiveTerms|blockedSensitive/);
});

test('legacy sweep command remains compatible without navigating tasks', () => {
  assert.match(nativeSource,
    /case "sweep":[\s\S]*?var result = scan\(&state\)[\s\S]*?"navigationSkipped"/);
});

test('allow-once cards are recognized by their allow and reject button pair', () => {
  assert.match(nativeSource,
    /for anchor in approvalAnchors[\s\S]*?if !verifiedButtons\.isEmpty \{ break \}[\s\S]*?container = parent\(of: node\)/);
  assert.match(nativeSource, /"Reject", "Deny", "拒绝", "不允许"/);
  assert.match(nativeSource,
    /guard buttons\.count == 2,[\s\S]*?return buttons\.filter \{ normalizedAXText\(accessibleString\(\$0\)\)\.isEmpty \}/);
  assert.match(nativeSource,
    /isAllowButton\(title: title, context: context\) \|\|\s*normalizedAXText\(title\)\.isEmpty/);
});

test('relaunch_and_confirm emits a host request and supports self-restarting ChatGPT with CDP port', async () => {
  const result = await call('relaunch_and_confirm', { approveAll: true });
  const request = result.result.structuredContent.hostRequest;
  assert.equal(request.capability, 'desktop.chatgpt-approvals.relaunch-and-confirm');
  assert.equal(request.params.approveAll, true);
  assert.match(nativeSource, /case "relaunch_and_confirm":[\s\S]*?NSWorkspace\.shared\.runningApplications\.filter[\s\S]*?--remote-debugging-port/);
});
