// Supabase Edge Function: wallet-image
//
// Draws the stamp circles shown on a Google Wallet loyalty card as a PNG:
//   GET ?s=<stamps>&g=<goal>&c=<background hex>&a=<accent hex>&k=<ink hex>&r=1 (right to left)
//       &n=<shop name>&l=<ar|fr|en>  (with a name: the elegant themed banner)
// One circle per visit of the shop's goal plus a gold gift circle; stamped
// circles are filled with a check mark. The URL carries the whole state, so
// Google re-downloads the picture whenever the count changes.
//
// Deploy with verify_jwt = false: Google fetches it without credentials.

import {initWasm, Resvg} from 'npm:@resvg/resvg-wasm@2.6.2';
import {heroSvg, wideSvg} from './hero.ts';

const W = 1032, H = 336;

// The elegant version (shop name in Amiri, theme gold) is rendered with
// resvg; the fonts and the engine are fetched once per instance. If anything
// fails the plain circles below are drawn instead.
// Fonts (Amiri, Cairo: SIL OFL) and the resvg engine are served by our site;
// jsDelivr is the fallback.
const SITE = (Deno.env.get('PUBLIC_SITE_URL') ?? 'https://nfc-smart-tags.vercel.app').replace(/\/+$/, '');
const CDN = 'https://cdn.jsdelivr.net';
const FILES = {
  wasm: [`${SITE}/wallet-resvg.wasm`, `${CDN}/npm/@resvg/resvg-wasm@2.6.2/index_bg.wasm`],
  amiri: [`${SITE}/wallet-amiri.ttf`, `${CDN}/gh/google/fonts@main/ofl/amiri/Amiri-Bold.ttf`],
  cairo: [`${SITE}/wallet-cairo.ttf`, `${CDN}/gh/google/fonts@main/ofl/cairo/Cairo%5Bslnt,wght%5D.ttf`],
};
async function grab(urls: string[]): Promise<Uint8Array> {
  for (const u of urls) {
    try {
      const r = await fetch(u);
      if (r.ok) return new Uint8Array(await r.arrayBuffer());
    } catch { /* try the next one */ }
  }
  throw new Error(`cannot load ${urls[0]}`);
}
let wasm: Promise<void> | null = null;
let fonts: Promise<Uint8Array[]> | null = null;
function engine(): Promise<Uint8Array[]> {
  wasm ??= grab(FILES.wasm).then((b) => initWasm(b)).catch((e) => { wasm = null; throw e; });
  fonts ??= Promise.all([grab(FILES.amiri), grab(FILES.cairo)]).catch((e) => { fonts = null; throw e; });
  return wasm.then(() => fonts!);
}

function crcTable(): Uint32Array {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
}
const CRC = crcTable();
function crc32(bytes: Uint8Array): number {
  let c = 0xffffffff;
  for (const b of bytes) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type: string, data: Uint8Array): Uint8Array {
  const out = new Uint8Array(12 + data.length);
  const view = new DataView(out.buffer);
  view.setUint32(0, data.length);
  for (let i = 0; i < 4; i++) out[4 + i] = type.charCodeAt(i);
  out.set(data, 8);
  view.setUint32(8 + data.length, crc32(out.subarray(4, 8 + data.length)));
  return out;
}

async function deflate(data: Uint8Array): Promise<Uint8Array> {
  const stream = new Blob([data]).stream().pipeThrough(new CompressionStream('deflate'));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

async function png(rgba: Uint8Array): Promise<Uint8Array> {
  const raw = new Uint8Array((W * 4 + 1) * H);
  for (let y = 0; y < H; y++) {
    raw[y * (W * 4 + 1)] = 0;
    raw.set(rgba.subarray(y * W * 4, (y + 1) * W * 4), y * (W * 4 + 1) + 1);
  }
  const ihdr = new Uint8Array(13);
  const v = new DataView(ihdr.buffer);
  v.setUint32(0, W);
  v.setUint32(4, H);
  ihdr.set([8, 6, 0, 0, 0], 8);
  const parts = [
    new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', await deflate(raw)),
    chunk('IEND', new Uint8Array()),
  ];
  const out = new Uint8Array(parts.reduce((s, p) => s + p.length, 0));
  let o = 0;
  for (const p of parts) {
    out.set(p, o);
    o += p.length;
  }
  return out;
}

type RGB = [number, number, number];

function hex(c: string): RGB {
  return [parseInt(c.slice(0, 2), 16), parseInt(c.slice(2, 4), 16), parseInt(c.slice(4, 6), 16)];
}

function draw(stamps: number, goal: number, bg: RGB, accent: RGB = [246, 194, 50], ink: RGB = [27, 20, 0], rtl = false): Uint8Array {
  const img = new Uint8Array(W * H * 4);
  // Background: the shop colour, slightly darker towards the bottom.
  for (let y = 0; y < H; y++) {
    const k = 1 - 0.28 * (y / H);
    for (let x = 0; x < W; x++) {
      const i = (y * W + x) * 4;
      img[i] = bg[0] * k;
      img[i + 1] = bg[1] * k;
      img[i + 2] = bg[2] * k;
      img[i + 3] = 255;
    }
  }
  const blend = (x: number, y: number, c: RGB, a: number) => {
    if (a <= 0 || x < 0 || y < 0 || x >= W || y >= H) return;
    const i = (y * W + x) * 4;
    a = Math.min(1, a);
    img[i] = img[i] * (1 - a) + c[0] * a;
    img[i + 1] = img[i + 1] * (1 - a) + c[1] * a;
    img[i + 2] = img[i + 2] * (1 - a) + c[2] * a;
  };
  const segDist = (px: number, py: number, ax: number, ay: number, bx: number, by: number) => {
    const dx = bx - ax, dy = by - ay;
    const t = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)));
    return Math.hypot(px - ax - t * dx, py - ay - t * dy);
  };

  const n = goal + 1; // circles + gift
  const rows = n <= 8 ? 1 : n <= 18 ? 2 : 3;
  const cols = Math.ceil(n / rows);
  const cell = Math.min((W - 60) / cols, (H - 40) / rows);
  const R = cell * 0.4;
  const white: RGB = accent;
  const gold: RGB = accent;
  const ready = stamps >= goal;

  for (let k = 0; k < n; k++) {
    const row = Math.floor(k / cols);
    const inRow = row === rows - 1 ? n - cols * (rows - 1) : cols;
    // Arabic: the first visit is on the right and the gift on the left.
    const col = rtl ? inRow - 1 - (k % cols) : k % cols;
    const rowWidth = inRow * cell;
    const cx = (W - rowWidth) / 2 + cell * (col + 0.5);
    const cy = (H - rows * cell) / 2 + cell * (row + 0.5);
    const gift = k === n - 1;
    const filled = gift ? ready : k < stamps;
    const color = gift ? gold : white;
    const ring = Math.max(3, R * 0.11);
    for (let y = Math.floor(cy - R - 2); y <= cy + R + 2; y++) {
      for (let x = Math.floor(cx - R - 2); x <= cx + R + 2; x++) {
        const d = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
        if (filled) {
          blend(x, y, color, R - d + 0.5);
          if (!gift) {
            // Check mark in the card colour.
            const m = Math.min(
              segDist(x + 0.5, y + 0.5, cx - 0.42 * R, cy + 0.02 * R, cx - 0.1 * R, cy + 0.32 * R),
              segDist(x + 0.5, y + 0.5, cx - 0.1 * R, cy + 0.32 * R, cx + 0.44 * R, cy - 0.3 * R),
            );
            blend(x, y, ink, Math.min(R - d + 0.5, 0.13 * R - m + 0.5));
          }
        } else {
          // Empty: soft fill and a ring.
          blend(x, y, color, Math.min(0.12, (R - d + 0.5) * 0.12));
          blend(x, y, color, Math.min(R - d + 0.5, d - (R - ring) + 0.5) * (gift ? 0.95 : 0.75));
        }
        if (gift) {
          // Simple gift box: body, lid and ribbon.
          const box: RGB = filled ? ink : gold;
          const bx = x + 0.5 - cx, by = y + 0.5 - cy;
          const inBody = Math.abs(bx) <= 0.36 * R && by >= -0.08 * R && by <= 0.42 * R;
          const inLid = Math.abs(bx) <= 0.44 * R && by >= -0.26 * R && by < -0.08 * R;
          const ribbon = Math.abs(bx) <= 0.035 * R && by >= -0.26 * R && by <= 0.42 * R;
          const bow = Math.hypot(bx + 0.16 * R, by + 0.36 * R) <= 0.11 * R || Math.hypot(bx - 0.16 * R, by + 0.36 * R) <= 0.11 * R;
          if ((inBody || inLid || bow) && !ribbon) blend(x, y, box, 1);
          else if (ribbon && (inBody || inLid)) blend(x, y, filled ? gold : bg, 1);
        }
      }
    }
  }
  return img;
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const isPoints = url.searchParams.get('m') === 'p';
  const goal = Math.min(isPoints ? 10000 : 50, Math.max(1, parseInt(url.searchParams.get('g') ?? '5', 10) || 5));
  const stamps = Math.min(isPoints ? 100000 : goal, Math.max(0, parseInt(url.searchParams.get('s') ?? '0', 10) || 0));
  const pick = (k: string, d: string) => (/^[0-9a-fA-F]{6}$/.test(url.searchParams.get(k) ?? '') ? url.searchParams.get(k)! : d);
  const bg = pick('c', '0b1a36'), accent = pick('a', 'f6c232'), ink = pick('k', '1b1400');
  const rtl = url.searchParams.get('r') === '1';
  const name = (url.searchParams.get('n') ?? '').slice(0, 60);
  const l = url.searchParams.get('l');
  const lang = l === 'fr' || l === 'en' ? l : 'ar';
  let body: Uint8Array | null = null;
  if (url.searchParams.get('t') === 'wide') {
    // Front-of-card wide logo; no plain fallback, Google retries later.
    try {
      const fontBuffers = await engine();
      body = new Resvg(wideSvg(name || ' ', accent), {font: {fontBuffers, loadSystemFonts: false, defaultFontFamily: 'Amiri'}}).render().asPng();
    } catch (e) {
      console.error('wide render failed', String(e).slice(0, 200));
      return new Response('busy', {status: 503, headers: {'Retry-After': '60'}});
    }
  } else if (name) {
    try {
      const fontBuffers = await engine();
      const sector = (url.searchParams.get('i') ?? '').replace(/[^a-z]/g, '').slice(0, 12);
      const svg = heroSvg({name, stamps, goal, bg, accent, ink, rtl, lang, sector, points: isPoints});
      body = new Resvg(svg, {font: {fontBuffers, loadSystemFonts: false, defaultFontFamily: 'Cairo'}}).render().asPng();
    } catch (e) {
      console.error('hero render failed', String(e).slice(0, 200));
    }
  }
  body ??= await png(draw(Math.min(stamps, 50), Math.min(goal, 50), hex(bg), hex(accent), hex(ink), rtl));
  return new Response(body, {
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=31536000, immutable',
      'Access-Control-Allow-Origin': '*',
    },
  });
});
