import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import express from 'express';

import {
  extractDouyinAwemeId,
  resolveDouyinVideo,
  selectCleanVideoUrl,
} from '../src/douyin_downloader.js';
import { createMiniAppMarketplaceRouter } from '../src/miniapp_marketplace_http.js';

const AWEME_ID = '7491613333141900602';

function detailPayload(id = AWEME_ID) {
  return {
    aweme_detail: {
      aweme_id: id,
      desc: '测试作品 / clean source',
      author: { nickname: '测试作者' },
      video: {
        duration: 12888,
        cover: { url_list: ['https://p3-sign.douyinpic.com/cover.jpeg'] },
        play_addr: { url_list: ['https://v3-dy-o-abtest.zjcdn.com/base.mp4'] },
        download_addr: { url_list: ['https://v3-dy-o-abtest.zjcdn.com/watermarked.mp4'] },
        bit_rate: [
          { bit_rate: 1000, play_addr: { url_list: ['https://v9-dy-o-abtest.douyinvod.com/low.mp4'] } },
          { bit_rate: 3000, play_addr: { url_list: ['https://v9-dy-o-abtest.douyinvod.com/high.mp4'] } },
        ],
      },
    },
  };
}

function makeFetch() {
  return async (input) => {
    const url = String(input);
    if (url.includes('/aweme/v1/web/aweme/detail/')) {
      return new Response(JSON.stringify(detailPayload()), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    }
    if (url.startsWith('https://v.douyin.com/')) {
      return new Response('', {
        status: 302,
        headers: { location: `https://www.douyin.com/video/${AWEME_ID}` },
      });
    }
    if (url === `https://www.douyin.com/video/${AWEME_ID}`) {
      return new Response('<html></html>', { status: 200 });
    }
    throw new Error(`unexpected fetch ${url}`);
  };
}

async function withServer(run) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'fabushi-douyin-miniapp-'));
  const app = express();
  const { router } = createMiniAppMarketplaceRouter({
    storagePath: path.join(root, 'marketplace.json'),
    douyinFetchImpl: makeFetch(),
  });
  app.use(router);
  const server = await new Promise((resolve) => {
    const listener = app.listen(0, '127.0.0.1', () => resolve(listener));
  });
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  try {
    await run(baseUrl);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    fs.rmSync(root, { recursive: true, force: true });
  }
}

async function readJson(response) {
  const payload = await response.json();
  assert.ok(response.ok, JSON.stringify(payload));
  return payload;
}

test('extractDouyinAwemeId supports jingxuan modal, canonical video URL and numeric id', () => {
  assert.equal(extractDouyinAwemeId(`https://www.douyin.com/jingxuan?modal_id=${AWEME_ID}`), AWEME_ID);
  assert.equal(extractDouyinAwemeId(`https://www.douyin.com/video/${AWEME_ID}`), AWEME_ID);
  assert.equal(extractDouyinAwemeId(AWEME_ID), AWEME_ID);
});

test('selectCleanVideoUrl chooses highest bitrate play_addr and never download_addr', () => {
  const aweme = detailPayload().aweme_detail;
  assert.equal(selectCleanVideoUrl(aweme), 'https://v9-dy-o-abtest.douyinvod.com/high.mp4');
  assert.notEqual(selectCleanVideoUrl(aweme), aweme.video.download_addr.url_list[0]);
});

test('resolveDouyinVideo follows a public short link and returns proxied clean play_addr', async () => {
  const resolved = await resolveDouyinVideo('复制这条链接 https://v.douyin.com/test123/ 打开抖音', {
    fetchImpl: makeFetch(),
    baseUrl: 'https://api.example.test',
  });
  assert.equal(resolved.awemeId, AWEME_ID);
  assert.equal(resolved.streamType, 'play_addr');
  assert.equal(resolved.watermarkProcessing, false);
  assert.equal(resolved.mediaUrl, 'https://v9-dy-o-abtest.douyinvod.com/high.mp4');
  assert.match(resolved.downloadUrl, /\/v1\/miniapps\/douyin-batch-downloader\/media\?/);
});

test('market lists the official downloader and batch endpoint preserves per-item results', async () => {
  await withServer(async (baseUrl) => {
    const headers = { 'content-type': 'application/json', 'x-fabushi-device-id': 'douyin-test-device' };
    const market = await readJson(await fetch(`${baseUrl}/v1/marketplace/plugins?q=%E6%8A%96%E9%9F%B3&platform=desktop`, { headers }));
    const downloader = market.plugins.find((plugin) => plugin.pluginId === 'douyin-batch-downloader');
    assert.ok(downloader);
    assert.equal(downloader.releaseStatus, 'approved');

    const batch = await readJson(await fetch(`${baseUrl}/v1/miniapps/douyin-batch-downloader/batch`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        items: [
          `https://www.douyin.com/jingxuan?modal_id=${AWEME_ID}`,
          'not-a-douyin-url',
        ],
      }),
    }));
    assert.equal(batch.count, 2);
    assert.equal(batch.results[0].ok, true);
    assert.equal(batch.results[0].value.awemeId, AWEME_ID);
    assert.equal(batch.results[1].ok, false);
    assert.equal(batch.results[1].error.code, 'INVALID_DOUYIN_URL');
  });
});
