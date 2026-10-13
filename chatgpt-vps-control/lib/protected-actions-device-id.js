export function isProtectedActionsTestDeviceId(value) {
  return /^gha-[0-9]+-[0-9]+-(?:interactive|retention-app-[ab]|(?:ios|macos|windows)-app(?:-[ab])?)$/u.test(String(value || ""));
}
