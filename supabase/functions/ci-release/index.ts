// Lets this repo's own GitHub Actions build (build-apk.yml on main, proven
// with a GitHub OIDC token) publish the APKs to the private bucket.
//   {action: 'upload', build, names: [...]}  -> signed upload URLs
//   {action: 'publish', manifest}            -> becomes the current release;
//                                               older builds are deleted
import {createRemoteJWKSet, jwtVerify} from 'npm:jose@5.9.6';
import {createClient} from 'npm:@supabase/supabase-js@2.45.4';

const ISSUER = 'https://token.actions.githubusercontent.com';
const REPO = 'Mohamedelbiaddd/NFC-';
const AUDIENCE = 'tapmaroc-ci-release';
const BUCKET = 'app-releases';
const jwks = createRemoteJWKSet(new URL(`${ISSUER}/.well-known/jwks`));

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {status, headers: {'content-type': 'application/json'}});

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({error: 'method'}, 405);
  const token = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
  try {
    const {payload} = await jwtVerify(token, jwks, {issuer: ISSUER, audience: AUDIENCE});
    const ok =
      payload.repository === REPO &&
      payload.ref === 'refs/heads/main' &&
      payload.event_name !== 'pull_request' &&
      typeof payload.job_workflow_ref === 'string' &&
      payload.job_workflow_ref.startsWith(`${REPO}/.github/workflows/build-apk.yml@refs/heads/main`);
    if (!ok) return json({error: 'forbidden'}, 403);
  } catch (_) {
    return json({error: 'unauthorized'}, 401);
  }
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const body = await req.json().catch(() => ({}));
  const build = Number(body.build ?? body.manifest?.build);
  if (!Number.isInteger(build) || build < 1) return json({error: 'build'}, 400);

  if (body.action === 'upload') {
    const names: string[] = Array.isArray(body.names) ? body.names : [];
    const out: Record<string, string> = {};
    for (const name of names.slice(0, 6)) {
      if (!/^[a-z0-9._-]{1,80}\.apk$/i.test(name)) return json({error: 'name'}, 400);
      const {data, error} = await db.storage.from(BUCKET).createSignedUploadUrl(`android/${build}/${name}`, {upsert: true});
      if (error || !data) return json({error: 'sign', detail: error?.message}, 500);
      out[name] = data.signedUrl;
    }
    return json({urls: out});
  }

  if (body.action === 'publish') {
    const m = body.manifest;
    if (!m || typeof m.files !== 'object') return json({error: 'manifest'}, 400);
    for (const f of Object.values(m.files) as {path: string}[]) {
      if (!String(f.path).startsWith(`android/${build}/`)) return json({error: 'path'}, 400);
    }
    const {error} = await db.rpc('nfc_app_release_set', {p_manifest: m});
    if (error) return json({error: 'save'}, 500);
    // Keep this build and the previous one only (free storage).
    const {data: dirs} = await db.storage.from(BUCKET).list('android', {limit: 100});
    const old = (dirs ?? []).map((d) => Number(d.name)).filter((n) => Number.isInteger(n) && n < build)
      .sort((a, b) => b - a).slice(1);
    for (const n of old) {
      const {data: files} = await db.storage.from(BUCKET).list(`android/${n}`);
      const paths = (files ?? []).map((f) => `android/${n}/${f.name}`);
      if (paths.length) await db.storage.from(BUCKET).remove(paths);
    }
    return json({ok: true, removed: old});
  }
  return json({error: 'action'}, 400);
});
