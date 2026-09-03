import Foundation

let queueSameChatThinkingLimitSeconds: UInt64 = 1_200
let queueMaxSameChatFollowUps = 2

struct QueueTurnTiming: Codable, Equatable {
  var turnStartedAt: String
  var turnEndedAt: String?
  var turnStartedMonotonicNanoseconds: UInt64
  var turnEndedMonotonicNanoseconds: UInt64?
  var thinkingDurationSeconds: Double?
  var turnThinkingSeconds: Double?
  var chatConversationId: String?
  var sameChatFollowUpCount: Int
  var newChatContinuationCount: Int
}

enum QueueTurnContinuationAction: String, Codable {
  case sameChatFollowUp
  case newChat
}

func monotonicDurationSeconds(start: UInt64, end: UInt64) -> Double {
  guard end >= start else { return 0 }
  return Double(end - start) / 1_000_000_000
}

func finishQueueTurnTiming(
  _ timing: inout QueueTurnTiming,
  endedAt: String,
  monotonicNanoseconds: UInt64
) {
  timing.turnEndedAt = endedAt
  timing.turnEndedMonotonicNanoseconds = monotonicNanoseconds
  let seconds = monotonicDurationSeconds(
    start: timing.turnStartedMonotonicNanoseconds,
    end: monotonicNanoseconds
  )
  timing.thinkingDurationSeconds = seconds
  timing.turnThinkingSeconds = seconds
}

func queueTurnContinuationAction(
  taskComplete: Bool,
  timing: QueueTurnTiming
) -> QueueTurnContinuationAction? {
  guard !taskComplete else { return nil }
  let duration = timing.turnThinkingSeconds ?? timing.thinkingDurationSeconds ?? 0
  if duration < Double(queueSameChatThinkingLimitSeconds),
     timing.sameChatFollowUpCount < queueMaxSameChatFollowUps {
    return .sameChatFollowUp
  }
  return .newChat
}

func recordQueueTurnContinuation(
  _ action: QueueTurnContinuationAction,
  timing: inout QueueTurnTiming
) {
  switch action {
  case .sameChatFollowUp:
    timing.sameChatFollowUpCount += 1
  case .newChat:
    timing.newChatContinuationCount += 1
    timing.sameChatFollowUpCount = 0
  }
}

func queueSameChatContinuationPrompt() -> String {
  "继续完成原目标、检查已落盘进度、不要只总结"
}
