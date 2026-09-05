import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const read = (path) => readFile(new URL(path, root), "utf8");

test("interactive Runner supports explicit protected account bindings", async () => {
  const workflow = await read(".github/workflows/interactive-runner-mcp.yml");
  assert.match(workflow, /account_binding:/u);
  assert.match(workflow, /default: ci-test-account/u);
  assert.match(workflow, /- ci-test-account/u);
  assert.match(workflow, /id-token: write/u);
  assert.match(workflow, /audience=fabushi-ci-runner/u);
  assert.match(workflow, /\/v1\/ci\/runner-session/u);
  assert.match(workflow, /if: inputs\.account_binding == 'github-actor'/u);
  assert.match(workflow, /if: inputs\.account_binding == 'ci-test-account'/u);
  assert.match(workflow, /secrets\.FABUSHI_CI_TEST_USERNAME/u);
  assert.match(workflow, /secrets\.FABUSHI_CI_TEST_PASSWORD/u);
  assert.match(workflow, /login-ci-test-account\.mjs/u);
  assert.match(workflow, /export-ci-app-account-session\.mjs/u);
  assert.match(workflow, /FABUSHI_ACCOUNT_SESSION_FILE/u);
  assert.match(workflow, /FABUSHI_CI_ACCOUNT_SESSION_FILE/u);
  assert.match(workflow, /GitHub-linked Fabushi account/u);
  assert.doesNotMatch(workflow, /TEST_ACCOUNT_TOKEN/u);
  assert.doesNotMatch(workflow, /MAHAYANA_TEST_ACCOUNT_TOKEN/u);
  assert.doesNotMatch(workflow, /FABUSHI_ACCOUNT_ACCESS_TOKEN/u);
  assert.doesNotMatch(workflow, /FABUSHI_CI_TEST_ACCOUNT_AUTOLOGIN/u);
  assert.doesNotMatch(workflow, /nohup node chatgpt-vps-control\/bin\/fabushi-device-agent\.js/u);
  assert.doesNotMatch(workflow, /device-agent\.pid/u);
  assert.match(workflow, /controllable device online/u);
  assert.match(workflow, /installed application owns device registration/u);
});

test("the installed app owns account-bound remote-device registration", async () => {
  const main = await read("desktop/electron/main.cjs");
  const supervisor = await read("desktop/electron/remote-device-agent-supervisor.cjs");
  const host = await read("third_party/mahayana/mahayana-rs/mahayana-app-host/src/lib.rs");
  assert.match(main, /RemoteDeviceAgentSupervisor/u);
  assert.match(supervisor, /feature\.auth\.deviceAgentSession/u);
  assert.match(supervisor, /OFFICIAL_DEVICE_GATEWAY_URL/u);
  assert.match(supervisor, /FABUSHI_ACCOUNT_TOKEN_FILE/u);
  assert.match(supervisor, /FABUSHI_ACCOUNT_SESSION_FILE: ''/u);
  assert.match(host, /feature\.auth\.deviceAgentSession/u);
});

test("CI Runner token exchange is exact-repository, exact-workflow and linked-account scoped", async () => {
  const source = await read("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/ci_runner.rs");
  for (const required of [
    "https://token.actions.githubusercontent.com",
    'const CI_REPOSITORY: &str = "bhrumom/fabushi"',
    'const CI_REPOSITORY_ID: &str = "1037709914"',
    'const CI_REPOSITORY_OWNER_ID: &str = "281146136"',
    "interactive-runner-mcp.yml@refs/heads/main",
    'const CI_PROTECTED_REF: &str = "refs/heads/main"',
    "ref_protected",
    "workflow_dispatch",
    "github-hosted",
    "account_identities",
    "provider = 'github'",
    "subject = ?1",
    "gha-{}-{}-interactive",
    "CI_OIDC_MAX_AGE_SECONDS",
  ]) assert.ok(source.includes(required), `missing CI Runner security invariant: ${required}`);
  assert.doesNotMatch(source, /TEST_ACCOUNT_TOKEN/u);
  assert.doesNotMatch(source, /password/u);
  assert.doesNotMatch(source, /refreshToken/u);
});

test("packaged app accepts only a private short-lived GitHub Actions session file", async () => {
  const source = await read("third_party/mahayana/mahayana-rs/mahayana-product/src/lib.rs");
  assert.match(source, /FABUSHI_CI_ACCOUNT_SESSION_FILE/u);
  assert.match(source, /accepted only inside GitHub Actions/u);
  assert.match(source, /regular non-symlink file/u);
  assert.match(source, /mode\(\) & 0o077/u);
  assert.match(source, /provider"\)\.and_then\(Value::as_str\) == Some\("github-actions"\)/u);
  assert.match(source, /value\.get\("refreshToken"\)\.is_none\(\)/u);
  assert.match(source, /session_id\.starts_with\("ci-runner:"\)/u);
  assert.match(source, /device_id\.ends_with\("-interactive"\)/u);
  assert.match(source, /device_id\.ends_with\("-macos-app"\)/u);
  assert.match(source, /pub fn device_agent_session/u);
});
