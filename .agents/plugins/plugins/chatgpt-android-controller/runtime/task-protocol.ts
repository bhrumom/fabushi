import { createHash } from 'node:crypto';

export const TASK_REPORT_BEGIN = 'MAHAYANA_TASK_REPORT_V1_BEGIN';
export const TASK_REPORT_END = 'MAHAYANA_TASK_REPORT_V1_END';

export type TaskReportStatus = 'complete' | 'incomplete' | 'blocked';

export type TaskReport = {
  protocol: 'mahayana.task-report.v1';
  status: TaskReportStatus;
  remaining: string[];
  blockers: string[];
  next_task: string;
  summary?: string;
};

export type PromptTask = {
  id: string;
  title?: string;
  prompt: string;
  directive?: string;
  connector?: string;
  revision?: number;
  goalVersion?: number | string;
  promptTemplate?: string;
  documentDirectory?: string;
  specSources?: string[];
  dependsOn?: string[];
  priority?: number;
  timeout?: number;
  maxTaskContinuations?: number;
  maxRuntimeRetries?: number;
};

function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (value && typeof value === 'object') {
    const record = value as Record<string, unknown>;
    return `{${Object.keys(record).sort().map(key => `${JSON.stringify(key)}:${canonicalJson(record[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

export function taskRuntimeId(task: PromptTask): string {
  const digest = createHash('sha256').update(canonicalJson({
    id: task.id,
    prompt: task.prompt,
    directive: task.directive || '',
    connector: task.connector || '',
    revision: Math.max(1, Number(task.revision || 1)),
    goalVersion: task.goalVersion ?? null,
    promptTemplate: task.promptTemplate || '',
    documentDirectory: task.documentDirectory || '',
    specSources: Array.isArray(task.specSources) ? task.specSources : [],
    dependsOn: Array.isArray(task.dependsOn) ? task.dependsOn : [],
    priority: Number(task.priority || 0),
    timeout: Number(task.timeout || 0),
    maxTaskContinuations: Number(task.maxTaskContinuations ?? 0),
    maxRuntimeRetries: Number(task.maxRuntimeRetries ?? 0),
  })).digest('hex').slice(0, 12);
  return `${task.id}--v${Math.max(1, Number(task.revision || 1))}--s${digest}`;
}

export function normalizeComparable(value: unknown): string {
  return String(value || '')
    .replace(/[\u200B-\u200D\uFEFF]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .toLocaleLowerCase();
}

const UI_NOISE = new Set([
  'new chat', 'temporary chat', 'chatgpt', 'send', 'stop', 'voice mode',
  'attach files', 'photos', 'camera', 'search', 'apps', 'tools',
  '新聊天', '发送', '傳送', '停止', '语音模式', '語音模式',
]);

export function diffVisibleTexts(
  current: unknown[],
  baseline: unknown[],
  sentMessage = '',
): string[] {
  const baselineCounts = new Map<string, number>();
  for (const raw of baseline) {
    const key = normalizeComparable(raw);
    if (!key) continue;
    baselineCounts.set(key, (baselineCounts.get(key) || 0) + 1);
  }

  const sent = normalizeComparable(sentMessage);
  const out: string[] = [];
  for (const raw of current) {
    const text = String(raw || '').replace(/\s+/g, ' ').trim();
    const key = normalizeComparable(text);
    if (!key) continue;
    const count = baselineCounts.get(key) || 0;
    if (count > 0) {
      baselineCounts.set(key, count - 1);
      continue;
    }
    if (UI_NOISE.has(key)) continue;
    if (sent && (key === sent || (key.length >= 8 && sent.includes(key)))) continue;
    out.push(text);
  }
  return out;
}

export function assistantDeltaText(
  current: unknown[],
  baseline: unknown[],
  sentMessage = '',
): string {
  return diffVisibleTexts(current, baseline, sentMessage).join('\n').trim();
}

function stringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map(item => String(item || '').trim()).filter(Boolean).slice(0, 100);
}

export function parseTaskReport(text: unknown): TaskReport | null {
  const source = String(text || '');
  const start = source.lastIndexOf(TASK_REPORT_BEGIN);
  const end = source.lastIndexOf(TASK_REPORT_END);
  if (start < 0 || end <= start) return null;
  const body = source.slice(start + TASK_REPORT_BEGIN.length, end).trim();
  const objectStart = body.indexOf('{');
  const objectEnd = body.lastIndexOf('}');
  if (objectStart < 0 || objectEnd <= objectStart) return null;
  let value: any;
  try {
    value = JSON.parse(body.slice(objectStart, objectEnd + 1));
  } catch {
    return null;
  }
  if (value?.protocol !== 'mahayana.task-report.v1') return null;
  if (!['complete', 'incomplete', 'blocked'].includes(String(value.status || ''))) return null;
  const report: TaskReport = {
    protocol: 'mahayana.task-report.v1',
    status: value.status as TaskReportStatus,
    remaining: stringList(value.remaining),
    blockers: stringList(value.blockers),
    next_task: String(value.next_task || '').trim(),
  };
  if (value.summary != null) report.summary = String(value.summary).trim().slice(0, 4000);
  if (report.status !== 'complete' && !report.next_task) return null;
  return report;
}

function reportContract(taskId: string): string {
  return [
    'MAHAYANA_TASK_REPORT_CONTRACT_V2',
    `task_id=${taskId}`,
    '你必须持续完成任务，而不是只给计划。每一轮先实际工作，再在回复末尾输出且只输出一个机器可读报告块。',
    '完成时 status=complete，remaining/blockers 为空，next_task 为空。',
    '仍有工作时 status=incomplete；遇到外部阻塞时 status=blocked；两种情况都必须给出非空 next_task，作为下一轮可直接执行的指令。',
    `${TASK_REPORT_BEGIN}`,
    '{"protocol":"mahayana.task-report.v1","status":"complete|incomplete|blocked","remaining":[],"blockers":[],"next_task":"","summary":""}',
    `${TASK_REPORT_END}`,
    '不要把报告块放进 Markdown 代码围栏。',
  ].join('\n');
}

export function buildInitialTaskPrompt(task: PromptTask): string {
  const sections = [
    `任务：${task.title || task.id}`,
    task.prompt.trim(),
  ];
  if (task.directive?.trim()) sections.push(`追加指令：\n${task.directive.trim()}`);
  if (task.documentDirectory?.trim()) sections.push(`工作目录/文档目录：${task.documentDirectory.trim()}`);
  if (Array.isArray(task.specSources) && task.specSources.length) {
    sections.push(`规格来源：\n${task.specSources.map(item => `- ${item}`).join('\n')}`);
  }
  sections.push(reportContract(task.id));
  return sections.filter(Boolean).join('\n\n');
}

export function buildContinuationPrompt(task: PromptTask, report: TaskReport, round: number): string {
  const next = report.next_task.trim();
  return [
    `继续任务 ${task.id}，这是自动续作第 ${round} 轮。`,
    `上一轮状态：${report.status}`,
    report.remaining.length ? `仍需完成：\n${report.remaining.map(item => `- ${item}`).join('\n')}` : '',
    report.blockers.length ? `阻塞信息：\n${report.blockers.map(item => `- ${item}`).join('\n')}` : '',
    `下一步：\n${next}`,
    '直接继续实际工作，不要复述背景，不要等待人工确认。',
    reportContract(task.id),
  ].filter(Boolean).join('\n\n');
}

export function continuationBudget(requested: unknown, hardLimit = 50): number {
  const hard = Math.min(200, Math.max(1, Math.trunc(Number(hardLimit) || 50)));
  const value = Math.trunc(Number(requested));
  if (!Number.isFinite(value) || value <= 0) return hard;
  return Math.min(hard, Math.max(1, value));
}
