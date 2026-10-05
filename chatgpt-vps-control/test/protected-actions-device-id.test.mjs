import assert from "node:assert/strict";
import test from "node:test";
import { isProtectedActionsTestDeviceId } from "../lib/protected-actions-device-id.js";

test("protected GitHub Actions app device ids remain run-bound and allow dual-device suffixes", () => {
  for (const value of [
    "gha-123-1-interactive",
    "gha-123-1-ios-app",
    "gha-123-1-ios-app-a",
    "gha-123-1-ios-app-b",
    "gha-123-1-macos-app",
    "gha-123-1-macos-app-a",
    "gha-123-1-macos-app-b",
    "gha-123-1-windows-app",
    "gha-123-1-windows-app-a",
    "gha-123-1-windows-app-b",
  ]) assert.equal(isProtectedActionsTestDeviceId(value), true, value);

  for (const value of [
    "",
    "macos-app-a",
    "gha-main-1-macos-app-a",
    "gha-123-x-macos-app-a",
    "gha-123-1-macos-app-c",
    "gha-123-1-linux-app-a",
    "gha-123-1-macos-app-a-extra",
    "gha-123-1-interactive-a",
  ]) assert.equal(isProtectedActionsTestDeviceId(value), false, value);
});
