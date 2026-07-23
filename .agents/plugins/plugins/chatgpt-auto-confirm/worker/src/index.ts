import { HOME, RESOURCES } from './content.generated.ts';

const taskPromptTemplates = [
  { id: 'implement-and-verify', title: '实现并验证', description: '完成实现并运行相应验证。', promptPrefix: '请在当前 checkout 中完成下面的实现任务，检查现有改动后继续，运行与风险相称的验证，不要覆盖无关改动：' },
  { id: 'diagnose-fix-verify', title: '诊断、修复、验证', description: '定位根因后修复并回归验证。', promptPrefix: '请先用现有代码、日志和测试定位根因，然后修复并完成回归验证；不要只给建议：' },
  { id: 'review-and-fix', title: '审查并修正', description: '审查现有实现，修正真实问题并验证。', promptPrefix: '请审查当前 checkout 中与目标相关的实现，修正发现的真实问题并完成验证：' },
  { id: 'continue-to-complete', title: '持续完成目标', description: '从已有进度继续到全部验收通过。', promptPrefix: '请从当前 checkout 的已有进度继续，不要从头开始；持续工作直到以下目标和验收条件全部满足：' },
];

const reply = (id: unknown, result: unknown) => Response.json({ jsonrpc: '2.0', id, result });
const error = (id: unknown, code: number, message: string) => Response.json({
  jsonrpc: '2.0', id, error: { code, message },
});
const annotations = (readOnlyHint = false) => ({
  readOnlyHint, destructiveHint: false, openWorldHint: false,
});
const hostResult = (id: unknown, capability: string, params: unknown, approval: 'required' | 'none') =>
  reply(id, {
    content: [{ type: 'text', text: `已向大乘桌面宿主提交 ${capability}。` }],
    structuredContent: {
      handled: true,
      hostRequest: { transport: 'mcp-host-bridge', capability, params, approval },
    },
  });
const ruleSchema = {
  type: 'object', additionalProperties: false,
  required: ['application', 'action', 'resource'],
  properties: {
    application: { type: 'string', minLength: 1, description: '例如 GitHub' },
    action: { type: 'string', minLength: 1, description: '例如 Enable auto-merge' },
    resource: { type: 'string', minLength: 1, description: '例如 bhrumom/fabushi' },
  },
};
const queuedTaskSchema = {
  type: 'object', additionalProperties: false, required: ['title', 'prompt'],
  properties: {
    id: { type: 'string', pattern: '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$' },
    title: { type: 'string', minLength: 1, maxLength: 160 },
    prompt: { type: 'string', minLength: 1, maxLength: 10000 },
    promptTemplate: { type: 'string', enum: taskPromptTemplates.map(item => item.id), default: 'continue-to-complete' },
    connector: { type: 'string', minLength: 1, maxLength: 256, default: 'devspace1' },
    dependsOn: { type: 'array', maxItems: 50, items: { type: 'string', pattern: '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$' }, default: [] },
    resourceLocks: { type: 'array', maxItems: 20, items: { type: 'string', minLength: 1, maxLength: 256 }, default: [] },
    priority: { type: 'integer', minimum: -100, maximum: 100, default: 0 },
    timeout: { type: 'integer', minimum: 60, maximum: 7200, default: 3600 },
    maxTaskContinuations: { type: 'integer', minimum: 0, default: 0, description: '未完成时自动创建新 Chat 的轮数；0 表示持续执行，不设固定次数上限' },
    maxRuntimeRetries: { type: 'integer', minimum: 0, maximum: 5, default: 2 },
  },
};
const tools = [
  { name: 'home', description: '加载插件首页', annotations: annotations(true), inputSchema: {
    type: 'object', additionalProperties: false, properties: {
      surface: { type: 'string' }, locale: { type: 'string' }, cursor: { type: 'string' },
      limit: { type: 'integer', minimum: 1, maximum: 10 },
    },
  } },
  { name: 'start', description: '启动 ChatGPT 后台已加载授权卡的全部自动确认', annotations: annotations(), inputSchema: {
    type: 'object', additionalProperties: false, properties: {
      rules: { type: 'array', minItems: 1, maxItems: 20, items: ruleSchema },
      approveAll: { type: 'boolean', description: '自动确认 ChatGPT 已加载的所有已识别授权卡' },
      chatTitles: { type: 'array', maxItems: 20, description: '兼容字段；严格后台模式不会切换任务', items: { type: 'string', minLength: 1, maxLength: 256 } },
      chatUrls: { type: 'array', maxItems: 20, description: '后台跟踪的 ChatGPT 对话地址；页面卸载后会用同一登录会话在隐藏目标中继续操作', items: { type: 'string', pattern: '^https://chatgpt\\.com/(?:$|c/)' } },
      intervalMs: { type: 'integer', minimum: 400, maximum: 5000, default: 750 },
    },
  } },
  { name: 'stop', description: '停止自动确认监听', annotations: annotations(), inputSchema: {
    type: 'object', additionalProperties: false, properties: {},
  } },
  { name: 'status', description: '读取监听、权限和规则状态', annotations: annotations(true), inputSchema: {
    type: 'object', additionalProperties: false, properties: {},
  } },
  { name: 'scan_once', description: '立即后台扫描并确认已加载的所有已识别授权卡', annotations: annotations(), inputSchema: {
    type: 'object', additionalProperties: false, properties: {},
  } },
  { name: 'relaunch_and_confirm', description: '让小程序自行重启 ChatGPT.app 开启调试通道并立刻确认授权卡', annotations: annotations(), inputSchema: {
    type: 'object', additionalProperties: false, properties: {
      approveAll: { type: 'boolean', description: '自动确认 ChatGPT 已加载的所有已识别授权卡' },
    },
  } },
  { name: 'audit_log', description: '读取仅保存在本机的最近审计记录', annotations: annotations(true), inputSchema: {
    type: 'object', additionalProperties: false, properties: {
      limit: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
    },
  } },
  { name: 'diagnose', description: '只读检查 ChatGPT 已加载的辅助功能结构', annotations: annotations(true), inputSchema: {
    type: 'object', additionalProperties: false, properties: {},
  } },
  { name: 'send_and_watch', description: '在隐藏的第二个 ChatGPT.app 实例的 Chat 页面中发送指令，自动确认授权卡并实时等待最终回复；绝不使用当前 Work/worker 页面回退', annotations: annotations(), inputSchema: {
    type: 'object', additionalProperties: false, properties: {
      message: { type: 'string', minLength: 1, maxLength: 10000, description: '要发送给 ChatGPT 的指令文本' },
      connector: { type: 'string', description: '要从 ChatGPT Apps 菜单选择的 MCP connector 名称（如 devspace1）' },
      conversationId: { type: 'string', pattern: '^[A-Za-z0-9-]{8,128}$', description: '只读恢复监视时要绑定的 Chat 会话 ID；任何实际发送都会忽略旧会话并新建 Chat' },
      chatUrl: { type: 'string', pattern: '^https://chatgpt\\.com/(?:$|c/)', description: '精确操作的 ChatGPT 对话地址；界面隐藏后仍会在后台挂载' },
      newChat: { type: 'boolean', default: true, description: '在隐藏 ChatGPT.app 实例中点击「新聊天」并选中 Chat，再选择 connector 并发送' },
      timeout: { type: 'integer', minimum: 10, maximum: 7200, default: 3600, description: '等待最终回复的最大秒数' },
      stagnationTimeout: { type: 'integer', minimum: 60, maximum: 3600, default: 1200, description: '可见思考、工具进度和对话页连续无新内容多少秒后自动停止并在新 Chat 续作，默认 20 分钟' },
      maxRecoveryAttempts: { type: 'integer', minimum: 0, maximum: 5, default: 5, description: '停止后在新 Chat 自动发送续作指令的最大次数；超过后截图并报错' },
      autoContinueIncomplete: { type: 'boolean', default: true, description: '按机器可读最终总结识别未完成任务，并自动在全新 Chat 续作' },
      maxTaskContinuations: { type: 'integer', minimum: 0, default: 0, description: '最终总结为未完成时自动创建新 Chat 的轮数；0 表示持续执行，不设固定次数上限' },
      continuationMessage: { type: 'string', maxLength: 4000, description: '确认旧响应停止后，在新 Chat 中发送的续作指令' },
      resumeExisting: { type: 'boolean', default: false, description: '仅继续监视已发送的当前 Chat，不重复发送指令' },
      approveAll: { type: 'boolean', description: '自动确认所有授权卡片（默认 true）' },
      pollIntervalMs: { type: 'integer', minimum: 200, maximum: 5000, default: 500, description: '轮询回复的间隔毫秒数' },
    },
    required: ['message'],
  } },
  { name: 'add_connector', description: '在当前 ChatGPT 对话的 Apps 菜单中选择指定的 MCP connector', annotations: annotations(), inputSchema: {
    type: 'object', additionalProperties: false, properties: {
      connector: { type: 'string', minLength: 1, maxLength: 256, description: 'connector 名称（如 devspace1）' },
      conversationId: { type: 'string', pattern: '^[A-Za-z0-9-]{8,128}$', description: '要绑定的 ChatGPT 桌面端 Chat 会话 ID' },
      chatUrl: { type: 'string', pattern: '^https://chatgpt\\.com/(?:$|c/)', description: '精确操作的 ChatGPT 对话地址' },
    },
    required: ['connector'],
  } },
  { name: 'get_reply', description: '获取 ChatGPT 当前最新的 assistant 回复内容和流式状态', annotations: annotations(true), inputSchema: {
    type: 'object', additionalProperties: false, properties: {
      conversationId: { type: 'string', pattern: '^[A-Za-z0-9-]{8,128}$' },
      chatUrl: { type: 'string', pattern: '^https://chatgpt\\.com/(?:$|c/)' },
    },
  } },
  { name: 'chat_status', description: '获取当前 ChatGPT 聊天界面状态（输入框、流式回复、对话标题、connector 列表）', annotations: annotations(true), inputSchema: {
    type: 'object', additionalProperties: false, properties: {
      conversationId: { type: 'string', pattern: '^[A-Za-z0-9-]{8,128}$' },
      chatUrl: { type: 'string', pattern: '^https://chatgpt\\.com/(?:$|c/)' },
    },
  } },
  { name: 'prompt_templates', description: '读取内置任务提示词和最终总结协议', annotations: annotations(true), inputSchema: {
    type: 'object', additionalProperties: false, properties: {},
  } },
  { name: 'enqueue_tasks', description: '把一个或多个任务加入本地持久队列；默认共用一个专用 ChatGPT 实例，任务、验收 Chat 和等待外部结果后的定时续作均在 Chat 页面按队列安全串行；旧版隐藏 target 仅作为兼容回退', annotations: annotations(), inputSchema: {
    type: 'object', additionalProperties: false, required: ['tasks'], properties: {
      tasks: { type: 'array', minItems: 1, maxItems: 50, items: queuedTaskSchema },
      maxConcurrent: { type: 'integer', minimum: 1, maximum: 4, default: 2 },
      reviewGate: { type: 'boolean', default: true },
      start: { type: 'boolean', default: true },
    },
  } },
  { name: 'start_queue', description: '启动或恢复队列；工作和自动验收都在专用实例的 Chat 页面完成，Worker 只返回队列状态', annotations: annotations(), inputSchema: {
    type: 'object', additionalProperties: false, properties: {
      maxConcurrent: { type: 'integer', minimum: 1, maximum: 4 },
      waitForReview: { type: 'boolean', default: true },
      waitTimeout: { type: 'integer', minimum: 1, maximum: 7200, default: 3600 },
    },
  } },
  { name: 'queue_status', description: '读取任务队列、专用 ChatGPT worker 状态、验收 Chat 和待处理结果', annotations: annotations(true), inputSchema: {
    type: 'object', additionalProperties: false, properties: {},
  } },
  { name: 'wait_for_review', description: '等待队列出现待验收、阻塞或失败任务', annotations: annotations(true), inputSchema: {
    type: 'object', additionalProperties: false, properties: {
      timeout: { type: 'integer', minimum: 1, maximum: 7200, default: 3600 },
    },
  } },
  { name: 'review_task', description: '提交验收；通过后自动释放后续任务，未通过则带意见重新排队', annotations: annotations(), inputSchema: {
    type: 'object', additionalProperties: false, required: ['taskId', 'accepted'], properties: {
      taskId: { type: 'string', pattern: '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$' },
      accepted: { type: 'boolean' },
      feedback: { type: 'string', maxLength: 4000, default: '' },
    },
  } },
  { name: 'pause_queue', description: '暂停启动新任务，运行中的 worker 继续保存进度', annotations: annotations(), inputSchema: {
    type: 'object', additionalProperties: false, properties: {},
  } },
  { name: 'resume_queue', description: '从本地持久状态恢复队列和仍存活的 worker', annotations: annotations(), inputSchema: {
    type: 'object', additionalProperties: false, properties: {},
  } },
  { name: 'retry_task', description: '保留任务和工作区进度，立即新建 Chat 从中断处续作', annotations: annotations(), inputSchema: {
    type: 'object', additionalProperties: false, required: ['taskId'], properties: {
      taskId: { type: 'string', pattern: '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$' },
      feedback: { type: 'string', maxLength: 4000, default: '' },
    },
  } },
  { name: 'cancel_task', description: '取消排队中或运行中的任务', annotations: { readOnlyHint: false, destructiveHint: true, openWorldHint: false }, inputSchema: {
    type: 'object', additionalProperties: false, required: ['taskId'], properties: {
      taskId: { type: 'string', pattern: '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$' },
    },
  } },
];

export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname !== '/mcp') return new Response('Not found', { status: 404 });
    if (request.method === 'DELETE') return new Response(null, { status: 204 });
    if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
    const rpc = await request.json() as any;
    if (rpc.method === 'notifications/initialized') return new Response(null, { status: 202 });
    if (rpc.method === 'initialize') return reply(rpc.id, {
      protocolVersion: '2025-06-18', capabilities: { tools: {}, resources: {} },
      serverInfo: { name: 'chatgpt-auto-confirm', version: '0.1.0' },
    });
    if (rpc.method === 'tools/list') return reply(rpc.id, { tools });
    if (rpc.method === 'tools/call' && rpc.params?.name === 'home') return reply(rpc.id, {
      content: [{ type: 'text', text: HOME.welcome?.markdown ?? '' }], structuredContent: HOME,
    });
    if (rpc.method === 'tools/call') {
      const name = String(rpc.params?.name ?? '');
      const args = rpc.params?.arguments ?? {};
      if (name === 'start') {
        const rules = Array.isArray(args.rules) ? args.rules : [];
        if ((!args.approveAll && rules.length < 1) || rules.length > 20 || rules.some((rule: any) => {
          const parts = [rule?.application, rule?.action, rule?.resource]
            .map(value => String(value ?? '').trim());
          return parts.some(value => !value || value === '*' || value === '.*' || value.length > 256);
        })) {
          return error(rpc.id, -32602, '请启用 approveAll 或提供 1-20 条 application/action/resource 精确规则');
        }
        return hostResult(rpc.id, 'desktop.chatgpt-approvals.start', {
          rules, approveAll: args.approveAll === true,
          chatTitles: Array.isArray(args.chatTitles) ? args.chatTitles : [],
          chatUrls: Array.isArray(args.chatUrls) ? args.chatUrls : [],
          intervalMs: args.intervalMs ?? 750,
        }, 'required');
      }
      if (name === 'stop') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.stop', {}, 'required');
      if (name === 'status') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.status', {}, 'none');
      if (name === 'scan_once') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.scan-once', {}, 'required');
      if (name === 'relaunch_and_confirm') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.relaunch-and-confirm', { approveAll: args.approveAll === true }, 'required');
      if (name === 'audit_log') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.audit', { limit: args.limit ?? 20 }, 'none');
      if (name === 'diagnose') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.diagnose', {}, 'none');
      if (name === 'send_and_watch') {
        const msg = String(args.message ?? '').trim();
        if (!msg || msg.length > 10000) {
          return error(rpc.id, -32602, 'message 必须是 1-10000 字符的非空文本');
        }
        const resumeExisting = args.resumeExisting === true;
        return hostResult(rpc.id, 'desktop.chatgpt-approvals.send-and-watch', {
          message: msg,
          connector: args.connector || null,
          conversationId: resumeExisting ? (args.conversationId || null) : null,
          chatUrl: resumeExisting ? (args.chatUrl || null) : null,
          newChat: !resumeExisting,
          timeout: Math.min(7200, Math.max(10, args.timeout ?? 3600)),
          stagnationTimeout: Math.min(3600, Math.max(60, args.stagnationTimeout ?? 1200)),
          maxRecoveryAttempts: Math.min(5, Math.max(0, args.maxRecoveryAttempts ?? 5)),
          autoContinueIncomplete: args.autoContinueIncomplete !== false,
          maxTaskContinuations: Math.max(0, args.maxTaskContinuations ?? 0),
          continuationMessage: args.continuationMessage || null,
          resumeExisting,
          approveAll: args.approveAll !== false,
          pollIntervalMs: Math.min(5000, Math.max(200, args.pollIntervalMs ?? 500)),
        }, 'required');
      }
      if (name === 'add_connector') {
        const connector = String(args.connector ?? '').trim();
        if (!connector || connector.length > 256) {
          return error(rpc.id, -32602, 'connector 必须是 1-256 字符的名称');
        }
        return hostResult(rpc.id, 'desktop.chatgpt-approvals.add-connector', {
          connector, conversationId: args.conversationId || null, chatUrl: args.chatUrl || null,
        }, 'required');
      }
      if (name === 'get_reply') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.get-reply', {
          conversationId: args.conversationId || null, chatUrl: args.chatUrl || null,
        }, 'none');
      if (name === 'chat_status') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.chat-status', {
          conversationId: args.conversationId || null, chatUrl: args.chatUrl || null,
        }, 'none');
      if (name === 'prompt_templates') return reply(rpc.id, {
        content: [{ type: 'text', text: '已加载内置任务提示词。' }],
        structuredContent: {
          templates: taskPromptTemplates,
          reportProtocol: {
            protocol: 'mahayana.task-report.v1',
            markers: ['MAHAYANA_TASK_REPORT_V1_BEGIN', 'MAHAYANA_TASK_REPORT_V1_END'],
            statuses: ['complete', 'incomplete', 'blocked'],
            fields: ['summary', 'completed', 'remaining', 'blockers', 'verification', 'wait_seconds', 'wait_reason', 'next_task'],
          },
        },
      });
      if (name === 'enqueue_tasks') {
        const tasks = Array.isArray(args.tasks) ? args.tasks : [];
        if (tasks.length < 1 || tasks.length > 50) return error(rpc.id, -32602, 'tasks 必须包含 1-50 个任务');
        return hostResult(rpc.id, 'desktop.chatgpt-approvals.queue-enqueue', {
          tasks,
          maxConcurrent: Math.min(4, Math.max(1, args.maxConcurrent ?? 2)),
          reviewGate: args.reviewGate !== false,
          start: args.start !== false,
        }, 'required');
      }
      if (name === 'start_queue') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.queue-start', {
          maxConcurrent: args.maxConcurrent || null,
          waitForReview: args.waitForReview !== false,
          waitTimeout: Math.min(7200, Math.max(1, args.waitTimeout ?? 3600)),
        }, 'required');
      if (name === 'queue_status') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.queue-status', {}, 'none');
      if (name === 'wait_for_review') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.queue-wait-review', {
          timeout: Math.min(7200, Math.max(1, args.timeout ?? 3600)),
        }, 'none');
      if (name === 'review_task') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.queue-review', {
          taskId: String(args.taskId || ''),
          accepted: args.accepted === true,
          feedback: String(args.feedback || '').slice(0, 4000),
        }, 'required');
      if (name === 'pause_queue') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.queue-pause', {}, 'required');
      if (name === 'resume_queue') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.queue-resume', {}, 'required');
      if (name === 'retry_task') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.queue-retry', {
          taskId: String(args.taskId || ''),
          feedback: String(args.feedback || '').slice(0, 4000),
        }, 'required');
      if (name === 'cancel_task') return hostResult(
        rpc.id, 'desktop.chatgpt-approvals.queue-cancel', {
          taskId: String(args.taskId || ''),
        }, 'required');
    }
    if (rpc.method === 'resources/list') return reply(rpc.id, { resources: Object.keys(RESOURCES).map(uri => ({
      uri, name: uri.split('/').at(-1), mimeType: 'text/markdown',
    })) });
    if (rpc.method === 'resources/read') {
      const text = RESOURCES[String(rpc.params?.uri ?? '')];
      if (text === undefined) return error(rpc.id, -32002, 'Resource not found');
      return reply(rpc.id, { contents: [{ uri: rpc.params.uri, mimeType: 'text/markdown', text }] });
    }
    return error(rpc.id ?? null, -32601, 'Method not found');
  },
};
