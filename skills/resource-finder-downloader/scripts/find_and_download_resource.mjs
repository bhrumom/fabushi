#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

function parseArgs(argv) {
  const args = {
    query: '',
    backend: process.env.DACHENG_AI_BACKEND_URL || 'https://api.ombhrum.com',
    limit: 8,
    pick: 1,
    output: process.cwd(),
    jsonOnly: false,
  };

  const positional = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--backend') args.backend = argv[++i];
    else if (arg === '--limit') args.limit = Number(argv[++i] || args.limit);
    else if (arg === '--pick') args.pick = Number(argv[++i] || args.pick);
    else if (arg === '--output') args.output = argv[++i] || args.output;
    else if (arg === '--json-only') args.jsonOnly = true;
    else positional.push(arg);
  }

  args.query = positional.join(' ').trim();
  if (!args.query) {
    throw new Error('Usage: find_and_download_resource.mjs "<query-or-url>" [--output dir]');
  }
  args.backend = args.backend.replace(/\/+$/, '');
  args.limit = Number.isFinite(args.limit) ? Math.max(1, Math.min(args.limit, 20)) : 8;
  args.pick = Number.isFinite(args.pick) ? Math.max(1, args.pick) : 1;
  return args;
}

async function postJson(url, body) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok || data.success === false) {
    throw new Error(data.message || data.error || `Request failed: ${response.status}`);
  }
  return data;
}

function safeFileName(value) {
  return String(value || 'dharma-resource')
    .replace(/[\\/:*?"<>|]+/g, '-')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 90) || 'dharma-resource';
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  await fs.mkdir(args.output, { recursive: true });

  const search = await postJson(`${args.backend}/api/resources/search`, {
    query: args.query,
    limit: args.limit,
  });
  const items = Array.isArray(search.items) ? search.items : [];
  if (items.length === 0) {
    throw new Error('No downloadable resources found.');
  }

  const selected = items[Math.min(args.pick - 1, items.length - 1)];
  const downloaded = await postJson(`${args.backend}/api/resources/download`, selected);
  const baseName = safeFileName(downloaded.fileName || downloaded.title);
  const metadataPath = path.join(args.output, `${baseName}.json`);
  const textPath = path.join(args.output, baseName.endsWith('.txt') ? baseName : `${baseName}.txt`);

  await fs.writeFile(
    metadataPath,
    JSON.stringify({ selected, downloaded, candidates: items }, null, 2),
    'utf8',
  );

  if (!args.jsonOnly) {
    const text = [
      `标题: ${downloaded.title}`,
      `来源: ${downloaded.sourceName}`,
      `链接: ${downloaded.url}`,
      '',
      downloaded.contentText || '',
    ].join('\n');
    await fs.writeFile(textPath, text, 'utf8');
  }

  console.log(
    JSON.stringify(
      {
        ok: true,
        selected,
        metadataPath,
        textPath: args.jsonOnly ? null : textPath,
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  console.error(error.message || String(error));
  process.exit(1);
});
