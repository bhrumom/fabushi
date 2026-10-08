export function isProtectedActionsTestDeviceId(value) {
  return /^gha-[0-9]+-[0-9]+-(?:interactive|(?:ios|macos|windows)-app(?:-[ab])?)$/u.test(String(value || ""));
}
