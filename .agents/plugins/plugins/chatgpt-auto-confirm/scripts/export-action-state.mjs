import { readFileSync } from 'node:fs';
import { gzipSync } from 'node:zlib';

const statePath = process.env.CHATGPT_AUTO_CONFIRM_QUEUE_STATE;
if (!statePath) throw new Error('CHATGPT_AUTO_CONFIRM_QUEUE_STATE is required');
const state = JSON.parse(readFileSync(statePath, 'utf8'));
state.audit = [];
state.queueWatcherPid = null;
state.queueWorkerPort = null;
state.queueWorkerTargetId = null;
state.queueWorkerProfilePath = null;
state.queueWorkerMode = null;
for (const task of state.automationTasks || []) {
  task.workerPid = null;
  task.workerPort = null;
  task.workerTargetId = null;
  task.workerStatePath = null;
  task.workerProfilePath = null;
  task.resultPath = null;
  task.lastResultJSON = null;
  task.reportFingerprints = Array.isArray(task.reportFingerprints)
    ? task.reportFingerprints.slice(-10)
    : [];
}
const encoded = gzipSync(Buffer.from(JSON.stringify(state))).toString('base64');
if (Buffer.byteLength(encoded) > 47_000) {
  throw new Error(`Queue state exceeds the GitHub secret budget (${Buffer.byteLength(encoded)} bytes)`);
}
process.stdout.write(encoded);
