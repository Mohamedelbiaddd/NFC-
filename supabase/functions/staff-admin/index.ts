// Supabase Edge Function: staff-admin
//
// Closed registration: staff accounts are only created here.
//   create         {email, name, role, lang}  super admin -> agent|worker, agent -> worker
//   invite         {user_id, lang}      new 24 h invitation link (the old one dies)
//   delete         {user_id}            only when the account has no shops and
//                                       no members under it (suspend otherwise)
//   purge          {user_id, with_children}  deletes the account with everything
//                                       it created (nfc_admin_purge_user), then the
//                                       login(s); with_children: its whole team too
// Nobody receives a password: the account gets an invitation link (24 h)
// that downloads the app and lets the person choose their own password. The
// link is e-mailed when RESEND_API_KEY is set; the creator can also share it.
import {createClient, type SupabaseClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {inviteEmail} from './email.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMAIL = /^[^\s@]{1,64}@[^\s@]{1,190}\.[^\s@]{2,}$/;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {...CORS, 'Content-Type': 'application/json'},
  });
}

function randomText(length: number, chars: string): string {
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(bytes, (b) => chars[b % chars.length]).join('');
}

// Login password nobody knows until the person sets their own.
const password = () => randomText(32, 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789');

export async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

const LANGS = ['ar', 'fr', 'en', 'it'];

/** New invitation for [userId]: link token + 8-character code (both hashed in the DB). */
async function invite(admin: SupabaseClient, actor: string, userId: string, email: string, name: string, lang: string) {
  const token = randomText(40, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789');
  const code = randomText(8, 'ABCDEFGHJKMNPQRSTUVWXYZ23456789');
  const {data, error} = await admin.rpc('nfc_invite_new', {
    p_user: userId, p_email: email, p_lang: lang, p_actor: actor,
    p_token_hash: await sha256(token), p_code_hash: await sha256(code),
  });
  if (error || !data) throw new Error('invite');
  const link = `https://tapmaroc.com/app/${token}`;
  const pretty = `${code.slice(0, 4)}-${code.slice(4)}`;
  let emailed = false;
  const key = Deno.env.get('RESEND_API_KEY') ?? '';
  if (key) {
    const mail = inviteEmail(lang, name, link, pretty);
    try {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {Authorization: `Bearer ${key}`, 'Content-Type': 'application/json'},
        body: JSON.stringify({
          from: Deno.env.get('INVITE_FROM') ?? 'TapMaroc <no-reply@tapmaroc.com>',
          to: [email], subject: mail.subject, html: mail.html, text: mail.text,
          reply_to: Deno.env.get('INVITE_REPLY_TO') ?? undefined,
        }),
      });
      emailed = res.ok;
      await admin.rpc('nfc_invite_mark', {p_invite: data.id, p_status: res.ok ? 'sent' : `error ${res.status}`});
    } catch (_) {
      await admin.rpc('nfc_invite_mark', {p_invite: data.id, p_status: 'error'});
    }
  }
  return {link, code: pretty, expires_at: data.expires_at, emailed};
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: CORS});
  if (req.method !== 'POST') return json({error: 'Method not allowed'}, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json({error: 'إعدادات الدالة غير مكتملة على الخادم'}, 500);
  }
  const authorization = req.headers.get('Authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) return json({error: 'التوثيق مطلوب'}, 401);

  const asCaller = createClient(supabaseUrl, anonKey, {
    global: {headers: {Authorization: authorization}},
    auth: {persistSession: false, autoRefreshToken: false},
  });
  const {data: userData, error: userError} = await asCaller.auth.getUser();
  const caller = userData?.user;
  if (userError || !caller) return json({error: 'جلسة غير صالحة'}, 401);

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: {persistSession: false, autoRefreshToken: false},
  });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({error: 'طلب غير صالح'}, 400);
  }
  const action = String(body.action ?? '');

  try {
    if (action === 'create') {
      const email = String(body.email ?? '').trim().toLowerCase();
      const name = String(body.name ?? '').trim();
      const role = String(body.role ?? 'worker');
      const lang = LANGS.includes(String(body.lang)) ? String(body.lang) : 'ar';
      if (!EMAIL.test(email)) return json({error: 'البريد الإلكتروني غير صحيح'}, 400);
      if (name.length < 1 || name.length > 80) return json({error: 'اكتب الاسم'}, 400);
      if (role !== 'agent' && role !== 'worker') return json({error: 'نوع الحساب غير صحيح'}, 400);
      const {data: allowed, error: allowError} = await asCaller.rpc('nfc_can_create_staff', {new_role: role});
      if (allowError) return json({error: 'تعذّر التحقق من الصلاحية'}, 500);
      if (!allowed) return json({error: 'ليست لديك صلاحية إنشاء هذا النوع من الحسابات'}, 403);

      const pass = password();
      const {data: created, error: createError} = await admin.auth.admin.createUser({
        email,
        password: pass,
        email_confirm: true,
        user_metadata: {display_name: name},
      });
      if (createError || !created?.user) {
        const exists = /already|registered|exists/i.test(createError?.message ?? '');
        return json({error: exists ? 'هذا البريد مسجّل من قبل' : 'تعذّر إنشاء الحساب'}, exists ? 409 : 500);
      }
      const {error: regError} = await admin.rpc('nfc_register_staff', {
        actor: caller.id,
        new_user: created.user.id,
        new_role: role,
        new_name: name,
        new_email: email,
      });
      if (regError) {
        await admin.auth.admin.deleteUser(created.user.id);
        return json({error: 'تعذّر تسجيل الحساب في الشبكة'}, 500);
      }
      const sent = await invite(admin, caller.id, created.user.id, email, name, lang);
      return json({user_id: created.user.id, email, ...sent});
    }

    const target = String(body.user_id ?? '');
    if (!UUID.test(target)) return json({error: 'حساب غير صالح'}, 400);

    if (action === 'purge') {
      const {data: result, error: purgeError} = await asCaller.rpc('nfc_admin_purge_user', {
        target, with_children: body.with_children === true,
      });
      if (purgeError) return json({error: 'تعذّر الحذف'}, 500);
      if (!result?.ok) {
        const msg = result?.error === 'super' ? 'لا يمكن حذف حساب المدير العام' : 'هذا الحساب ليس ضمن شبكتك';
        return json({error: msg}, 403);
      }
      let removed = 0;
      for (const id of (result.users ?? []) as string[]) {
        const {error} = await admin.auth.admin.deleteUser(id);
        if (!error) removed++;
      }
      return json({ok: true, removed});
    }
    const {data: manages, error: manageError} = await asCaller.rpc('nfc_can_manage_staff', {target});
    if (manageError) return json({error: 'تعذّر التحقق من الصلاحية'}, 500);
    if (!manages) return json({error: 'هذا الحساب ليس ضمن شبكتك'}, 403);
    const {data: superTarget} = await admin
      .from('nfc_super_admins').select('user_id').eq('user_id', target).maybeSingle();
    if (superTarget) return json({error: 'لا يمكن تعديل حساب المدير العام من هنا'}, 403);

    if (action === 'invite') {
      const lang = LANGS.includes(String(body.lang)) ? String(body.lang) : 'ar';
      const {data: staff} = await admin
        .from('nfc_staff').select('display_name, email').eq('user_id', target).maybeSingle();
      const {data: user} = await admin.auth.admin.getUserById(target);
      const email = user?.user?.email ?? staff?.email ?? '';
      if (!email) return json({error: 'لا يوجد بريد لهذا الحساب'}, 400);
      const sent = await invite(admin, caller.id, target, email, staff?.display_name ?? '', lang);
      await admin.from('nfc_network_events').insert({
        actor_id: caller.id, action: 'invite_sent', subject_type: 'staff',
        subject_id: target, subject_name: staff?.display_name ?? '',
      });
      return json({email, ...sent});
    }

    if (action === 'delete') {
      const [{count: children}, {count: shops}] = await Promise.all([
        admin.from('nfc_staff').select('user_id', {count: 'exact', head: true}).eq('parent_id', target),
        admin.from('nfc_businesses').select('id', {count: 'exact', head: true})
          .eq('created_by', target).not('shop_slug', 'is', null),
      ]);
      if ((children ?? 0) > 0 || (shops ?? 0) > 0) {
        return json({error: 'لهذا الحساب محلات أو عمال تابعون. أوقفه بدل الحذف.'}, 409);
      }
      const {data: staff} = await admin
        .from('nfc_staff').select('display_name').eq('user_id', target).maybeSingle();
      const {error} = await admin.auth.admin.deleteUser(target);
      if (error) return json({error: 'تعذّر الحذف'}, 500);
      await admin.from('nfc_network_events').insert({
        actor_id: caller.id, action: 'staff_deleted', subject_type: 'staff',
        subject_id: null, subject_name: staff?.display_name ?? '',
      });
      return json({ok: true});
    }

    return json({error: 'عملية غير معروفة'}, 400);
  } catch (_) {
    return json({error: 'خطأ غير متوقع في الخادم'}, 500);
  }
});
