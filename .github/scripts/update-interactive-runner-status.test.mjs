import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { promisify } from "node:util";
import test from "node:test";
const exec = promisify(execFile);

test("interactive Runner status is atomically written inside RUNNER_TEMP", async () => {
  const root = await mkdtemp(join(tmpdir(), "fabushi-runner-status-"));
  const directory = join(root, "session");
  try {
    await exec(process.execPath, [resolve(".github/scripts/update-interactive-runner-status.mjs"), "app-ready", "Fabushi is ready", "true", "/tmp/fabushi"], {
      env: {
        ...process.env,
        GITHUB_ACTIONS: "true",
        RUNNER_TEMP: root,
        FABUSHI_CI_SESSION_DIR: directory,
        DEVICE_ID: "gha-123",
        GITHUB_REPOSITORY: "bhrumom/fabushi",
        GITHUB_RUN_ID: "123",
      },
    });
    const status = JSON.parse(await readFile(join(directory, "status.json"), "utf8"));
    assert.equal(status.phase, "app-ready");
    assert.equal(status.appReady, true);
    assert.equal(status.deviceId, "gha-123");
    assert.equal(status.runUrl, "https://github.com/bhrumom/fabushi/actions/runs/123");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
