// Turns whatever the staff pastes as a shop location into coordinates:
//   * Google Maps links, long or short (maps.app.goo.gl, goo.gl/maps, g.co):
//     redirects are followed and the coordinates read from the final address
//     or page;
//   * "33.5731, -7.5898", "33.5731 -7.5898", 33°34'23"N 7°35'23"W;
//   * Plus Codes, full (8C3JHCMR+QX) or short with a town (HCMR+QX Casablanca;
//     the shop's address is used as the town when none is written).
// POST {q, near?} -> {lat, lng} or {error}. Signed-in app users only.
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {status, headers: {...CORS, 'Content-Type': 'application/json'}});
const UA = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

type LatLng = {lat: number; lng: number};
const trace: string[] = []; // filled only for {debug: true}
const ok = (lat: number, lng: number): LatLng | null =>
  Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180 && !(lat === 0 && lng === 0)
    ? {lat: +lat.toFixed(7), lng: +lng.toFixed(7)}
    : null;

const N = String.raw`(-?\d{1,3}(?:\.\d+)?)`;

/** Coordinates written in a text or an address (most precise pattern first). */
function fromText(raw: string): LatLng | null {
  let t = raw;
  for (let i = 0; i < 3; i++) {
    try {
      const d = decodeURIComponent(t);
      if (d === t) break;
      t = d;
    } catch {
      break;
    }
  }
  t = t.replace(/\+/g, ' ');
  const tries: RegExp[] = [
    new RegExp(String.raw`!3d${N}!4d${N}`),
    new RegExp(String.raw`[?&](?:q|query|ll|sll|daddr|destination|center|cbll)=(?:loc:)?\s*${N}\s*,\s*${N}`),
    new RegExp(String.raw`geo:${N},${N}`),
    new RegExp(String.raw`@${N},${N}`),
    new RegExp(String.raw`^\s*${N}\s*[,;\s]\s*${N}\s*$`),
    new RegExp(String.raw`${N}\s*,\s*${N}`),
  ];
  for (const re of tries) {
    const m = t.match(re);
    if (m) {
      const p = ok(parseFloat(m[1]), parseFloat(m[2]));
      if (p) return p;
    }
  }
  // 33°34'23.1"N 7°35'23.4"W
  const dms = t.match(
    /(\d{1,2})°\s*(\d{1,2})['′]\s*(\d{1,2}(?:\.\d+)?)?["″]?\s*([NS])[\s,]*(\d{1,3})°\s*(\d{1,2})['′]\s*(\d{1,2}(?:\.\d+)?)?["″]?\s*([EW])/i,
  );
  if (dms) {
    const v = (d: string, m: string, s?: string) => +d + +m / 60 + (s ? +s : 0) / 3600;
    const lat = v(dms[1], dms[2], dms[3]) * (/s/i.test(dms[4]) ? -1 : 1);
    const lng = v(dms[5], dms[6], dms[7]) * (/w/i.test(dms[8]) ? -1 : 1);
    return ok(lat, lng);
  }
  return null;
}

/** Coordinates inside a Google Maps page. */
function fromPage(html: string): LatLng | null {
  const a = html.match(/APP_INITIALIZATION_STATE=\[\[\[\s*-?[\d.]+\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\]/);
  const marker = fromText(html.match(/!3d-?[\d.]+!4d-?[\d.]+/)?.[0] ?? '');
  if (marker) return marker;
  const meta = html.match(/content="[^"]*?center=(-?[\d.]+)%2C(-?[\d.]+)/);
  if (meta) return ok(+meta[1], +meta[2]);
  if (a) return ok(+a[2], +a[1]);
  return null;
}

// ------------------------------------------------------------ Plus Codes
const OLC = '23456789CFGHJMPQRVWX';
const PAIR = [20, 1, 0.05, 0.0025, 0.000125];

function decodeFull(code: string): LatLng | null {
  const c = code.toUpperCase().replace('+', '').replace(/0+$/, '');
  let lat = -90, lng = -180, latRes = 20, lngRes = 20;
  for (let i = 0; i < Math.min(c.length, 10); i += 2) {
    latRes = lngRes = PAIR[i / 2];
    lat += OLC.indexOf(c[i]) * latRes;
    if (i + 1 < c.length) lng += OLC.indexOf(c[i + 1]) * lngRes;
  }
  for (let i = 10; i < c.length; i++) {
    latRes /= 5;
    lngRes /= 4;
    const d = OLC.indexOf(c[i]);
    lat += Math.floor(d / 4) * latRes;
    lng += (d % 4) * lngRes;
  }
  return ok(lat + latRes / 2, lng + lngRes / 2);
}

function encodePrefix(lat: number, lng: number, length: number): string {
  let la = Math.min(Math.max(lat, -90), 89.9999999) + 90, ln = (((lng + 180) % 360) + 360) % 360;
  let out = '';
  for (const res of PAIR) {
    const a = Math.floor(la / res), b = Math.floor(ln / res);
    out += OLC[a] + OLC[b];
    la -= a * res;
    ln -= b * res;
  }
  return out.slice(0, length);
}

function recoverNearest(short: string, ref: LatLng): LatLng | null {
  const s = short.toUpperCase();
  const pad = 8 - s.indexOf('+');
  const res = Math.pow(20, 2 - pad / 2);
  const full = encodePrefix(ref.lat, ref.lng, pad) + s;
  const p = decodeFull(full);
  if (!p) return null;
  let {lat, lng} = p;
  if (ref.lat + res / 2 < lat && lat - res >= -90) lat -= res;
  else if (ref.lat - res / 2 > lat && lat + res <= 90) lat += res;
  if (ref.lng + res / 2 < lng) lng -= res;
  else if (ref.lng - res / 2 > lng) lng += res;
  return ok(lat, lng);
}

/** Town or place name -> coordinates (Open-Meteo, then Photon / OpenStreetMap). */
async function geocode(place: string): Promise<LatLng | null> {
  const name = place.trim();
  if (!name) return null;
  try {
    const r = await fetch(`https://photon.komoot.io/api/?limit=1&q=${encodeURIComponent(name)}`, {
      headers: {'User-Agent': 'TapMaroc/1.0 (contact@tapmaroc.com)'},
    });
    trace.push(`photon ${r.status}`);
    if (r.ok) {
      const c = (await r.json())?.features?.[0]?.geometry?.coordinates;
      if (c) return ok(+c[1], +c[0]);
    }
  } catch (_) { /* next */ }
  // Open-Meteo knows towns only: try the last words (often the town).
  const words = name.split(/[\s,،]+/).filter(Boolean);
  for (const n of [name, words.slice(-2).join(' '), words.slice(-1).join(' ')]) {
    if (!n) continue;
    const r = await fetch(`https://geocoding-api.open-meteo.com/v1/search?count=1&name=${encodeURIComponent(n)}`);
    trace.push(`open-meteo ${r.status} ${n}`);
    if (!r.ok) continue;
    const row = (await r.json())?.results?.[0];
    if (row) return ok(+row.latitude, +row.longitude);
  }
  return null;
}

const C = '[23456789CFGHJMPQRVWX]';
async function fromPlusCode(text: string, near: string): Promise<LatLng | null> {
  const full = text.match(new RegExp(`\\b(${C}{8}\\+${C}{2,3})\\b`, 'i'));
  if (full) return decodeFull(full[1]);
  const short = text.match(new RegExp(`\\b(${C}{4,6}\\+${C}{2,3})\\b`, 'i'));
  if (!short || short[1].indexOf('+') % 2) return null;
  const town = text.replace(short[0], '').replace(/[,،]/g, ' ').trim() || near;
  const ref = await geocode(town);
  return ref ? recoverNearest(short[1], ref) : null;
}

// ------------------------------------------------------------ links
// Only map services are fetched (no open proxy).
const MAPS = /(^|\.)(google\.[a-z.]{2,8}|goo\.gl|g\.co|app\.goo\.gl)$/i;

async function fromLink(url: string): Promise<LatLng | null> {
  let current = url;
  for (let hop = 0; hop < 8; hop++) {
    const direct = fromText(current);
    if (direct) return direct;
    if (!MAPS.test(new URL(current).hostname)) return null;
    const r = await fetch(current, {redirect: 'manual', headers: {'User-Agent': UA, 'Accept-Language': 'fr,en'}});
    const next = r.headers.get('location');
    trace.push(`${r.status} ${current.slice(0, 160)} -> ${(next ?? '').slice(0, 300)}`);
    if (r.status >= 300 && r.status < 400 && next) {
      current = new URL(next, current).toString();
      // EU consent page: the real address is in "continue".
      const cont = new URL(current).searchParams.get('continue');
      if (cont && fromText(cont)) return fromText(cont);
      continue;
    }
    const html = r.ok ? (await r.text()).slice(0, 2_000_000) : '';
    trace.push(`page ${html.length} ${html.match(/APP_INITIALIZATION_STATE=.{0,80}/)?.[0] ?? ''}`);
    const inPage = fromPage(html);
    if (inPage) return inPage;
    // Link to a named place without coordinates: look the name up.
    const q = new URL(current).searchParams.get('q');
    return q ? await geocode(q) : null;
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: CORS});
  if (req.method !== 'POST') return json({error: 'method'}, 405);
  const body = await req.json().catch(() => ({}));
  const q = String(body.q ?? '').trim().slice(0, 600);
  const near = String(body.near ?? '').trim().slice(0, 200);
  if (!q) return json({error: 'empty'}, 400);
  try {
    const link = q.match(/https?:\/\/\S+/)?.[0];
    const found = (link ? await fromLink(link) : null) ?? fromText(q) ?? (await fromPlusCode(q, near));
    const dbg = body.debug ? {trace: trace.splice(0)} : (trace.length = 0, {});
    return found ? json({...found, ...dbg}) : json({error: 'not_found', ...dbg});
  } catch (_) {
    return json({error: 'failed'});
  }
});
