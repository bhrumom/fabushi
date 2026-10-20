import { _electron as electron, chromium } from '@playwright/test';
import { createServer } from 'node:http';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const desktopRoot = path.resolve(new URL('..', import.meta.url).pathname);
const config = JSON.parse(await readFile(path.join(desktopRoot, 'e2e/fixtures/avatar-motion-parity.v1.json'), 'utf8'));
const referenceRoot = path.resolve(process.env.GBF509_REFERENCE_ROOT || '');
const executablePath = process.env.FABUSHI_ELECTRON_EXECUTABLE || '';
const evidenceRoot = path.resolve(process.env.GBF509_EVIDENCE_DIR || path.join(desktopRoot, 'test-results/gbf-509-motion-parity'));
const sourceSha = String(process.env.GBF509_SOURCE_SHA || '').trim().toLowerCase();
const referenceSha = String(process.env.GBF509_REFERENCE_SHA || '').trim().toLowerCase();

if (!executablePath) throw new Error('FABUSHI_ELECTRON_EXECUTABLE is required');
if (!process.env.GBF509_REFERENCE_ROOT) throw new Error('GBF509_REFERENCE_ROOT is required');
if (!/^[0-9a-f]{40}$/.test(sourceSha)) throw new Error('GBF509_SOURCE_SHA must be exact');
if (referenceSha !== config.frozenReference.commit) throw new Error('Reference SHA does not match frozen v1 contract');

for (const dir of [
  evidenceRoot,
  path.join(evidenceRoot, 'frames/reference'),
  path.join(evidenceRoot, 'frames/fabushi'),
  path.join(evidenceRoot, 'comparisons'),
  path.join(evidenceRoot, 'video/reference-raw'),
  path.join(evidenceRoot, 'video/fabushi-raw'),
  path.join(evidenceRoot, 'trace'),
]) await mkdir(dir, { recursive: true });

const harnessHtml = [
  '<!doctype html><meta charset="utf-8">',
  '<style>html,body{margin:0;width:640px;height:480px;overflow:hidden;background:#f3efe6}body{display:grid;place-items:center}#stage{width:64px;height:64px;display:grid;place-items:center}#ref-avatar{width:64px;height:64px;overflow:visible;--fg:#111;--bg:#f3efe6;color-scheme:light}</style>',
  '<div id="stage"><svg id="ref-avatar"></svg></div>',
  '<script src="/replica/geometry-data.js"><' + '/script>',
  '<script src="/replica/src/math.js"><' + '/script>',
  '<script src="/replica/src/tables.js"><' + '/script>',
  '<script src="/replica/src/pose.js"><' + '/script>',
  '<script src="/replica/src/tricks.js"><' + '/script>',
  '<script src="/replica/src/fx.js"><' + '/script>',
  '<script src="/replica/src/eyes.js"><' + '/script>',
  '<script src="/replica/src/character.js"><' + '/script>',
  '<script>window.__gbf509ResetRandom=function(seed){let value=seed>>>0;Math.random=function(){value=(value+0x6D2B79F5)>>>0;let t=value;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);return((t^(t>>>14))>>>0)/4294967296;};};window.__gbf509Ready=true;<' + '/script>',
].join('');

function mediaType(filePath) {
  if (filePath.endsWith('.js')) return 'text/javascript; charset=utf-8';
  if (filePath.endsWith('.html')) return 'text/html; charset=utf-8';
  if (filePath.endsWith('.png')) return 'image/png';
  return 'application/octet-stream';
}

const server = createServer(async (request, response) => {
  try {
    const pathname = new URL(request.url || '/', 'http://127.0.0.1').pathname;
    if (pathname === '/__gbf509') {
      response.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
      response.end(harnessHtml);
      return;
    }
    const target = path.resolve(referenceRoot, '.' + decodeURIComponent(pathname));
    if (!(target === referenceRoot || target.startsWith(referenceRoot + path.sep))) {
      response.writeHead(403); response.end('forbidden'); return;
    }
    response.writeHead(200, { 'content-type': mediaType(target), 'cache-control': 'no-store' });
    response.end(await readFile(target));
  } catch (error) {
    response.writeHead(404); response.end(String(error));
  }
});
await new Promise((resolve, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolve);
});
const address = server.address();
if (!address || typeof address === 'string') throw new Error('Reference server did not bind');
const referenceUrl = 'http://127.0.0.1:' + address.port + '/__gbf509';

const logs = [];
const launchEnv = Object.fromEntries(Object.entries(process.env).filter(([, value]) => typeof value === 'string'));
launchEnv.FABUSHI_AVATAR_MOTION_PARITY = '1';
launchEnv.FABUSHI_APP_DATA = path.join(evidenceRoot, 'app-data');
delete launchEnv.FABUSHI_FEATURE_HOST_MODE;
delete launchEnv.FABUSHI_E2E;

const browser = await chromium.launch({ headless: true });
const refContext = await browser.newContext({
  viewport: config.capture.viewport,
  reducedMotion: 'no-preference',
  recordVideo: { dir: path.join(evidenceRoot, 'video/reference-raw'), size: config.capture.viewport },
});
await refContext.tracing.start({ screenshots: true, snapshots: true, sources: true });
const refVideoStartedAt = Date.now();
const refPage = await refContext.newPage();
refPage.on('console', (m) => logs.push({ side: 'reference', kind: 'console', at: Date.now(), text: m.text() }));
refPage.on('pageerror', (e) => logs.push({ side: 'reference', kind: 'pageerror', at: Date.now(), text: e.stack || e.message }));
await refPage.goto(referenceUrl);
await refPage.waitForFunction(() => window.__gbf509Ready === true);

const fabVideoStartedAt = Date.now();
const app = await electron.launch({
  executablePath,
  env: launchEnv,
  recordVideo: { dir: path.join(evidenceRoot, 'video/fabushi-raw'), size: config.capture.viewport },
});
const fabPage = await app.firstWindow();
fabPage.on('console', (m) => logs.push({ side: 'fabushi', kind: 'console', at: Date.now(), text: m.text() }));
fabPage.on('pageerror', (e) => logs.push({ side: 'fabushi', kind: 'pageerror', at: Date.now(), text: e.stack || e.message }));
const child = app.process();
child.stdout?.on('data', (chunk) => logs.push({ side: 'fabushi', kind: 'stdout', at: Date.now(), text: String(chunk) }));
child.stderr?.on('data', (chunk) => logs.push({ side: 'fabushi', kind: 'stderr', at: Date.now(), text: String(chunk) }));
await app.evaluate(({ BrowserWindow }) => {
  const win = BrowserWindow.getAllWindows()[0];
  if (!win) throw new Error('Fabushi parity window missing');
  win.setContentSize(640, 480, false);
});
await fabPage.emulateMedia({ reducedMotion: 'no-preference' });
await fabPage.waitForSelector('[data-testid="avatar-motion-parity-harness"]');
await fabPage.context().tracing.start({ screenshots: true, snapshots: true, sources: true });

const comparisonContext = await browser.newContext({ viewport: { width: 128, height: 64 } });
const comparisonPage = await comparisonContext.newPage();
const refVideo = refPage.video();
const fabVideo = fabPage.video();
await new Promise((resolve) => setTimeout(resolve, config.capture.warmupMs));

function seedFor(index) { return (config.capture.referenceRandomSeed + index * 7919) >>> 0; }

async function configureReference(scenario, index) {
  await refPage.evaluate(({ scenario, seed }) => {
    window.__refChar?.destroy?.();
    window.__gbf509ResetRandom(seed);
    const svg = document.getElementById('ref-avatar');
    svg.innerHTML = '';
    const c = new window.GrokCharacter(svg, {
      mode: 'hold', state: scenario.state, shape: 'blob', color: 'black', scheme: 'light',
      loginWrap: true, sizePx: 64, followPointer: scenario.id === 'pointer-gaze',
      reduceMotion: false, paused: false, emphasis: false,
    });
    c.trickAt = Infinity; c.celebrateAt = -1; c.winkUntil = Infinity; c.eyeUntil = Infinity; c.gazeUntil = Infinity;
    c.ctx.nodUntil = scenario.referenceOverrides?.nodAtMs == null ? Infinity : c.stateAt + Number(scenario.referenceOverrides.nodAtMs);
    window.__refChar = c;
  }, { scenario, seed: seedFor(index) });
}

async function configureFabushi(scenario) {
  const generation = await fabPage.evaluate((scenario) => window.__fabushiAvatarParity.configure({
    identity: scenario.identity, state: scenario.state, followPointer: scenario.id === 'pointer-gaze',
  }), scenario);
  await fabPage.waitForFunction((g) => document.querySelector('[data-testid="avatar-motion-parity-harness"]')?.getAttribute('data-generation') === String(g), generation);
  await fabPage.waitForFunction(() => Boolean(document.querySelector('svg[data-fabushi-avatar-runtime]')?.dataset.motionBodyY));
}

async function movePointer(page, selector, x, y) {
  const box = await page.locator(selector).boundingBox();
  if (!box) throw new Error('Avatar box missing');
  await page.mouse.move(box.x + box.width / 2 + x * box.width / 2, box.y + box.height / 2 + y * box.height / 2);
}

async function applyEvent(event) {
  if (event.type === 'gaze') {
    await Promise.all([
      movePointer(refPage, '#ref-avatar', Number(event.x), Number(event.y)),
      movePointer(fabPage, 'svg[data-fabushi-avatar-runtime]', Number(event.x), Number(event.y)),
    ]);
  } else if (event.type === 'state') {
    await Promise.all([
      refPage.evaluate((state) => {
        const c = window.__refChar;
        c.setState(state, { resetEyes: false });
        c.trickAt = Infinity; c.winkUntil = Infinity; c.eyeUntil = Infinity; c.gazeUntil = Infinity; c.ctx.nodUntil = Infinity;
      }, event.state),
      fabPage.evaluate((state) => window.__fabushiAvatarParity.setState(state), event.state),
    ]);
  } else if (event.type === 'spin') {
    await Promise.all([
      refPage.evaluate((turns) => window.__refChar.spinOnce(turns), Number(event.turns || 1)),
      fabPage.evaluate((turns) => window.__fabushiAvatarParity.spin(turns), Number(event.turns || 1)),
    ]);
  } else if (event.type === 'bounce') {
    await Promise.all([refPage.evaluate(() => window.__refChar.bounceOnce()), fabPage.evaluate(() => window.__fabushiAvatarParity.bounce())]);
  } else if (event.type === 'burst') {
    await Promise.all([refPage.evaluate(() => window.__refChar.burstOnce()), fabPage.evaluate(() => window.__fabushiAvatarParity.burst())]);
  }
}

async function referenceSnapshot() {
  return refPage.evaluate(() => {
    const c = window.__refChar;
    const ex = c.extras || {};
    const width = c.svg.viewBox.baseVal.width || 259;
    const eyes = c.eyeEls.map((eye) => eye.getBoundingClientRect());
    return {
      state: c.state,
      bodyY: (c.ty.x + Number(ex.hop || 0) + Number(ex.ki || 0)) * 64 / width,
      roll: c.spin.x + Number(ex.Kr || 0) + Number(ex.Yr || 0),
      spin: ex.turn == null ? 0 : Number(ex.turn) * 180 / Math.PI,
      squash: c.squash.x,
      gazeX: c.followPointer ? c.pointer.x / 22 : c.gazeX.x / 15,
      gazeY: c.followPointer ? c.pointer.y / 14 : c.gazeY.x / 9,
      leftEyePx: eyes[0]?.height || 0,
      rightEyePx: eyes[1]?.height || 0,
    };
  });
}

async function fabushiSnapshot() {
  return fabPage.evaluate(() => {
    const raw = window.__fabushiAvatarParity.snapshot();
    const svg = document.querySelector('svg[data-fabushi-avatar-runtime]');
    const eyes = [...svg.querySelectorAll('ellipse')].map((eye) => eye.getBoundingClientRect());
    return {
      state: raw.state,
      bodyY: Number(raw.bodyY) * 64 / 260,
      roll: Number(raw.roll),
      spin: Number(raw.spin),
      squash: Number(raw.squash),
      gazeX: Number(raw.gazeX),
      gazeY: Number(raw.gazeY),
      leftEyePx: eyes[0]?.height || 0,
      rightEyePx: eyes[1]?.height || 0,
      burst: Number(raw.burst),
    };
  });
}

async function capturePair(id, index) {
  const [reference, fabushi] = await Promise.all([
    refPage.locator('#ref-avatar').screenshot(),
    fabPage.locator('svg[data-fabushi-avatar-runtime]').screenshot(),
  ]);
  const name = id + '-' + String(index).padStart(4, '0') + '.png';
  await Promise.all([
    writeFile(path.join(evidenceRoot, 'frames/reference', name), reference),
    writeFile(path.join(evidenceRoot, 'frames/fabushi', name), fabushi),
  ]);
  return { reference, fabushi };
}

async function comparison(id, label, pair) {
  const ref = 'data:image/png;base64,' + pair.reference.toString('base64');
  const fab = 'data:image/png;base64,' + pair.fabushi.toString('base64');
  await comparisonPage.setViewportSize({ width: 128, height: 64 });
  await comparisonPage.setContent('<style>html,body{margin:0;width:128px;height:64px;background:#f3efe6;display:flex}img{width:64px;height:64px}</style><img src="' + ref + '"><img src="' + fab + '">');
  await comparisonPage.screenshot({ path: path.join(evidenceRoot, 'comparisons', id + '-' + label + '-side-by-side.png') });
  await comparisonPage.setViewportSize({ width: 64, height: 64 });
  await comparisonPage.setContent('<style>html,body{margin:0;width:64px;height:64px;background:#f3efe6}img{position:absolute;inset:0;width:64px;height:64px}img:last-child{opacity:.5}</style><img src="' + ref + '"><img src="' + fab + '">');
  await comparisonPage.screenshot({ path: path.join(evidenceRoot, 'comparisons', id + '-' + label + '-overlay.png') });
}

async function motionEnergy(buffers) {
  const encoded = buffers.map((b) => b.toString('base64'));
  return comparisonPage.evaluate(async (frames) => {
    const canvas = document.createElement('canvas'); canvas.width = 64; canvas.height = 64;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    const pixels = async (base64) => {
      const image = new Image(); image.src = 'data:image/png;base64,' + base64; await image.decode();
      ctx.clearRect(0, 0, 64, 64); ctx.drawImage(image, 0, 0, 64, 64);
      return ctx.getImageData(0, 0, 64, 64).data;
    };
    if (frames.length < 2) return [];
    const out = []; let previous = await pixels(frames[0]);
    for (let i = 1; i < frames.length; i += 1) {
      const current = await pixels(frames[i]); let sum = 0;
      for (let p = 0; p < current.length; p += 4) {
        sum += Math.abs(current[p] - previous[p]) + Math.abs(current[p + 1] - previous[p + 1]) + Math.abs(current[p + 2] - previous[p + 2]);
      }
      out.push(sum / (64 * 64 * 3 * 255)); previous = current;
    }
    return out;
  }, encoded);
}

const capture = {};
const sampleIntervalMs = 1000 / config.capture.sampleHz;

for (let scenarioIndex = 0; scenarioIndex < config.scenarios.length; scenarioIndex += 1) {
  const scenario = config.scenarios[scenarioIndex];
  await Promise.all([configureReference(scenario, scenarioIndex), configureFabushi(scenario)]);
  await new Promise((resolve) => setTimeout(resolve, 80));
  const reference = [], fabushi = [], frames = [];
  const events = [...scenario.events].sort((a, b) => a.atMs - b.atMs);
  let eventIndex = 0, winkDone = false, hopDone = false, nodStopped = false;
  const count = Math.floor(scenario.durationMs / sampleIntervalMs) + 1;
  const start = Date.now();
  const action = ['spin', 'bounce', 'burst'].includes(scenario.id);
  const frameEvery = action ? 3 : 6;

  for (let i = 0; i < count; i += 1) {
    const t = i * sampleIntervalMs;
    const wait = start + t - Date.now();
    if (wait > 0) await new Promise((resolve) => setTimeout(resolve, wait));
    while (eventIndex < events.length && Number(events[eventIndex].atMs) <= t + 0.5) await applyEvent(events[eventIndex++]);

    const winkAt = Number(scenario.referenceOverrides?.winkAtMs ?? -1);
    if (!winkDone && winkAt >= 0 && t >= winkAt) {
      await refPage.evaluate((eye) => {
        const c = window.__refChar; c.winkAt = performance.now(); c.winkEye = Number(eye); c.winkUntil = Infinity;
      }, Number(scenario.referenceOverrides?.winkEye ?? 0));
      winkDone = true;
    }
    const hopAt = Number(scenario.referenceOverrides?.hopAtMs ?? -1);
    if (!hopDone && hopAt >= 0 && t >= hopAt) {
      await refPage.evaluate(() => window.__refChar.bounceOnce());
      hopDone = true;
    }

    const nodAt = Number(scenario.referenceOverrides?.nodAtMs ?? -1);
    if (!nodStopped && nodAt >= 0 && t >= nodAt + 520) {
      await refPage.evaluate(() => { window.__refChar.ctx.nodUntil = Infinity; }); nodStopped = true;
    }

    const [ref, fab] = await Promise.all([referenceSnapshot(), fabushiSnapshot()]);
    reference.push({ t, actualMs: Date.now() - start, ...ref });
    fabushi.push({ t, actualMs: Date.now() - start, ...fab });
    if (i % frameEvery === 0 || i === count - 1) frames.push(await capturePair(scenario.id, frames.length));
  }

  if (frames.length) {
    await comparison(scenario.id, 'start', frames[0]);
    await comparison(scenario.id, 'middle', frames[Math.floor(frames.length / 2)]);
    await comparison(scenario.id, 'end', frames[frames.length - 1]);
  }
  capture[scenario.id] = {
    reference,
    fabushi,
    wallStartedAt: start,
    wallDurationMs: Date.now() - start,
    frameIntervalMs: frameEvery * sampleIntervalMs,
    referenceEnergy: action ? await motionEnergy(frames.map((f) => f.reference)) : [],
    fabushiEnergy: action ? await motionEnergy(frames.map((f) => f.fabushi)) : [],
  };
  await writeFile(path.join(evidenceRoot, scenario.id + '-reference-metrics.json'), JSON.stringify(reference, null, 2) + '\n');
  await writeFile(path.join(evidenceRoot, scenario.id + '-fabushi-metrics.json'), JSON.stringify(fabushi, null, 2) + '\n');
}

await writeFile(path.join(evidenceRoot, 'raw-motion-capture.json'), JSON.stringify({
  sourceSha,
  referenceSha,
  videoTiming: { refVideoStartedAt, fabVideoStartedAt },
  capture,
}, null, 2) + '\n');
await writeFile(path.join(evidenceRoot, 'runtime-logs.json'), JSON.stringify(logs, null, 2) + '\n');
await refContext.tracing.stop({ path: path.join(evidenceRoot, 'trace/reference-trace.zip') });
await fabPage.context().tracing.stop({ path: path.join(evidenceRoot, 'trace/fabushi-trace.zip') });

await refContext.close();
await app.close();
if (refVideo) await writeFile(path.join(evidenceRoot, 'video/reference.webm'), await readFile(await refVideo.path()));
if (fabVideo) await writeFile(path.join(evidenceRoot, 'video/fabushi.webm'), await readFile(await fabVideo.path()));
await comparisonContext.close();
await browser.close();
await new Promise((resolve) => server.close(resolve));

const digestFiles = ['raw-motion-capture.json', 'runtime-logs.json', 'trace/reference-trace.zip', 'trace/fabushi-trace.zip', 'video/reference.webm', 'video/fabushi.webm'];
const digests = [];
for (const file of digestFiles) {
  const bytes = await readFile(path.join(evidenceRoot, file));
  digests.push({ path: file, sha256: createHash('sha256').update(bytes).digest('hex'), bytes: bytes.length });
}
await writeFile(path.join(evidenceRoot, 'artifact-digests.json'), JSON.stringify({ sourceSha, referenceSha, files: digests }, null, 2) + '\n');
console.log('GBF-509 capture complete for ' + sourceSha + ' against ' + referenceSha);
