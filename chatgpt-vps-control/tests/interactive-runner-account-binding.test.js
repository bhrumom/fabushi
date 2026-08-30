import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const read = (path) => readFile(new URL(path, root), "utf8");

test("interactive Runner uses GitHub OIDC and no shared test-account credential", async () => {
  const workflow = await read(".github/workflows/interactive-runner-mcp.yml");
  assert.match(workflow, /id-token: write/u);
  assert.match(workflow, /audience=fabushi-ci-runner/u);
  assert.match(workflow, /\/v1\/ci\/runner-session/u);
  assert.match(workflow, /FABUSHI_ACCOUNT_SESSION_FILE/u);
  assert.match(workflow, /FABUSHI_CI_ACCOUNT_SESSION_FILE/u);
  assert.match(workflow, /GitHub-linked Fabushi account/u);
  assert.doesNotMatch(workflow, /TEST_ACCOUNT_TOKEN/u);
  assert.doesNotMatch(workflow, /MAHAYANA_TEST_ACCOUNT_TOKEN/u);
  assert.doesNotMatch(workflow, /FABUSHI_ACCOUNT_ACCESS_TOKEN/u);
  assert.doesNotMatch(workflow, /FABUSHI_CI_TEST_ACCOUNT_AUTOLOGIN/u);
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
});
