import { createHash } from "node:crypto";
import { promises as fs } from "node:fs";
import path from "node:path";

const root = process.cwd();
const manifestPath = path.join(root, "contracts/migration/legacy-surface.json");
const manifest = JSON.parse(await fs.readFile(manifestPath, "utf8"));

if (manifest.schemaVersion !== 1) {
  throw new Error(`Unsupported migration manifest schema: ${manifest.schemaVersion}`);
}

async function walk(relativeRoot) {
  const absoluteRoot = path.join(root, relativeRoot);
  const entries = await fs.readdir(absoluteRoot, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const relative = path.posix.join(relativeRoot, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await walk(relative)));
    } else if (entry.isFile() && entry.name.endsWith(".dart")) {
      files.push(relative);
    }
  }
  return files;
}

const trackedFiles = (
  await Promise.all(manifest.trackedRoots.map((trackedRoot) => walk(trackedRoot)))
)
  .flat()
  // Match `LC_ALL=C sort` exactly. Locale collation can treat punctuation
  // differently across runner images and would make the SHA non-portable.
  .sort((left, right) => (left < right ? -1 : left > right ? 1 : 0));
const fingerprintInput = `${trackedFiles.join("\n")}\n`;
const fingerprint = createHash("sha256").update(fingerprintInput).digest("hex");

const errors = [];
if (trackedFiles.length !== manifest.expected.fileCount) {
  errors.push(
    `legacy file count changed: expected ${manifest.expected.fileCount}, found ${trackedFiles.length}`,
  );
}
if (fingerprint !== manifest.expected.sha256) {
  errors.push(
    `legacy surface fingerprint changed: expected ${manifest.expected.sha256}, found ${fingerprint}`,
  );
}

const allowedStatuses = new Set(["pending", "in-progress", "migrated", "deleted"]);
const seenDomainIds = new Set();
const compiledDomains = manifest.domains.map((domain) => {
  if (seenDomainIds.has(domain.id)) errors.push(`duplicate domain id: ${domain.id}`);
  seenDomainIds.add(domain.id);
  if (!allowedStatuses.has(domain.status)) {
    errors.push(`invalid status for ${domain.id}: ${domain.status}`);
  }
  if (!Array.isArray(domain.patterns) || domain.patterns.length === 0) {
    errors.push(`domain has no patterns: ${domain.id}`);
  }
  if (domain.status === "migrated" && domain.e2eFeatureIds.length === 0) {
    errors.push(`migrated domain has no E2E evidence IDs: ${domain.id}`);
  }
  return {
    ...domain,
    matchers: domain.patterns.map((pattern) => new RegExp(pattern)),
    matched: [],
  };
});

for (const file of trackedFiles) {
  const domain = compiledDomains.find((candidate) =>
    candidate.matchers.some((matcher) => matcher.test(file)),
  );
  if (!domain) {
    errors.push(`legacy file is not classified: ${file}`);
  } else {
    domain.matched.push(file);
  }
}

for (const domain of compiledDomains) {
  if (domain.matched.length === 0) {
    errors.push(`migration domain matches no current file: ${domain.id}`);
  }
}

const featureCatalog = JSON.parse(
  await fs.readFile(path.join(root, manifest.featureCatalogPath), "utf8"),
);
if (featureCatalog.schemaVersion !== 1 || !Array.isArray(featureCatalog.features)) {
  errors.push("invalid cross-platform E2E feature catalog");
}
const featureIds = new Set(
  (featureCatalog.features ?? []).map((feature) => feature.id),
);
if (featureIds.size !== (featureCatalog.features ?? []).length) {
  errors.push("cross-platform E2E feature catalog contains duplicate ids");
}
for (const domain of compiledDomains) {
  for (const featureId of domain.e2eFeatureIds) {
    if (!featureIds.has(featureId)) {
      errors.push(`${domain.id} references an unknown E2E feature: ${featureId}`);
    }
  }
}

const summary = [
  "## Fabushi migration surface",
  "",
  `- Tracked Dart files: ${trackedFiles.length}`,
  `- Surface SHA-256: \`${fingerprint}\``,
  `- Migration domains: ${compiledDomains.length}`,
  "",
  "| Domain | Files | Status | Required for cutover | E2E evidence |",
  "|---|---:|---|---|---|",
  ...compiledDomains.map(
    (domain) =>
      `| ${domain.id} | ${domain.matched.length} | ${domain.status} | ${domain.requiredForCutover ? "yes" : "no"} | ${domain.e2eFeatureIds.join(", ") || "—"} |`,
  ),
  "",
].join("\n");
console.log(summary);

if (process.env.GITHUB_STEP_SUMMARY) {
  await fs.appendFile(process.env.GITHUB_STEP_SUMMARY, summary);
}

if (errors.length > 0) {
  throw new Error(
    [
      "Migration surface contract failed.",
      ...errors.map((error) => `- ${error}`),
      "Update the explicit manifest and its evidence in the same pull request.",
    ].join("\n"),
  );
}
