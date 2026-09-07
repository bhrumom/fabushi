import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const args = new Map(process.argv.slice(2).map((arg) => {
  const [key, value = 'true'] = arg.replace(/^--/, '').split('=');
  return [key, value];
}));
const platform = args.get('platform') || 'all';
const repoRoot = path.resolve(args.get('repo-root') || process.cwd());

const IOS_SIZES = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024];
const ANDROID_DENSITIES = {
  mdpi: { legacy: 48, foreground: 108 },
  hdpi: { legacy: 72, foreground: 162 },
  xhdpi: { legacy: 96, foreground: 216 },
  xxhdpi: { legacy: 144, foreground: 324 },
  xxxhdpi: { legacy: 192, foreground: 432 },
};
const BRAND = {
  top: [103, 226, 172],
  mid: [0, 194, 115],
  bottom: [0, 132, 74],
  eye: [255, 255, 255],
  backgroundTop: [255, 255, 255],
  backgroundBottom: [247, 247, 245],
};

const crcTable = new Uint32Array(256);
for (let n = 0; n < 256; n += 1) {
  let c = n;
  for (let k = 0; k < 8; k += 1) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
  crcTable[n] = c >>> 0;
}

function crc32(buffer) {
  let c = 0xffffffff;
  for (const byte of buffer) c = crcTable[(c ^ byte) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data = Buffer.alloc(0)) {
  const name = Buffer.from(type, 'ascii');
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length, 0);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([name, data])), 0);
  return Buffer.concat([length, name, data, crc]);
}

function encodePng(width, height, rgba, { alpha = false } = {}) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = alpha ? 6 : 2;
  const channels = alpha ? 4 : 3;
  const stride = width * channels;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y += 1) {
    const row = y * (stride + 1);
    raw[row] = 0;
    if (alpha) {
      rgba.copy(raw, row + 1, y * width * 4, (y + 1) * width * 4);
      continue;
    }
    for (let x = 0; x < width; x += 1) {
      const source = (y * width + x) * 4;
      const target = row + 1 + x * 3;
      raw[target] = rgba[source];
      raw[target + 1] = rgba[source + 1];
      raw[target + 2] = rgba[source + 2];
    }
  }
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND'),
  ]);
}

function lerp(a, b, t) { return a + (b - a) * t; }
function mixColor(a, b, t) { return a.map((value, index) => Math.round(lerp(value, b[index], t))); }
function clamp(value, min = 0, max = 1) { return Math.max(min, Math.min(max, value)); }

function ghostInside(x, y, inset) {
  const cx = 0.5;
  const rx = 0.275 * inset;
  const ry = 0.205 * inset;
  const crownY = 0.37;
  const sideLeft = cx - rx;
  const sideRight = cx + rx;
  const top = crownY - ry;
  if (y < top || x < sideLeft || x > sideRight) return false;
  if (y < crownY) {
    const dx = (x - cx) / rx;
    const dy = (y - crownY) / ry;
    return dx * dx + dy * dy <= 1;
  }
  const baseY = 0.68;
  const centers = [0.31, 0.5, 0.69];
  const radius = 0.102 * inset;
  let bottom = baseY;
  for (const center of centers) {
    const dx = x - center;
    if (Math.abs(dx) <= radius) bottom = Math.max(bottom, baseY + Math.sqrt(Math.max(0, radius * radius - dx * dx)));
  }
  return y <= bottom;
}

function roundedRectInside(x, y, cx, cy, width, height, radius) {
  const dx = Math.abs(x - cx) - width / 2 + radius;
  const dy = Math.abs(y - cy) - height / 2 + radius;
  const outsideX = Math.max(dx, 0);
  const outsideY = Math.max(dy, 0);
  return Math.min(Math.max(dx, dy), 0) + Math.hypot(outsideX, outsideY) <= radius;
}

function sampleIcon(nx, ny, transparent, inset = 1) {
  const backgroundT = clamp(ny);
  const background = mixColor(BRAND.backgroundTop, BRAND.backgroundBottom, backgroundT);
  const body = ghostInside(nx, ny, inset);
  const eye = body && (
    roundedRectInside(nx, ny, 0.43, 0.425, 0.057, 0.155, 0.0285) ||
    roundedRectInside(nx, ny, 0.57, 0.425, 0.057, 0.155, 0.0285)
  );
  if (eye) return [...BRAND.eye, 255];
  if (body) {
    const diagonal = clamp((nx + ny - 0.25) / 1.25);
    let color = diagonal < 0.58
      ? mixColor(BRAND.top, BRAND.mid, diagonal / 0.58)
      : mixColor(BRAND.mid, BRAND.bottom, (diagonal - 0.58) / 0.42);
    const shine = clamp((0.62 - Math.hypot(nx - 0.34, ny - 0.26)) / 0.62) * 0.12;
    color = mixColor(color, [255, 255, 255], shine);
    return [...color, 255];
  }
  return transparent ? [0, 0, 0, 0] : [...background, 255];
}

function renderIcon(size, { transparent = false, safeZone = false } = {}) {
  const rgba = Buffer.alloc(size * size * 4);
  const offsets = [[0.25, 0.25], [0.75, 0.25], [0.25, 0.75], [0.75, 0.75]];
  const scale = safeZone ? 0.72 : 1;
  const offset = (1 - scale) / 2;
  for (let y = 0; y < size; y += 1) {
    for (let x = 0; x < size; x += 1) {
      const accum = [0, 0, 0, 0];
      for (const [ox, oy] of offsets) {
        let nx = (x + ox) / size;
        let ny = (y + oy) / size;
        nx = (nx - offset) / scale;
        ny = (ny - offset) / scale;
        const sample = (nx < 0 || nx > 1 || ny < 0 || ny > 1)
          ? (transparent ? [0, 0, 0, 0] : [...mixColor(BRAND.backgroundTop, BRAND.backgroundBottom, clamp((y + oy) / size)), 255])
          : sampleIcon(nx, ny, transparent);
        for (let i = 0; i < 4; i += 1) accum[i] += sample[i];
      }
      const index = (y * size + x) * 4;
      for (let i = 0; i < 4; i += 1) rgba[index + i] = Math.round(accum[i] / offsets.length);
    }
  }
  return encodePng(size, size, rgba, { alpha: transparent });
}

function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
  console.log(`generated ${path.relative(repoRoot, file)}`);
}

function generateDesktop() {
  write(path.join(repoRoot, 'desktop/resources/icon.png'), renderIcon(1024));
}

function generateIos() {
  const dir = path.join(repoRoot, 'mobile/ios/Fabushi/Assets.xcassets/AppIcon.appiconset');
  for (const size of IOS_SIZES) write(path.join(dir, `AppIcon-${size}.png`), renderIcon(size));
}

function generateAndroid() {
  const res = path.join(repoRoot, 'mobile/android/app/src/main/res');
  for (const [density, sizes] of Object.entries(ANDROID_DENSITIES)) {
    const dir = path.join(res, `mipmap-${density}`);
    const legacy = renderIcon(sizes.legacy);
    write(path.join(dir, 'ic_launcher.png'), legacy);
    write(path.join(dir, 'ic_launcher_round.png'), legacy);
    write(path.join(dir, 'ic_launcher_foreground.png'), renderIcon(sizes.foreground, { transparent: true, safeZone: true }));
  }
}

const allowed = new Set(['all', 'desktop', 'ios', 'android']);
if (!allowed.has(platform)) throw new Error(`Unsupported --platform=${platform}`);
if (platform === 'all' || platform === 'desktop') generateDesktop();
if (platform === 'all' || platform === 'ios') generateIos();
if (platform === 'all' || platform === 'android') generateAndroid();
