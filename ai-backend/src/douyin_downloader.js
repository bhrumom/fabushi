import { Readable } from 'node:stream';

import express from 'express';

import { MiniAppMarketplaceError, normalizeMiniAppManifest } from './miniapp_marketplace.js';
import { publicBaseUrl, route } from './miniapp_marketplace_server_common.js';

const DOUYIN_HOST_SUFFIXES = ['douyin.com', 'iesdouyin.com'];
const MEDIA_HOST_SUFFIXES = [
  'douyinvod.com',
  'douyinpic.com',
  'bytecdn.cn',
  'bytedance.com',
  'snssdk.com',
  'douyin.com',
];
const DEFAULT_USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36';
const MAX_BATCH_ITEMS = 50;
const MAX_REDIRECTS = 6;

export const DOUYIN_DOWNLOADER_ID = 'douyin-batch-downloader';

function hostMatches(hostname, suffixes) {
  const host = String(hostname ?? '').trim().toLocaleLowerCase();
  return suffixes.some((suffix) => host === suffix || host.endsWith(`.${suffix}`));
}

function firstUrl(value) {
  const text = String(value ?? '').trim();
  const match = text.match(/https?:\/\/[^\s<>"']+/i);
  if (!match) return null;
  return match[0].replace(/[，。；;、）)\]}]+$/u, '');
}

export function extractDouyinAwemeId(value) {
  const text = String(value ?? '').trim();
  if (/^\d{10,24}$/.test(text)) return text;
  const candidate = firstUrl(text) ?? text;
  let parsed;
  try {
    parsed = new URL(candidate);
  } catch {
    const direct = text.match(/(?:video|note)\/(\d{10,24})/i);
    return direct?.[1] ?? null;
  }
  const queryId = parsed.searchParams.get('modal_id') ?? parsed.searchParams.get('aweme_id');
  if (queryId && /^\d{10,24}$/.test(queryId)) return queryId;
  const pathId = parsed.pathname.match(/\/(?:video|note)\/(\d{10,24})(?:\/|$)/i);
  return pathId?.[1] ?? null;
}

function normalizeDouyinInput(value) {
  const input = String(value ?? '').trim();
  if (!input) throw new MiniAppMarketplaceError('INVALID_DOUYIN_URL', '请输入抖音分享链接或作品 ID');
  if (/^\d{10,24}$/.test(input)) return { input, url: null, awemeId: input };
  const rawUrl = firstUrl(input);
  if (!rawUrl) throw new MiniAppMarketplaceError('INVALID_DOUYIN_URL', '没有找到可识别的抖音链接');
  const parsed = new URL(rawUrl);
  if (!hostMatches(parsed.hostname, DOUYIN_HOST_SUFFIXES)) {
    throw new MiniAppMarketplaceError('INVALID_DOUYIN_URL', '仅支持 douyin.com / iesdouyin.com 公开作品链接');
  }
  return { input, url: parsed.toString(), awemeId: extractDouyinAwemeId(parsed.toString()) };
}

async function followDouyinRedirects(url, fetchImpl) {
  let current = url;
  for (let index = 0; index <= MAX_REDIRECTS; index += 1) {
    const parsed = new URL(current);
    if (!hostMatches(parsed.hostname, DOUYIN_HOST_SUFFIXES)) {
      throw new MiniAppMarketplaceError('UNSAFE_REDIRECT', '抖音链接跳转到了不受信任的域名');
    }
    const response = await fetchImpl(current, {
      redirect: 'manual',
      headers: { 'user-agent': DEFAULT_USER_AGENT, accept: 'text/html,application/xhtml+xml' },
    });
    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get('location');
      if (!location) break;
      current = new URL(location, current).toString();
      continue;
    }
    return { url: response.url || current, response };
  }
  return { url: current, response: null };
}

function walkForAweme(node, awemeId, seen = new Set()) {
  if (!node || typeof node !== 'object' || seen.has(node)) return null;
  seen.add(node);
  if (!Array.isArray(node)) {
    const id = String(node.aweme_id ?? node.awemeId ?? node.item_id ?? node.itemId ?? '');
    if ((id === String(awemeId) || !id) && node.video && typeof node.video === 'object') return node;
    const detail = node.aweme_detail ?? node.awemeDetail;
    if (detail && typeof detail === 'object') {
      const found = walkForAweme(detail, awemeId, seen);
      if (found) return found;
    }
    if (Array.isArray(node.item_list)) {
      const exact = node.item_list.find((item) => String(item?.aweme_id ?? '') === String(awemeId));
      if (exact?.video) return exact;
      if (node.item_list[0]?.video) return node.item_list[0];
    }
  }
  for (const value of Object.values(node)) {
    const found = walkForAweme(value, awemeId, seen);
    if (found) return found;
  }
  return null;
}

function parseSharePage(html, awemeId) {
  const text = String(html ?? '');
  const renderData = text.match(/<script[^>]+id=["']RENDER_DATA["'][^>]*>([\s\S]*?)<\/script>/i)?.[1];
  if (renderData) {
    try {
      const parsed = JSON.parse(decodeURIComponent(renderData));
      const found = walkForAweme(parsed, awemeId);
      if (found) return found;
    } catch {
      // Fall through to the router-data representation.
    }
  }
  const routerData = text.match(/window\._ROUTER_DATA\s*=\s*(\{[\s\S]*?\})\s*<\/script>/i)?.[1];
  if (routerData) {
    try {
      const found = walkForAweme(JSON.parse(routerData), awemeId);
      if (found) return found;
    } catch {
      // The page shape changes frequently; callers receive a stable parse error below.
    }
  }
  return null;
}

function urlsFromAddress(address) {
  return Array.isArray(address?.url_list)
    ? address.url_list.filter((url) => typeof url === 'string' && /^https?:\/\//i.test(url))
    : [];
}

export function selectCleanVideoUrl(aweme) {
  const video = aweme?.video;
  if (!video || typeof video !== 'object') return null;
  const bitrateCandidates = Array.isArray(video.bit_rate)
    ? [...video.bit_rate]
      .sort((left, right) => Number(right?.bit_rate ?? 0) - Number(left?.bit_rate ?? 0))
      .flatMap((entry) => urlsFromAddress(entry?.play_addr))
    : [];
  const playCandidates = urlsFromAddress(video.play_addr);
  return [...bitrateCandidates, ...playCandidates][0] ?? null;
}

function cleanTitle(value, awemeId) {
  const text = String(value ?? '').trim().replace(/[\\/:*?"<>|\u0000-\u001f]+/g, ' ').replace(/\s+/g, ' ');
  return (text || `douyin-${awemeId}`).slice(0, 80);
}

async function fetchAwemeDetail(awemeId, fetchImpl) {
  const detailUrl = new URL('https://www.douyin.com/aweme/v1/web/aweme/detail/');
  detailUrl.searchParams.set('aweme_id', awemeId);
  detailUrl.searchParams.set('device_platform', 'webapp');
  detailUrl.searchParams.set('aid', '6383');
  try {
    const response = await fetchImpl(detailUrl, {
      headers: {
        'user-agent': DEFAULT_USER_AGENT,
        accept: 'application/json,text/plain,*/*',
        referer: `https://www.douyin.com/video/${awemeId}`,
      },
    });
    if (response.ok) {
      const payload = await response.json();
      const found = walkForAweme(payload, awemeId);
      if (found?.video) return found;
    }
  } catch {
    // Use the public share-page fallback below.
  }

  const shareResponse = await fetchImpl(`https://www.iesdouyin.com/share/video/${awemeId}/`, {
    headers: { 'user-agent': DEFAULT_USER_AGENT, accept: 'text/html,application/xhtml+xml' },
  });
  if (!shareResponse.ok) {
    throw new MiniAppMarketplaceError('DOUYIN_FETCH_FAILED', `抖音作品读取失败 (${shareResponse.status})`);
  }
  const aweme = parseSharePage(await shareResponse.text(), awemeId);
  if (!aweme?.video) throw new MiniAppMarketplaceError('DOUYIN_PARSE_FAILED', '当前公开页面没有返回可解析的视频播放源');
  return aweme;
}

export async function resolveDouyinVideo(value, { fetchImpl = globalThis.fetch, baseUrl = '' } = {}) {
  if (typeof fetchImpl !== 'function') throw new Error('fetch implementation is required');
  const normalized = normalizeDouyinInput(value);
  let awemeId = normalized.awemeId;
  let resolvedUrl = normalized.url;
  if (!awemeId && normalized.url) {
    const followed = await followDouyinRedirects(normalized.url, fetchImpl);
    resolvedUrl = followed.url;
    awemeId = extractDouyinAwemeId(resolvedUrl);
    if (!awemeId && followed.response?.ok) {
      const html = await followed.response.text();
      awemeId = html.match(/(?:aweme_id|itemId)["':=\s]+(\d{10,24})/i)?.[1] ?? null;
    }
  }
  if (!awemeId) throw new MiniAppMarketplaceError('DOUYIN_ID_NOT_FOUND', '无法从该链接解析作品 ID');

  const aweme = await fetchAwemeDetail(awemeId, fetchImpl);
  const mediaUrl = selectCleanVideoUrl(aweme);
  if (!mediaUrl) throw new MiniAppMarketplaceError('DOUYIN_MEDIA_NOT_FOUND', '作品没有返回公开播放源');
  const title = cleanTitle(aweme.desc, awemeId);
  const cover = urlsFromAddress(aweme.video?.cover)[0] ?? urlsFromAddress(aweme.video?.origin_cover)[0] ?? null;
  const proxy = baseUrl
    ? `${baseUrl}/v1/miniapps/${DOUYIN_DOWNLOADER_ID}/media?url=${encodeURIComponent(mediaUrl)}&filename=${encodeURIComponent(`${title}.mp4`)}`
    : null;
  return {
    awemeId,
    sourceUrl: resolvedUrl ?? `https://www.douyin.com/video/${awemeId}`,
    title,
    author: String(aweme.author?.nickname ?? '').trim() || null,
    cover,
    durationMs: Number(aweme.video?.duration ?? 0) || null,
    mediaUrl,
    downloadUrl: proxy,
    streamType: 'play_addr',
    watermarkProcessing: false,
  };
}

async function mapLimit(items, limit, mapper) {
  const output = new Array(items.length);
  let cursor = 0;
  async function worker() {
    while (cursor < items.length) {
      const index = cursor;
      cursor += 1;
      try {
        output[index] = { ok: true, value: await mapper(items[index], index) };
      } catch (error) {
        output[index] = {
          ok: false,
          error: { code: error?.code ?? 'DOUYIN_RESOLVE_FAILED', message: String(error?.message ?? error) },
        };
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return output;
}

function renderDownloaderUi() {
  return `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>抖音批量下载</title><style>*{box-sizing:border-box}body{margin:0;font-family:system-ui,-apple-system,sans-serif;background:#f5f6f8;color:#111827}.wrap{max-width:980px;margin:0 auto;padding:24px}.card{background:#fff;border:1px solid #e5e7eb;border-radius:18px;padding:20px;box-shadow:0 8px 28px rgba(0,0,0,.05)}h1{font-size:24px;margin:0 0 8px}.sub{color:#6b7280;margin:0 0 18px}textarea{width:100%;min-height:180px;resize:vertical;border:1px solid #d1d5db;border-radius:14px;padding:14px;font:14px ui-monospace,monospace}button,a.btn{border:0;border-radius:12px;padding:10px 15px;background:#111827;color:#fff;text-decoration:none;cursor:pointer;font-weight:600}button.secondary{background:#e5e7eb;color:#111827}.actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:12px}.status{margin-top:14px;color:#4b5563}.result{display:grid;grid-template-columns:84px 1fr auto;gap:12px;align-items:center;padding:14px 0;border-top:1px solid #eee}.result img{width:84px;height:84px;object-fit:cover;border-radius:12px;background:#eee}.title{font-weight:700}.meta{font-size:12px;color:#6b7280;margin-top:4px}.error{color:#b91c1c}.note{margin-top:18px;font-size:12px;color:#6b7280;line-height:1.6}@media(max-width:640px){.result{grid-template-columns:64px 1fr}.result img{width:64px;height:64px}.result>a{grid-column:2}}</style></head><body><main class="wrap"><section class="card"><h1>抖音批量无平台水印下载</h1><p class="sub">每行粘贴一个抖音分享链接，最多 ${MAX_BATCH_ITEMS} 条。系统选择作品公开的播放源（play_addr），不会对画面做裁切、遮挡或重编码去水印。</p><textarea id="input" placeholder="https://www.douyin.com/jingxuan?modal_id=...\nhttps://v.douyin.com/...\n..."></textarea><div class="actions"><button id="parse">批量解析</button><button id="download" class="secondary" disabled>下载全部成功项</button></div><div id="status" class="status"></div><div id="results"></div><p class="note">请仅下载你拥有、获得授权或法律允许保存的内容。该小程序不绕过 DRM、付费墙或私密访问控制；抖音公开页面/API 变化时个别作品可能暂时解析失败。</p></section></main><script>const input=document.querySelector('#input'),status=document.querySelector('#status'),results=document.querySelector('#results'),parse=document.querySelector('#parse'),download=document.querySelector('#download');let resolved=[];function esc(s){return String(s??'').replace(/[&<>\"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]))}parse.onclick=async()=>{const items=input.value.split(/\n+/).map(v=>v.trim()).filter(Boolean);if(!items.length){status.textContent='请先粘贴链接';return}parse.disabled=true;download.disabled=true;status.textContent='正在解析 '+items.length+' 条…';results.innerHTML='';try{const r=await fetch('/v1/miniapps/${DOUYIN_DOWNLOADER_ID}/batch',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({items})});const p=await r.json();if(!r.ok)throw new Error(p?.error?.message||'解析失败');resolved=p.results||[];const ok=resolved.filter(x=>x.ok);status.textContent='完成：'+ok.length+' 成功，'+(resolved.length-ok.length)+' 失败';download.disabled=!ok.length;results.innerHTML=resolved.map((x,i)=>x.ok?'<div class="result">'+(x.value.cover?'<img src="'+esc(x.value.cover)+'" alt="">':'<div></div>')+'<div><div class="title">'+esc(x.value.title)+'</div><div class="meta">'+esc(x.value.author||'未知作者')+' · '+esc(x.value.awemeId)+'</div></div><a class="btn" href="'+esc(x.value.downloadUrl)+'">下载</a></div>':'<div class="result"><div></div><div class="error">第 '+(i+1)+' 条：'+esc(x.error?.message||'解析失败')+'</div></div>').join('')}catch(e){status.textContent=e.message}finally{parse.disabled=false}};download.onclick=()=>{const links=resolved.filter(x=>x.ok&&x.value.downloadUrl).map(x=>x.value.downloadUrl);links.forEach((href,i)=>setTimeout(()=>{const a=document.createElement('a');a.href=href;a.download='';document.body.appendChild(a);a.click();a.remove()},i*350))};</script></body></html>`;
}

export function douyinDownloaderManifest() {
  return normalizeMiniAppManifest({
    id: DOUYIN_DOWNLOADER_ID,
    version: '1.0.0',
    title: '抖音批量下载',
    description: '解析抖音公开作品的 clean play_addr，支持最多 50 条批量解析与下载，不对视频画面做二次去水印处理。',
    publisher: { id: 'fabushi-official', displayName: 'Fabushi 官方', verified: true, website: 'https://fabushi.ombhrum.com' },
    categories: ['official', 'utilities', 'media'],
    tags: ['抖音', 'douyin', '批量下载', '无水印', '视频下载'],
    locales: ['zh-cn', 'en'],
    featured: true,
    homepage: `https://api.ombhrum.com/v1/miniapps/${DOUYIN_DOWNLOADER_ID}/ui`,
    bot: {
      id: `${DOUYIN_DOWNLOADER_ID}-bot`,
      username: 'douyin_downloader_bot',
      displayName: '抖音批量下载',
      description: '粘贴抖音公开作品链接，解析公开播放源并批量下载。',
    },
    surfaces: [
      { id: 'web-ui', kind: 'web', title: '批量下载界面', url: `https://api.ombhrum.com/v1/miniapps/${DOUYIN_DOWNLOADER_ID}/ui`, platforms: ['desktop', 'mobile', 'web'], priority: 100 },
    ],
    commands: [
      { name: 'resolve', description: '解析单个抖音公开作品链接', surfaceId: 'web-ui', tool: 'resolve', usage: `/${DOUYIN_DOWNLOADER_ID}:resolve {"url":"https://..."}`, naturalLanguageHints: ['解析抖音链接', '下载这个抖音'] },
      { name: 'batch', description: '批量解析最多 50 条抖音公开作品链接', surfaceId: 'web-ui', tool: 'batch', usage: `/${DOUYIN_DOWNLOADER_ID}:batch {"items":["https://..."]}`, naturalLanguageHints: ['批量下载抖音', '批量解析链接'] },
    ],
    distribution: { installMode: 'metadata', repository: 'https://github.com/bhrumom/fabushi', sourceRef: 'main', license: 'repository-license' },
    permissions: ['network', 'download-files'],
    review: { state: 'approved', reviewer: 'fabushi-release-policy', reviewedAt: Date.now() },
    stats: { monthlyActiveUsers: 0 },
  });
}

export function createDouyinDownloaderRouter({ fetchImpl = globalThis.fetch } = {}) {
  const router = express.Router();

  router.get(`/v1/miniapps/${DOUYIN_DOWNLOADER_ID}/ui`, route(async (_req, res) => {
    res.type('html').set('Cache-Control', 'public, max-age=300').send(renderDownloaderUi());
  }));

  router.post(`/v1/miniapps/${DOUYIN_DOWNLOADER_ID}/resolve`, route(async (req, res) => {
    const value = req.body?.url ?? req.body?.input ?? req.body?.value;
    res.json(await resolveDouyinVideo(value, { fetchImpl, baseUrl: publicBaseUrl(req) }));
  }));

  router.post(`/v1/miniapps/${DOUYIN_DOWNLOADER_ID}/batch`, route(async (req, res) => {
    const items = Array.isArray(req.body?.items) ? req.body.items.map((value) => String(value ?? '').trim()).filter(Boolean) : [];
    if (items.length === 0) throw new MiniAppMarketplaceError('INVALID_BATCH', 'items 必须包含至少一个抖音链接');
    if (items.length > MAX_BATCH_ITEMS) throw new MiniAppMarketplaceError('BATCH_TOO_LARGE', `一次最多解析 ${MAX_BATCH_ITEMS} 条`);
    const baseUrl = publicBaseUrl(req);
    const results = await mapLimit(items, 4, (value) => resolveDouyinVideo(value, { fetchImpl, baseUrl }));
    res.json({ miniAppId: DOUYIN_DOWNLOADER_ID, count: items.length, results });
  }));

  router.get(`/v1/miniapps/${DOUYIN_DOWNLOADER_ID}/media`, route(async (req, res) => {
    const raw = String(req.query.url ?? '').trim();
    let mediaUrl;
    try {
      mediaUrl = new URL(raw);
    } catch {
      throw new MiniAppMarketplaceError('INVALID_MEDIA_URL', '无效的媒体地址');
    }
    if (mediaUrl.protocol !== 'https:' || !hostMatches(mediaUrl.hostname, MEDIA_HOST_SUFFIXES)) {
      throw new MiniAppMarketplaceError('UNSAFE_MEDIA_URL', '媒体地址不属于受信任的抖音/字节 CDN');
    }
    const range = String(req.get('range') ?? '').trim();
    const upstream = await fetchImpl(mediaUrl, {
      headers: {
        'user-agent': DEFAULT_USER_AGENT,
        referer: 'https://www.douyin.com/',
        ...(range ? { range } : {}),
      },
      redirect: 'follow',
    });
    if (!upstream.ok && upstream.status !== 206) {
      throw new MiniAppMarketplaceError('MEDIA_FETCH_FAILED', `媒体下载失败 (${upstream.status})`);
    }
    const filename = cleanTitle(req.query.filename ?? 'douyin-video.mp4', 'video').replace(/\.mp4$/i, '');
    res.status(upstream.status);
    for (const header of ['content-type', 'content-length', 'content-range', 'accept-ranges']) {
      const value = upstream.headers.get(header);
      if (value) res.set(header, value);
    }
    res.set('Content-Disposition', `attachment; filename*=UTF-8''${encodeURIComponent(`${filename}.mp4`)}`);
    res.set('Cache-Control', 'private, max-age=0, no-store');
    if (!upstream.body) return res.end();
    await new Promise((resolve, reject) => {
      Readable.fromWeb(upstream.body).on('error', reject).on('end', resolve).pipe(res);
    });
  }));

  return router;
}
