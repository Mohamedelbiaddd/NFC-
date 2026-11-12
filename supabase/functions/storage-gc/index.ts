// Deletes pictures nobody uses any more from the profile-images bucket.
// Called by the database right after an edit drops a picture (with the
// dropped paths) and every hour (to catch uploads that were never saved).
// Only the database knows the key, so nobody else can trigger it.
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

const BUCKET = 'profile-images';

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('method', { status: 405 });
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const key = req.headers.get('x-gc-key') ?? '';
  if (!/^[0-9a-f]{64}$/.test(key)) return new Response('forbidden', { status: 403 });
  const { data: ok } = await db.rpc('nfc_gc_key_ok', { k: key });
  if (ok !== true) return new Response('forbidden', { status: 403 });

  const body = await req.json().catch(() => ({}));
  const force = Array.isArray(body?.paths)
    ? body.paths.filter((p: unknown) => typeof p === 'string' && p.length < 300 && !p.includes('..')).slice(0, 200)
    : [];
  const { data: orphans, error } = await db.rpc('nfc_storage_orphans', { grace_minutes: 120, force });
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });

  const names: string[] = orphans ?? [];
  let removed = 0;
  for (let i = 0; i < names.length; i += 100) {
    const batch = names.slice(i, i + 100);
    const { data, error: rmError } = await db.storage.from(BUCKET).remove(batch);
    if (!rmError) removed += data?.length ?? 0;
  }
  return new Response(JSON.stringify({ removed }), { headers: { 'content-type': 'application/json' } });
});
