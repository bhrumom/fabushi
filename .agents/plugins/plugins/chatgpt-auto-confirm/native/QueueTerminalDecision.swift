import Foundation

struct QueueReplyTerminalDecision {
  let responseIsInFlight: Bool
  let terminalIncomplete: Bool
  let terminalEvidence: Bool
  let terminal: Bool
}

func queueReplyTerminalDecision(_ reply: [String: Any]) -> QueueReplyTerminalDecision {
  let activelyResponding = reply["streaming"] as? Bool == true
    || reply["stopAvailable"] as? Bool == true
    || reply["waitingForApproval"] as? Bool == true
    || reply["devspaceWaiting"] as? Bool == true
  let pending = reply["pending"] as? Bool == true
  let responseIsInFlight = activelyResponding || pending

  // `explicitlyIncomplete` is only a text classifier. It may be true while a
  // response is still streaming and therefore must never become terminal
  // evidence on its own. The JS-level `terminalIncomplete` value already
  // requires completed-response UI evidence.
  let terminalIncomplete = reply["terminalIncomplete"] as? Bool == true
  let terminalEvidence = reply["done"] as? Bool == true
    || reply["completionCandidate"] as? Bool == true
    || terminalIncomplete

  return QueueReplyTerminalDecision(
    responseIsInFlight: responseIsInFlight,
    terminalIncomplete: terminalIncomplete,
    terminalEvidence: terminalEvidence,
    terminal: !responseIsInFlight && terminalEvidence
  )
}
