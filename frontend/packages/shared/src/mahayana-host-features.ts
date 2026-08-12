export type MahayanaHostJourneyStep =
  | { action: "expectText"; testId: string; text: string }
  | { action: "expectContainsText"; testId: string; text: string }
  | { action: "fill"; testId: string; value: string }
  | { action: "click"; testId: string }
  | { action: "expectVisible"; testId: string }
  | { action: "expectDialog"; name: string };

export const mahayanaHostFeatures = [
  {
    id: "runtime.boot",
    label: "Runtime 启动",
    journey: [
      { action: "expectText", testId: "host-status", text: "ready" },
    ],
  },
  {
    id: "chat.send",
    label: "聊天发送与响应",
    journey: [
      {
        action: "fill",
        testId: "chat-input",
        value: "验证极速自动化测试",
      },
      { action: "click", testId: "send-message" },
      {
        action: "expectContainsText",
        testId: "messages",
        text: "收到：验证极速自动化测试",
      },
    ],
  },
  {
    id: "marketplace.install",
    label: "Marketplace 安装",
    journey: [
      { action: "click", testId: "install-miniapp" },
      {
        action: "expectText",
        testId: "marketplace-state",
        text: "installed",
      },
    ],
  },
  {
    id: "miniapp.open",
    label: "MiniApp 打开",
    journey: [
      { action: "click", testId: "open-miniapp" },
      { action: "expectVisible", testId: "miniapp-panel" },
    ],
  },
  {
    id: "capability.approval",
    label: "敏感能力审批",
    journey: [
      { action: "click", testId: "request-capability" },
      { action: "expectDialog", name: "能力审批" },
      { action: "click", testId: "approve-capability" },
      {
        action: "expectText",
        testId: "approval-state",
        text: "allowed",
      },
    ],
  },
  {
    id: "operation.interrupt",
    label: "长任务中断",
    journey: [
      { action: "click", testId: "start-long-operation" },
      {
        action: "expectText",
        testId: "operation-state",
        text: "running",
      },
      { action: "click", testId: "interrupt-operation" },
      {
        action: "expectText",
        testId: "operation-state",
        text: "interrupted",
      },
    ],
  },
  {
    id: "session.clear",
    label: "安全会话清除",
    journey: [
      { action: "click", testId: "clear-session" },
      {
        action: "expectText",
        testId: "session-state",
        text: "cleared",
      },
    ],
  },
] as const satisfies ReadonlyArray<{
  id: string;
  label: string;
  journey: ReadonlyArray<MahayanaHostJourneyStep>;
}>;

export type MahayanaHostFeatureId =
  (typeof mahayanaHostFeatures)[number]["id"];

export type MahayanaHostFeatureState = "pending" | "passed" | "failed";
