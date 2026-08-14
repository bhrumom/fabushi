import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const cargoManifestPath = resolve(
  repositoryRoot,
  "apps/fabushi-tauri/src-tauri/Cargo.toml",
);
const tauriConfigPath = resolve(
  repositoryRoot,
  "apps/fabushi-tauri/src-tauri/tauri.conf.json",
);

const [cargoManifest, tauriConfigText] = await Promise.all([
  readFile(cargoManifestPath, "utf8"),
  readFile(tauriConfigPath, "utf8"),
]);
const tauriConfig = JSON.parse(tauriConfigText);

const desktopFeature = cargoManifest.match(/desktop\s*=\s*\[([\s\S]*?)\n\]/)?.[1];
assert.ok(desktopFeature, "Cargo.toml must declare the desktop feature");

for (const requiredFeature of [
  '"production-runtime"',
  '"mahayana-feature-host/desktop-full"',
  '"mahayana-host/desktop-full"',
  '"tauri/custom-protocol"',
]) {
  assert.ok(
    desktopFeature.includes(requiredFeature),
    `desktop must enable ${requiredFeature}`,
  );
}

assert.match(
  cargoManifest,
  /\[\[bin\]\][\s\S]*?name\s*=\s*"fabushi"[\s\S]*?required-features\s*=\s*\["desktop"\]/,
  "the production executable must remain the desktop-only fabushi binary",
);
assert.equal(
  tauriConfig.build.frontendDist,
  "../../../frontend/apps/host/dist",
  "Tauri production builds must embed the shared React Host bundle",
);
assert.equal(
  tauriConfig.build.devUrl,
  "http://127.0.0.1:1420",
  "the local dev URL must remain explicit and isolated from production assets",
);
assert.equal(
  tauriConfig.bundle.active,
  false,
  "the fast compile gate must not spend time producing installers",
);
assert.ok(
  !tauriConfig.bundle.resources ||
    !Object.keys(tauriConfig.bundle.resources).some((source) =>
      source.includes(".agents/plugins"),
    ),
  "Tauri must not bundle the plugin marketplace; plugins are downloaded from the cloud on install",
);

console.log("Tauri production contract passed");
