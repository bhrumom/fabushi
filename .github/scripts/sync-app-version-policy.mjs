#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

function parseArgs(argv) {
  const args = {};
  for (let index = 2; index < argv.length; index += 1) {
    const current = argv[index];
    if (!current.startsWith('--')) continue;
    const key = current.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith('--')) {
      args[key] = 'true';
      continue;
    }
    args[key] = next;
    index += 1;
  }
  return args;
}

function readPubspecVersion(pubspecPath) {
  const content = fs.readFileSync(pubspecPath, 'utf8');
  const match = content.match(/^version:\s*([^+\s]+)\+(\d+)\s*$/m);
  if (!match) {
    throw new Error(`Unable to parse version from ${pubspecPath}`);
  }
  return {
    version: match[1],
    buildNumber: Number.parseInt(match[2], 10),
  };
}

function parseReleaseVersion(value) {
  if (!value) return null;

  const normalizedValue = String(value).trim();
  if (!normalizedValue) return null;

  const tagMatch = normalizedValue.match(/v?(\d+\.\d+\.\d+)-(\d+)-mobile(?:[.-].*)?$/i);
  if (tagMatch) {
    return {
      version: tagMatch[1],
      buildNumber: Number.parseInt(tagMatch[2], 10),
    };
  }

  const titleMatch = normalizedValue.match(/(\d+\.\d+\.\d+)\+(\d+)/);
  if (titleMatch) {
    return {
      version: titleMatch[1],
      buildNumber: Number.parseInt(titleMatch[2], 10),
    };
  }

  return null;
}

function resolveVersionMetadata({ pubspecPath, args }) {
  const releaseCandidates = [
    args.releaseTag,
    process.env.GITHUB_RELEASE_TAG,
    args.title,
    process.env.VERSION_TITLE,
    process.env.GITHUB_RELEASE_TITLE,
    process.env.GITHUB_RELEASE_BODY,
  ];

  for (const candidate of releaseCandidates) {
    const parsed = parseReleaseVersion(candidate);
    if (parsed) {
      return parsed;
    }
  }

  return readPubspecVersion(pubspecPath);
}

function normalizeBoolean(value, fallbackValue) {
  if (value === undefined || value === null || value === '') {
    return fallbackValue;
  }
  const normalized = String(value).trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallbackValue;
}

function normalizeInteger(value) {
  if (value === undefined || value === null || value === '') {
    return undefined;
  }
  const parsed = Number.parseInt(String(value), 10);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Expected integer but received: ${value}`);
  }
  return parsed;
}

function maybeSplitLines(value) {
  if (!value) return undefined;
  return String(value)
    .split(/\r?\n/)
    .map((item) => item.trim())
    .filter(Boolean);
}

async function upsertPolicy({ endpoint, token, payload }) {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Release-Automation-Token': token,
    },
    body: JSON.stringify(payload),
  });

  const text = await response.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch (_) {
    body = text;
  }

  if (!response.ok) {
    throw new Error(`Policy sync failed (${response.status}): ${JSON.stringify(body)}`);
  }

  return body;
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = process.cwd();
  const pubspecPath = path.join(repoRoot, 'fabushi', 'pubspec.yaml');
  const { version, buildNumber } = resolveVersionMetadata({ pubspecPath, args });

  const endpoint =
    args.endpoint ||
    process.env.VERSION_POLICY_ENDPOINT ||
    process.env.APP_VERSION_POLICY_SYNC_URL;
  const token =
    args.token ||
    process.env.VERSION_POLICY_AUTOMATION_TOKEN ||
    process.env.APP_VERSION_POLICY_AUTOMATION_TOKEN;
  if (!endpoint) {
    throw new Error('Missing VERSION_POLICY_ENDPOINT');
  }
  if (!token) {
    throw new Error('Missing VERSION_POLICY_AUTOMATION_TOKEN');
  }

  const channels = (
    args.channels ||
    process.env.VERSION_POLICY_CHANNELS ||
    args.channel ||
    process.env.VERSION_CHANNEL ||
    'stable'
  )
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
  const platforms = (args.platforms || process.env.VERSION_POLICY_PLATFORMS || 'android,ios')
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);

  const releaseNotes = maybeSplitLines(
    args.releaseNotes ||
      process.env.VERSION_RELEASE_NOTES ||
      process.env.GITHUB_RELEASE_BODY,
  );
  const title = args.title || process.env.VERSION_TITLE || process.env.GITHUB_RELEASE_TITLE;
  const message = args.message || process.env.VERSION_MESSAGE;
  const forceUpdate = normalizeBoolean(
    args.forceUpdate || process.env.VERSION_FORCE_UPDATE,
    false,
  );
  const minSupportedBuildNumber = normalizeInteger(
    args.minSupportedBuildNumber || process.env.VERSION_MIN_SUPPORTED_BUILD,
  );
  const rolloutPercentage = normalizeInteger(
    args.rolloutPercentage || process.env.VERSION_ROLLOUT_PERCENTAGE,
  );
  const promptIntervalHours = normalizeInteger(
    args.promptIntervalHours || process.env.VERSION_PROMPT_INTERVAL_HOURS,
  );
  const allowSkip = normalizeBoolean(
    args.allowSkip || process.env.VERSION_ALLOW_SKIP,
    !forceUpdate,
  );
  const source = args.source || process.env.VERSION_SYNC_SOURCE || 'github-actions';
  const publishedAt = args.publishedAt || process.env.VERSION_PUBLISHED_AT;

  const platformUrls = {
    android:
      process.env.APP_DOWNLOAD_URL_ANDROID ||
      process.env.APP_VERSION_DOWNLOAD_URL_ANDROID ||
      '',
    ios:
      process.env.APP_DOWNLOAD_URL_IOS ||
      process.env.APP_VERSION_DOWNLOAD_URL_IOS ||
      '',
    web:
      process.env.APP_DOWNLOAD_URL_WEB ||
      process.env.APP_VERSION_DOWNLOAD_URL_WEB ||
      process.env.FRONTEND_URL ||
      '',
  };

  for (const channel of channels) {
    for (const platform of platforms) {
      const payload = {
        platform,
        channel,
        latestVersion: version,
        latestBuildNumber: buildNumber,
        downloadUrl: platformUrls[platform] || '',
        forceUpdate,
        allowSkip,
        source,
      };

      if (title) payload.title = title;
      if (message) payload.message = message;
      if (publishedAt) payload.publishedAt = publishedAt;
      if (releaseNotes?.length) payload.releaseNotes = releaseNotes;
      if (minSupportedBuildNumber !== undefined) {
        payload.minSupportedBuildNumber = minSupportedBuildNumber;
      }
      if (rolloutPercentage !== undefined) {
        payload.rolloutPercentage = rolloutPercentage;
      }
      if (promptIntervalHours !== undefined) {
        payload.promptIntervalHours = promptIntervalHours;
      }

      const result = await upsertPolicy({ endpoint, token, payload });
      console.log(`Synced ${platform}/${channel} -> ${version}+${buildNumber}`);
      console.log(JSON.stringify(result, null, 2));
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
