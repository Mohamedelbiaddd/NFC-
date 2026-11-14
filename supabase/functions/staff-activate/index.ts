// Activates a staff account from its invitation (no password is ever shared).
//   {action: 'check', token}                      -> {state, name, email}
//   {action: 'check', email, code}                 -> same, by the e-mailed code
//   {action: 'activate', token | email+code, password, device:{id, model, platform, os, app}}
//       -> {access_token, refresh_token}: the person chose their own password,
//          this phone becomes the account's only phone, every other login ends.
// Called before login, so it checks the invitation itself (verify_jwt off).
import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {status, headers: {...CORS, 'Content-Type': 'application/json'}});
}

async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

function sessionId(accessToken: string): string | null {
  try {
    const part = accessToken.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    const payload = JSON.parse(atob(part + '='.repeat((4 - (part.length % 4)) % 4)));
    return typeof payload.session_id === 'string' ? payload.session_id : null;
  } catch {
    return null;
  }
}

const str = (v: unknown, max: number) => String(v ?? '').trim().slice(0, max);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: CORS});
  if (req.method !== 'POST') return json({error: 'method'}, 405);
  const url = Deno.env.get('SUPABASE_URL')!;
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: {persistSession: false, autoRefreshToken: false},
  });
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({error: 'bad_request'}, 400);
  }

  // Find the invitation (link token, or e-mail + code).
  const token = str(body.token, 100);
  let invite: Record<string, unknown> | null = null;
  if (/^[A-Za-z0-9]{30,64}$/.test(token)) {
    const {data} = await admin.rpc('nfc_invite_get', {p_token_hash: await sha256(token), p_count: false});
    invite = data;
  } else {
    const email = str(body.email, 200).toLowerCase();
    const code = str(body.code, 20).toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (!email.includes('@') || code.length !== 8) return json({state: 'bad_code'});
    const {data} = await admin.rpc('nfc_invite_by_code', {p_email: email, p_code_hash: await sha256(code)});
    invite = data;
  }
  if (!invite) return json({state: 'not_found'});
  if (invite.state !== 'ok') return json({state: invite.state});
  if (body.action === 'check') {
    return json({state: 'ok', name: invite.name, email: invite.email, expires_at: invite.expires_at});
  }
  if (body.action !== 'activate') return json({error: 'action'}, 400);

  const password = String(body.password ?? '');
  if (password.length < 8 || password.length > 72) return json({state: 'weak_password'});
  const device = (body.device ?? {}) as Record<string, unknown>;
  const deviceId = str(device.id, 100);
  if (deviceId.length < 16) return json({error: 'device'}, 400);

  const userId = String(invite.user_id);
  const {error: updateError} = await admin.auth.admin.updateUserById(userId, {
    password, email_confirm: true,
  });
  if (updateError) return json({error: 'update'}, 500);

  const anon = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    auth: {persistSession: false, autoRefreshToken: false},
  });
  const {data: signed, error: signError} = await anon.auth.signInWithPassword({
    email: String(invite.email), password,
  });
  const session = signed?.session;
  if (signError || !session) return json({error: 'login'}, 500);

  const {data: done} = await admin.rpc('nfc_invite_activate', {
    p_invite: invite.id, p_session: sessionId(session.access_token),
    p_device: deviceId, p_model: str(device.model, 120), p_platform: str(device.platform, 20),
    p_os: str(device.os, 60), p_app: str(device.app, 20),
  });
  if (!done?.ok) return json({state: 'expired'});
  return json({
    state: 'activated',
    email: invite.email,
    access_token: session.access_token,
    refresh_token: session.refresh_token,
  });
});
