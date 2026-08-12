export const mahayanaHostFeatures = [
  { id: "runtime.boot", label: "Runtime 启动" },
  { id: "chat.send", label: "聊天发送与响应" },
  { id: "marketplace.install", label: "Marketplace 安装" },
  { id: "miniapp.open", label: "MiniApp 打开" },
  { id: "capability.approval", label: "敏感能力审批" },
  { id: "operation.interrupt", label: "长任务中断" },
  { id: "session.clear", label: "安全会话清除" },
] as const;

export type MahayanaHostFeatureId =
  (typeof mahayanaHostFeatures)[number]["id"];

export type MahayanaHostFeatureState = "pending" | "passed" | "failed";
