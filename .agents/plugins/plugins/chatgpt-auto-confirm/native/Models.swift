import ApplicationServices
import Cocoa
import Darwin
import Foundation
import SystemConfiguration

struct ApprovalRule: Codable {
  let id: String
  let application: String
  let action: String
  let resource: String
}

struct AuditEvent: Codable {
  let at: String
  let decision: String
  let reason: String
  let clicked: Bool
  let ruleId: String?
  let buttonTitle: String
  let promptText: String
  let error: String?
}

struct PluginState: Codable {
  var enabled = false
  var rules: [ApprovalRule] = []
  var approveAll: Bool?
  var chatTitles: [String]?
  var trackedChatURLs: [String]?
  var backgroundTargets: [String: String]?
  var backgroundAppPort: Int?
  var backgroundChatTargetId: String?
  var backgroundProfilePath: String?
  var backgroundConversationId: String?
  var intervalMs = 750
  var watcherPid: Int32?
  var startedAt: String?
  var lastError: String?
  var audit: [AuditEvent] = []
  var automationTasks: [AutomationTask]?
  var queueEnabled: Bool?
  var queuePaused: Bool?
  var queueMaxConcurrent: Int?
  var queueReviewGate: Bool?
  var queueWatcherPid: Int32?
  var queueRuntimeRevision: String?
  // Every running task owns a hidden ChatGPT process cloned from the restored
  // authenticated profile. It never navigates the primary window where the
  // user types, and tasks cannot close one another's renderer.
  var queueWorkerPort: Int?
  var queueWorkerTargetId: String?
  var queueWorkerProfilePath: String?
  var queueWorkerMode: String?
  // Reachability is queue-level state: a transient DNS/network/upstream
  // outage pauses the durable queue instead of terminating or duplicating
  // active Chat work.
  var queueNetworkStatus: String?
  var queueNetworkLastError: String?
  var queueNetworkFailureCount: Int?
  var queueNetworkWaitUntil: String?
}

struct AutomationTaskReport: Codable {
  var protocolName: String
  var status: String
  var summary: String
  var completed: [String]
  var remaining: [String]
  var blockers: [String]
  var verification: [String]
  var nextTask: String
  // When an external job (for example, GitHub Actions) is still running, the
  // Chat ends with an incomplete report and asks the queue to come back later
  // instead of keeping a renderer and a model response idle.
  var waitSeconds: Int?
  var waitReason: String?
  // A finished Chat can choose the connector for the next fresh Chat. This
  // is useful when a local bhrum2 step has pushed code and the next step must
  // inspect GitHub Actions through the GitHub connector.
  var nextConnector: String?

  enum CodingKeys: String, CodingKey {
    case protocolName = "protocol"
    case status, summary, completed, remaining, blockers, verification
    case nextTask = "next_task"
    case waitSeconds = "wait_seconds"
    case waitReason = "wait_reason"
    case nextConnector = "next_connector"
  }
}

struct AutomationTask: Codable {
  var id: String
  var title: String
  var prompt: String
  var promptTemplate: String
  var connector: String
  var dependsOn: [String]
  var resourceLocks: [String]
  var priority: Int
  var timeout: Int
  var maxTaskContinuations: Int
  var maxRuntimeRetries: Int
  var attempts: Int
  var reviewRound: Int
  var status: String
  var createdAt: String
  var updatedAt: String
  var startedAt: String?
  var finishedAt: String?
  var workerPid: Int32?
  var workerPort: Int?
  var workerTargetId: String?
  var workerStatePath: String?
  var workerProfilePath: String?
  var resultPath: String?
  var conversationId: String?
  var reviewConversationId: String?
  var reviewStatus: String?
  var reviewReport: AutomationTaskReport?
  var chatURL: String?
  var report: AutomationTaskReport?
  var lastResultJSON: String?
  var lastError: String?
  var reviewFeedback: String?
  var reviewedAt: String?
  var continuationDepth: Int?
  var reportFingerprints: [String]?
  var lastActivitySignature: String?
  var lastProgressAt: String?
  var waitingUntil: String?
  var waitReason: String?
  // Conversation is durable state; hidden renderer is only a recoverable worker.
  // These fields allow the queue to recover after a renderer disappears instead
  // of treating the task as failed.
  var hiddenWorkerLastHeartbeatAt: String? = nil
  var hiddenWorkerRecoveryCount: Int? = nil
  var hiddenWorkerLastError: String? = nil
  // GitHub-hosted sessions persist their recovery boundary in task state so a
  // later Actions run can distinguish fresh progress from an old renderer.
  var watchdogLastRecoveryAt: String? = nil
  var watchdogRecoveryCount: Int? = nil
}

struct Candidate {
  let element: AXUIElement
  let promptText: String
  let buttonTitle: String
}
