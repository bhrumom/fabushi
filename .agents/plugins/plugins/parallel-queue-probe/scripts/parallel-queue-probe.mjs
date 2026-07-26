#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export const verifyEvidence = evidence => {
  const workers = Array.isArray(evidence?.activeWorkers) ? evidence.activeWorkers : [];
  const targetIds = workers.map(worker => worker?.targetId).filter(Boolean);
  const criteria = {
    actionReportedPassed: evidence?.status === 'passed',
    parallelMode:
      evidence?.executionMode === 'single-authenticated-process-multi-hidden-window-parallel',
    requestedConcurrency: Number(evidence?.requestedMaxConcurrent) >= 2,
    effectiveConcurrency: Number(evidence?.effectiveMaxConcurrent) >= 2,
    twoActiveWorkers: workers.length >= 2,
    isolatedTargets: targetIds.length >= 2 && new Set(targetIds).size === targetIds.length,
    hiddenTargets: workers.length >= 2 &&
      workers.every(worker => worker?.visibilityVerified === true),
    dynamicEnqueue: Array.isArray(evidence?.criteria) &&
      evidence.criteria.some(item => String(item).includes('task B was enqueued after task A')),
    observedOverlap: Array.isArray(evidence?.criteria) &&
      evidence.criteria.some(item => String(item).includes('both tasks were running')),
  };
  const failures = Object.entries(criteria)
    .filter(([, passed]) => !passed)
    .map(([name]) => name);
  return {
    ok: failures.length === 0,
    protocol: 'mahayana.parallel-queue-verification.v1',
    criteria,
    failures,
    summary: failures.length === 0
      ? '动态任务队列已通过真实并行与隐藏 Chat 隔离验收。'
      : `并行队列未通过：${failures.join(', ')}`,
  };
};

const verifyPath = evidencePath => {
  const evidence = JSON.parse(readFileSync(evidencePath, 'utf8'));
  return verifyEvidence(evidence);
};

const send = payload => process.stdout.write(`${JSON.stringify(payload)}\n`);

const serveMcp = async () => {
  process.stdin.setEncoding('utf8');
  let buffer = '';
  for await (const chunk of process.stdin) {
    buffer += chunk;
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() || '';
    for (const line of lines) {
      if (!line.trim()) continue;
      const request = JSON.parse(line);
      if (request.method === 'initialize') {
        send({
          jsonrpc: '2.0',
          id: request.id,
          result: {
            protocolVersion: '2025-06-18',
            capabilities: { tools: {} },
            serverInfo: { name: 'parallel-queue-probe', version: '0.1.0' },
          },
        });
      } else if (request.method === 'tools/list') {
        send({
          jsonrpc: '2.0',
          id: request.id,
          result: {
            tools: [{
              name: 'verify_parallel_queue',
              description: 'Verify a parallel-queue-evidence.json Action artifact.',
              inputSchema: {
                type: 'object',
                properties: {
                  evidencePath: { type: 'string' },
                },
                required: ['evidencePath'],
                additionalProperties: false,
              },
            }],
          },
        });
      } else if (request.method === 'tools/call' &&
                 request.params?.name === 'verify_parallel_queue') {
        try {
          const result = verifyPath(request.params.arguments?.evidencePath);
          send({
            jsonrpc: '2.0',
            id: request.id,
            result: {
              content: [{ type: 'text', text: result.summary }],
              structuredContent: result,
              isError: !result.ok,
            },
          });
        } catch (error) {
          send({
            jsonrpc: '2.0',
            id: request.id,
            error: { code: -32602, message: error.message },
          });
        }
      } else if (request.id !== undefined) {
        send({
          jsonrpc: '2.0',
          id: request.id,
          error: { code: -32601, message: 'Method not found' },
        });
      }
    }
  }
};

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [command, evidencePath] = process.argv.slice(2);
  if (command === 'mcp-serve') {
    await serveMcp();
  } else if (command === 'verify' && evidencePath) {
    const result = verifyPath(evidencePath);
    send(result);
    if (!result.ok) process.exitCode = 1;
  } else {
    process.stderr.write(
      'Usage: parallel-queue-probe.mjs verify <parallel-queue-evidence.json> | mcp-serve\n',
    );
    process.exitCode = 2;
  }
}
