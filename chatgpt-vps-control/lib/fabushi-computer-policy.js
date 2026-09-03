import { readFileSync } from "node:fs";

const ALLOWED_LOCAL_TOOL_PERMISSIONS = new Set(["ask", "always"]);

/**
 * Read the authoritative Rust Feature Host settings immediately before each
 * Computer Use tool authorization check. Missing, malformed, or incomplete
 * policy is denied so packaging/startup races cannot silently enable control.
 */
export function computerControlPolicyDecision({ env = process.env, readFile = readFileSync } = {}) {
  const policyFile = String(env.FABUSHI_COMPUTER_POLICY_FILE || "").trim();
  if (!policyFile) {
    return { allowed: false, reason: "Fabushi 电脑控制策略未配置。" };
  }

  let settings;
  try {
    settings = JSON.parse(readFile(policyFile, "utf8"));
  } catch (error) {
    if (error?.code === "ENOENT") {
      return { allowed: false, reason: "Fabushi 电脑控制策略尚未准备好。" };
    }
    return { allowed: false, reason: "无法安全读取 Fabushi 电脑控制策略。" };
  }

  if (!settings || typeof settings !== "object" || Array.isArray(settings)) {
    return { allowed: false, reason: "Fabushi 电脑控制策略格式无效。" };
  }
  if (settings.localExecution !== true) {
    return { allowed: false, reason: "本机执行已在 Fabushi 设置中关闭。" };
  }
  if (settings.aiComputerControlEnabled !== true) {
    return { allowed: false, reason: "AI 电脑控制已在 Fabushi 设置中关闭。" };
  }
  if (settings.localToolPermission === "never") {
    return { allowed: false, reason: "本机工具权限已设置为永不允许。" };
  }
  if (!ALLOWED_LOCAL_TOOL_PERMISSIONS.has(settings.localToolPermission)) {
    return { allowed: false, reason: "Fabushi 本机工具权限策略无效。" };
  }
  return { allowed: true };
}
