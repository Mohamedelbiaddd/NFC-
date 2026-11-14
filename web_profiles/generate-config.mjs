#!/usr/bin/env node
// Build-time configuration for the public profile site (/p/<slug>).
//
// Vercel environment variables (Production + Preview) win when they are set:
//   SUPABASE_URL          e.g. https://ikcaingdfybpqrdzucyd.supabase.co
//   SUPABASE_ANON_KEY     publishable key sb_publishable_… (or the legacy anon JWT)
// When they are absent the committed web_profiles/config.json is used, so the
// existing "edit the file" workflow keeps working.
//
// The script writes dist/config.json and copies the static assets into dist,
// which is what vercel.json publishes as Output Directory.
import {cp, mkdir, readFile, rm, writeFile} from 'node:fs/promises';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const out = join(root, 'dist');
const STATIC_FILES = [
  'themes.mjs',
  'sw.js',
  'privacy.html',
  'terms.html',
  'legal.css',
  'index.html',
  'profile.html',
  'start.html',
  'qr.html',
  'image-compress.mjs',
  'tag.html',
  'tag.js',
  'install.html',
  'install.js',
  'qr.js',
  'start.js',
  'robots.txt',
  'sitemap.xml',
  'home.css',
  'home.js',
  'home-cairo.woff2',
  'logo-256.webp',
  'app.js',
  'vcard.mjs',
  'card-themes.json',
  'themes',
  'routing.mjs',
  'styles.css',
  '_redirects',
  'manifest.webmanifest',
  'icon-192.png',
  'icon-512.png',
  'wallet-amiri.ttf',
  'wallet-cairo.ttf',
  'wallet-resvg.wasm',
  'apple-touch-icon.png',
  'card.html',
  'card.js',
  'shop.html',
  'shop.js',
  'i18n.mjs',
  'loyalty.mjs',
  'qrcode.mjs',
  'loyalty.css',
  'membercard.mjs',
  'home-text.mjs',
  'analytics.js',
  'card-name.woff2',
];

function fail(message) {
  console.error(`[config] ✖ ${message}`);
  process.exit(1);
}

// Only a bare https origin is accepted: no path, query, fragment or credentials.
function parseOrigin(value) {
  try {
    const url = new URL(String(value).trim());
    if (url.protocol !== 'https:') return null;
    if (url.username || url.password || url.search || url.hash) return null;
    if (url.pathname !== '/' && url.pathname !== '') return null;
    return url.origin;
  } catch {
    return null;
  }
}

// Accepts a publishable key or a legacy anon JWT, and refuses service keys so a
// privileged key can never end up inside a public page.
function parseKey(value) {
  const key = String(value ?? '').trim();
  if (/^sb_publishable_[A-Za-z0-9_-]{8,}$/.test(key)) return key;
  if (key.startsWith('sb_secret_')) return null;
  const jwt = /^(ey[A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+$/.exec(
    key,
  );
  if (!jwt) return null;
  try {
    const payload = JSON.parse(
      Buffer.from(jwt[2], 'base64url').toString('utf8'),
    );
    return payload.role === 'anon' ? key : null;
  } catch {
    return null;
  }
}

let config;
const envUrl = process.env.SUPABASE_URL;
const envKey =
  process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY;

if (envUrl || envKey) {
  const url = parseOrigin(envUrl ?? '');
  if (!url) {
    fail(
      'SUPABASE_URL must be the https origin of the project, ' +
        'for example https://abcdefghijk.supabase.co',
    );
  }
  const key = parseKey(envKey);
  if (!key) {
    fail(
      'SUPABASE_ANON_KEY must be the publishable key (sb_publishable_…) or the ' +
        'legacy anon JWT. Service role / secret keys are rejected.',
    );
  }
  config = {supabaseUrl: url, publishableKey: key};
  console.log(`[config] ✔ Using Vercel environment variables for ${url}`);
} else {
  let parsed;
  try {
    parsed = JSON.parse(await readFile(join(root, 'config.json'), 'utf8'));
  } catch {
    fail(
      'No SUPABASE_URL/SUPABASE_ANON_KEY environment variables and no readable ' +
        'web_profiles/config.json to fall back to.',
    );
  }
  const url = parseOrigin(parsed?.supabaseUrl);
  const key = parseKey(parsed?.publishableKey);
  if (!url || !key) {
    fail(
      'web_profiles/config.json needs a valid https supabaseUrl and a ' +
        'publishable publishableKey.',
    );
  }
  config = {supabaseUrl: url, publishableKey: key};
  console.log('[config] ✔ Using the committed web_profiles/config.json');
}

await rm(out, {recursive: true, force: true});
await mkdir(out, {recursive: true});
for (const file of STATIC_FILES) {
  try {
    await cp(join(root, file), join(out, file), {recursive: true});
  } catch {
    console.warn(`[config] … skipped missing ${file}`);
  }
}
await writeFile(join(out, 'config.json'), `${JSON.stringify(config, null, 2)}\n`);
console.log(
  `[config] ✔ Wrote dist/config.json for ${config.supabaseUrl} ` +
    `(key ${config.publishableKey.slice(0, 18)}…)`,
);

// The landing page in each language, written out in full so search engines
// show French, English or Italian results to people searching in those
// languages (index.html itself is the Arabic page).
const {T, TITLES, DESCS} = await import(new URL('./home-text.mjs', import.meta.url));
const esc = (v) => String(v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const LOCALE = {fr: 'fr_FR', en: 'en_US', it: 'it_IT'};
const arabic = await readFile(join(root, 'index.html'), 'utf8');
// The Arabic texts ride along in each page, so switching back to Arabic works.
const AR = {};
for (const m of arabic.matchAll(/<([a-z0-9]+)\b[^>]*\sdata-i="([^"]+)"[^>]*>([^<]*)<\/\1>/gi)) {
  AR[m[2]] ??= m[3].replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
}
AR.__desc = /<meta name="description" content="([^"]*)/.exec(arabic)?.[1] ?? '';
const arJson = JSON.stringify(AR).replace(/</g, '\\u003c');
for (const lang of ['fr', 'en', 'it']) {
  let html = arabic
    .replace('<html lang="ar" dir="rtl">', `<html lang="${lang}" dir="ltr">`)
    .replace(/<title>[^<]*<\/title>/, `<title>${esc(TITLES[lang])}</title>`)
    .replace(/(<meta name="description" content=")[^"]*/, `$1${esc(DESCS[lang])}`)
    .replace(/(<meta property="og:title" content=")[^"]*/, `$1${esc(TITLES[lang])}`)
    .replace(/(<meta property="og:description" content=")[^"]*/, `$1${esc(DESCS[lang])}`)
    .replace(/(<meta property="og:url" content=")[^"]*/, `$1https://tapmaroc.com/${lang}`)
    .replace(/(<link rel="canonical" href=")[^"]*/, `$1https://tapmaroc.com/${lang}`)
    .replace(/(<meta property="og:locale" content=")[^"]*/, `$1${LOCALE[lang]}`);
  // Links to the QR generator and the account page keep the language.
  html = html.replace(/href="\/(qr|start)(\?[^"]*)?"/g, (all, page, q) => `href="/${page}${q ? q.replace(/&?lang=[a-z]+/, '') + '&' : '?'}lang=${lang}"`);
  // Every text marked data-i="key" (text only, no tags inside).
  let missing = 0;
  html = html.replace(/(<([a-z0-9]+)\b[^>]*\sdata-i="([^"]+)"[^>]*>)([^<]*)(<\/\2>)/gi, (all, open, tag, key, text, close) => {
    const v = T[lang][key];
    if (v == null) { missing++; return all; }
    return open + esc(v) + close;
  });
  html = html.replace('</body>', `<script type="application/json" id="ar-text">${arJson}</script>\n</body>`);
  await writeFile(join(out, `${lang}.html`), html);
  console.log(`[config] ✔ Wrote dist/${lang}.html${missing ? ` (${missing} texts kept in Arabic)` : ''}`);
}
