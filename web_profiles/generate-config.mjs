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
  'index.html',
  'app.js',
  'routing.mjs',
  'styles.css',
  '_redirects',
  'manifest.webmanifest',
  'icon-192.png',
  'icon-512.png',
  'apple-touch-icon.png',
  'card.html',
  'card.js',
  'shop.html',
  'shop.js',
  'i18n.mjs',
  'loyalty.mjs',
  'qrcode.mjs',
  'loyalty.css',
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
    await cp(join(root, file), join(out, file));
  } catch {
    console.warn(`[config] … skipped missing ${file}`);
  }
}
await writeFile(join(out, 'config.json'), `${JSON.stringify(config, null, 2)}\n`);
console.log(
  `[config] ✔ Wrote dist/config.json for ${config.supabaseUrl} ` +
    `(key ${config.publishableKey.slice(0, 18)}…)`,
);
