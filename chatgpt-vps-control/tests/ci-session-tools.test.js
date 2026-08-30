import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { appendCiSessionNote, normalizeCiSessionDirectory, readCiSessionStatus, requestCiSessionFinish } from "../lib/ci-session-tools.js";

test("CI session evidence is confined to RUNNER_TEMP and supports status, notes, and finish", async () => {
  const root = await mkdtemp(join(tmpdir(), "fabushi-ci-session-"));
  const directory = join(root, "session");
  try {
    assert.equal(normalizeCiSessionDirectory(directory, { GITHUB_ACTIONS: "true", RUNNER_TEMP: root }), directory);
    await writeFile(join(root, "status.tmp"), "unused");
    await import("node:fs/promises").then(({ mkdir }) => mkdir(directory, { recursive: true }));
    await writeFile(join(directory, "status.json"), JSON.stringify({ phase: "app-ready", message: "Fabushi launched", appReady: true, deviceId: "gha-1" }));
    const status = await readCiSessionStatus(directory);
    assert.equal(status.appReady, true);
    assert.equal(status.deviceId, "gha-1");
    await appendCiSessionNote(directory, "Login and navigation passed.");
    assert.match(await readFile(join(directory, "remote-notes.jsonl"), "utf8"), /navigation passed/);
    await requestCiSessionFinish(directory, "Live regression complete");
    assert.match(await readFile(join(directory, "finish-requested.json"), "utf8"), /Live regression complete/);
    assert.throws(() => normalizeCiSessionDirectory("/tmp/outside", { GITHUB_ACTIONS: "true", RUNNER_TEMP: root }), /RUNNER_TEMP/);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
