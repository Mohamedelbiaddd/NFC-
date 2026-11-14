// The TapMaroc staff app is no longer public. Two ways to get it:
//   GET  ?t=<invite token>&info=1   -> {state, name, lang, expires_at} for the page
//   GET  ?t=<invite token>[&abi=v7] -> 302 to a 10-minute download link
//        (only while the invitation is valid: 24 h, not used, not replaced)
//   POST (signed-in staff, approved phone) {abi} -> {build, sha, url, size}
//        for the in-app update; the link is valid 30 minutes.
// The APKs sit in the private bucket app-releases (written by ci-release).
import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};
const BUCKET = 'app-releases';

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status, headers: {...CORS, 'Content-Type': 'application/json', 'Cache-Control': 'no-store'},
  });
}

async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

type Manifest = {build: number; sha?: string; files: Record<string, {path: string; size?: number; sha256?: string}>};

// arm64 for every recent phone; v7 (32-bit) for old ones.
function pick(m: Manifest, abi: string) {
  const key = /v7|armeabi/.test(abi) ? 'armeabi-v7a' : /x86_64/.test(abi) ? 'x86_64' : 'arm64-v8a';
  return m.files[key] ?? m.files['arm64-v8a'] ?? Object.values(m.files)[0];
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: CORS});
  const url = Deno.env.get('SUPABASE_URL')!;
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: {persistSession: false, autoRefreshToken: false},
  });
  const {data: manifest} = await admin.rpc('nfc_app_release_get');
  const m = manifest as Manifest | null;

  if (req.method === 'POST') {
    const authorization = req.headers.get('Authorization') ?? '';
    if (!authorization.startsWith('Bearer ')) return json({error: 'auth'}, 401);
    const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: {headers: {Authorization: authorization}},
      auth: {persistSession: false, autoRefreshToken: false},
    });
    // Goes through the API's device check: only the approved phone passes.
    const {error: deviceError} = await caller.rpc('nfc_am_super_admin');
    if (deviceError) return json({error: 'device'}, 403);
    const {data: account} = await caller.rpc('nfc_my_account');
    if (!account?.allowed) return json({error: 'forbidden'}, 403);
    if (!m) return json({build: 0});
    let body: Record<string, unknown> = {};
    try {
      body = await req.json();
    } catch { /* empty */ }
    const file = pick(m, String(body.abi ?? ''));
    const {data: signed} = await admin.storage.from(BUCKET).createSignedUrl(file.path, 1800);
    return json({build: m.build, sha: m.sha, url: signed?.signedUrl, size: file.size, sha256: file.sha256});
  }

  if (req.method !== 'GET') return json({error: 'method'}, 405);
  const params = new URL(req.url).searchParams;
  const token = params.get('t') ?? '';
  if (!/^[A-Za-z0-9]{30,64}$/.test(token)) return json({state: 'not_found'}, 404);
  const info = params.get('info') === '1';
  const {data: invite} = await admin.rpc('nfc_invite_get', {p_token_hash: await sha256(token), p_count: !info});
  if (!invite || invite.state !== 'ok') {
    return info ? json({state: invite?.state ?? 'not_found', lang: invite?.lang}) : json({state: invite?.state ?? 'not_found'}, 410);
  }
  if (info) {
    return json({state: 'ok', name: invite.name, lang: invite.lang, expires_at: invite.expires_at, ready: !!m});
  }
  if (!m) return json({state: 'not_ready'}, 503);
  const file = pick(m, params.get('abi') ?? '');
  const {data: signed} = await admin.storage.from(BUCKET)
    .createSignedUrl(file.path, 600, {download: 'TapMaroc.apk'});
  if (!signed?.signedUrl) return json({state: 'not_ready'}, 503);
  return new Response(null, {status: 302, headers: {...CORS, Location: signed.signedUrl, 'Cache-Control': 'no-store'}});
});
