// Grok Bot 0.16 memory constants/normalization/ranking, with a tiny synchronous SHA-1
// implementation so browser mock mode produces the same 16-character memory IDs.
import type { MemoryRecord } from "../mahayana-host/contracts";
import { clampLine } from "./sand-text";

export const MEMORY_RECENT_PROMPT_LIMIT = 30;
export const MEMORY_RECENT_PROMPT_CHAR_BUDGET = 4000;
export const MEMORY_PROFILE_PROMPT_LIMIT = 100;
export const MEMORY_UI_LIMIT = 1000;
export const MEMORY_MAX_CONTENT_LENGTH = 500;
export const MEMORY_DECAY_HALF_LIFE_DAYS = 30;
export const MEMORY_EPISODE_PREFIX = "[episode] ";
export const MEMORY_NOTE_PREFIX = "[note] ";

const DAY_MS = 24 * 60 * 60 * 1000;

export function normalizeMemoryContent(raw: string): string {
  return clampLine(raw, MEMORY_MAX_CONTENT_LENGTH);
}

export function memoryDedupeKey(content: string): string {
  return normalizeMemoryContent(content).toLowerCase();
}

export function memoryImportance(content: string): number {
  if (content.startsWith(MEMORY_EPISODE_PREFIX)) return 1.5;
  if (content.startsWith(MEMORY_NOTE_PREFIX)) return 0.5;
  return 1;
}

export function memoryRecallRank(memory: MemoryRecord): number {
  return Math.log2(memoryImportance(memory.content)) +
    memory.createdAt / (MEMORY_DECAY_HALF_LIFE_DAYS * DAY_MS);
}

export function formatMemoryDate(createdAtMs: number): string {
  if (!Number.isFinite(createdAtMs) || createdAtMs <= 0) return "unknown date";
  return new Date(createdAtMs).toISOString().slice(0, 10);
}

function utf8Bytes(text: string): number[] {
  return Array.from(new TextEncoder().encode(text));
}

function rotateLeft(value: number, bits: number): number {
  return ((value << bits) | (value >>> (32 - bits))) >>> 0;
}

function sha1Hex(text: string): string {
  const bytes = utf8Bytes(text);
  const bitLength = bytes.length * 8;
  bytes.push(0x80);
  while (bytes.length % 64 !== 56) bytes.push(0);
  const high = Math.floor(bitLength / 0x100000000);
  const low = bitLength >>> 0;
  for (let shift = 24; shift >= 0; shift -= 8) bytes.push((high >>> shift) & 0xff);
  for (let shift = 24; shift >= 0; shift -= 8) bytes.push((low >>> shift) & 0xff);
  let h0 = 0x67452301;
  let h1 = 0xefcdab89;
  let h2 = 0x98badcfe;
  let h3 = 0x10325476;
  let h4 = 0xc3d2e1f0;
  const words = new Uint32Array(80);
  for (let offset = 0; offset < bytes.length; offset += 64) {
    for (let index = 0; index < 16; index += 1) {
      const cursor = offset + index * 4;
      words[index] = (
        (bytes[cursor] << 24) |
        (bytes[cursor + 1] << 16) |
        (bytes[cursor + 2] << 8) |
        bytes[cursor + 3]
      ) >>> 0;
    }
    for (let index = 16; index < 80; index += 1) {
      words[index] = rotateLeft(words[index - 3] ^ words[index - 8] ^ words[index - 14] ^ words[index - 16], 1);
    }
    let a = h0;
    let b = h1;
    let c = h2;
    let d = h3;
    let e = h4;
    for (let index = 0; index < 80; index += 1) {
      let f: number;
      let k: number;
      if (index < 20) {
        f = (b & c) | (~b & d);
        k = 0x5a827999;
      } else if (index < 40) {
        f = b ^ c ^ d;
        k = 0x6ed9eba1;
      } else if (index < 60) {
        f = (b & c) | (b & d) | (c & d);
        k = 0x8f1bbcdc;
      } else {
        f = b ^ c ^ d;
        k = 0xca62c1d6;
      }
      const temp = (rotateLeft(a, 5) + f + e + k + words[index]) >>> 0;
      e = d;
      d = c;
      c = rotateLeft(b, 30);
      b = a;
      a = temp;
    }
    h0 = (h0 + a) >>> 0;
    h1 = (h1 + b) >>> 0;
    h2 = (h2 + c) >>> 0;
    h3 = (h3 + d) >>> 0;
    h4 = (h4 + e) >>> 0;
  }
  return [h0, h1, h2, h3, h4].map((word) => word.toString(16).padStart(8, "0")).join("");
}

export function memoryIdFor(content: string): string {
  return sha1Hex(memoryDedupeKey(content)).slice(0, 16);
}
