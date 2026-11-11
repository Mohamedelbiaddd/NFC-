// Hands the Android release keystore to this repo's own GitHub Actions
// build, and to nobody else. The caller proves who it is with a GitHub
// OIDC token (signed by GitHub, no shared secret): it must come from a
// push to main of Mohamedelbiaddd/NFC- running build-apk.yml.
import { createRemoteJWKSet, jwtVerify } from 'npm:jose@5.9.6';
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

const ISSUER = 'https://token.actions.githubusercontent.com';
const REPO = 'Mohamedelbiaddd/NFC-';
const AUDIENCE = 'tapmaroc-ci-signing';
const jwks = createRemoteJWKSet(new URL(`${ISSUER}/.well-known/jwks`));

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('method', { status: 405 });
  const token = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
  try {
    const { payload } = await jwtVerify(token, jwks, { issuer: ISSUER, audience: AUDIENCE });
    const ok =
      payload.repository === REPO &&
      payload.ref === 'refs/heads/main' &&
      payload.event_name !== 'pull_request' &&
      typeof payload.job_workflow_ref === 'string' &&
      payload.job_workflow_ref.startsWith(`${REPO}/.github/workflows/build-apk.yml@refs/heads/main`);
    if (!ok) return new Response('forbidden', { status: 403 });
  } catch (_) {
    return new Response('unauthorized', { status: 401 });
  }
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data, error } = await db.rpc('nfc_ci_signing');
  if (error || !data) return new Response('unavailable', { status: 503 });
  return new Response(JSON.stringify(data), { headers: { 'content-type': 'application/json' } });
});
