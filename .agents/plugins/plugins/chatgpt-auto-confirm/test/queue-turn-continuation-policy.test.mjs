import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const pluginRoot = fileURLToPath(new URL('..', import.meta.url));
const policyPath = join(pluginRoot, 'native', 'QueueTurnContinuationPolicy.swift');

test('queue turn continuation policy uses monotonic timing and rolls chat after two follow-ups or 1200 seconds', () => {
  const directory = mkdtempSync(join(tmpdir(), 'queue-turn-policy-'));
  const driverPath = join(directory, 'main.swift');
  const binaryPath = join(directory, 'policy-test');
  try {
    writeFileSync(driverPath, `import Foundation

func timing(_ seconds: Double, _ followUps: Int) -> QueueTurnTiming {
  QueueTurnTiming(
    turnStartedAt: "2026-09-03T00:00:00Z",
    turnEndedAt: "2026-09-03T00:00:01Z",
    turnStartedMonotonicNanoseconds: 10,
    turnEndedMonotonicNanoseconds: UInt64(10 + seconds * 1_000_000_000),
    thinkingDurationSeconds: seconds,
    turnThinkingSeconds: seconds,
    chatConversationId: "chat-1",
    sameChatFollowUpCount: followUps,
    newChatContinuationCount: 0
  )
}

guard queueTurnContinuationAction(taskComplete: false, timing: timing(1199, 0)) == .sameChatFollowUp else { exit(1) }
guard queueTurnContinuationAction(taskComplete: false, timing: timing(1199, 1)) == .sameChatFollowUp else { exit(2) }
guard queueTurnContinuationAction(taskComplete: false, timing: timing(1199, 2)) == .newChat else { exit(3) }
guard queueTurnContinuationAction(taskComplete: false, timing: timing(1200, 0)) == .newChat else { exit(4) }
guard queueTurnContinuationAction(taskComplete: true, timing: timing(1, 0)) == nil else { exit(5) }

var measured = timing(0, 0)
measured.turnStartedMonotonicNanoseconds = 1_000_000_000
finishQueueTurnTiming(&measured, endedAt: "wall-clock-can-jump", monotonicNanoseconds: 3_500_000_000)
guard measured.turnThinkingSeconds == 2.5 else { exit(6) }

var counters = timing(30, 1)
recordQueueTurnContinuation(.sameChatFollowUp, timing: &counters)
guard counters.sameChatFollowUpCount == 2 else { exit(7) }
recordQueueTurnContinuation(.newChat, timing: &counters)
guard counters.sameChatFollowUpCount == 0 && counters.newChatContinuationCount == 1 else { exit(8) }
guard queueSameChatContinuationPrompt() == "继续完成原目标、检查已落盘进度、不要只总结" else { exit(9) }
print("queue-turn-policy-ok")
`);
    execFileSync('xcrun', ['swiftc', policyPath, driverPath, '-o', binaryPath], { stdio: 'pipe' });
    assert.equal(execFileSync(binaryPath, { encoding: 'utf8' }).trim(), 'queue-turn-policy-ok');
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
