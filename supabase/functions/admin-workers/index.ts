// Supabase Edge Function: admin-workers
//
// Lets an owner/admin (or a super admin) create and manage field-worker
// accounts: username + password live in Supabase Auth, the workspace link and
// the display name live in public.nfc_workers.
//
// Deploy:  supabase functions deploy admin-workers
// Secrets: none, SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY
//          are injected by the platform.
import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Worker usernames map to a synthetic, never-mailed address so GoTrue can own
// the password. The Flutter app builds the same address when signing in.
const WORKER_DOMAIN = 'workers.nfc-studio.internal';
const USERNAME = /^[a-z0-9][a-z0-9_.-]{2,31}$/;
const UUID = /^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/i;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {...CORS, 'Content-Type': 'application/json'},
  });
}

function passwordError(value: unknown): string | null {
  const password = String(value ?? '');
  if (password.length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.';
  if (password.length > 72) return 'كلمة المرور طويلة جداً (72 حرفاً كحد أقصى).';
  return null;
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
  if (!authorization.startsWith('Bearer ')) {
    return json({error: 'التوثيق مطلوب'}, 401);
  }

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
  const workspaceId = String(body.workspace_id ?? '');
  if (!UUID.test(workspaceId)) {
    return json({error: 'مساحة عمل غير صالحة'}, 400);
  }

  const [{data: membership}, {data: superAdmin}] = await Promise.all([
    admin
      .from('nfc_memberships')
      .select('role')
      .eq('tenant_id', workspaceId)
      .eq('user_id', caller.id)
      .maybeSingle(),
    admin
      .from('nfc_super_admins')
      .select('user_id')
      .eq('user_id', caller.id)
      .maybeSingle(),
  ]);
  const callerRole = membership?.role ?? null;
  if (!superAdmin && callerRole !== 'owner' && callerRole !== 'admin') {
    return json({error: 'هذه العملية تتطلب صلاحية مالك أو مدير'}, 403);
  }

  async function logEvent(
    eventAction: string,
    subject: string,
    details: Record<string, unknown> = {},
  ) {
    await admin.from('nfc_activity').insert({
      tenant_id: workspaceId,
      actor_id: caller!.id,
      action: eventAction,
      subject: subject.slice(0, 200),
      details,
    });
  }

  // Owners and super administrators are never removable/disable-able here.
  async function protectsAccount(targetId: string) {
    const [{data: targetMember}, {data: targetSuper}] = await Promise.all([
      admin
        .from('nfc_memberships')
        .select('role')
        .eq('tenant_id', workspaceId)
        .eq('user_id', targetId)
        .maybeSingle(),
      admin
        .from('nfc_super_admins')
        .select('user_id')
        .eq('user_id', targetId)
        .maybeSingle(),
    ]);
    return targetSuper !== null || targetMember?.role === 'owner';
  }

  // Loads a worker that belongs to this workspace (or null).
  async function workerInWorkspace(workerId: string) {
    if (!UUID.test(workerId)) return null;
    const {data} = await admin
      .from('nfc_workers')
      .select('id, username, display_name, tenant_id, created_by')
      .eq('id', workerId)
      .eq('tenant_id', workspaceId)
      .maybeSingle();
    return data;
  }

  try {
    if (action === 'create') {
      const username = String(body.username ?? '').trim().toLowerCase();
      const displayName = String(body.display_name ?? '').trim();
      const role = body.role === 'viewer' ? 'viewer' : 'editor';
      if (!USERNAME.test(username)) {
        return json({
          error:
            'اسم المستخدم: 3–32 حرفاً لاتينياً صغيراً أو أرقام أو _ . - ' +
            'ويبدأ بحرف أو رقم.',
        }, 400);
      }
      if (displayName.length < 2 || displayName.length > 80) {
        return json({error: 'الاسم الظاهر يجب أن يكون بين 2 و80 حرفاً.'}, 400);
      }
      const passwordIssue = passwordError(body.password);
      if (passwordIssue) return json({error: passwordIssue}, 400);

      const {data: taken} = await admin
        .from('nfc_workers')
        .select('id')
        .ilike('username', username)
        .maybeSingle();
      if (taken) return json({error: 'اسم المستخدم مستخدم مسبقاً.'}, 409);

      const email = `${username}@${WORKER_DOMAIN}`;
      const {data: created, error: createError} = await admin.auth.admin
        .createUser({
          email,
          password: String(body.password),
          email_confirm: true,
          user_metadata: {
            worker_username: username,
            display_name: displayName,
            workspace_id: workspaceId,
          },
        });
      if (createError || !created?.user) {
        const conflict = /already|exists|registered/i.test(
          createError?.message ?? '',
        );
        return json({
          error: conflict
            ? 'اسم المستخدم مستخدم مسبقاً.'
            : `تعذّر إنشاء الحساب: ${createError?.message ?? 'خطأ غير معروف'}`,
        }, conflict ? 409 : 400);
      }

      const workerId = created.user.id;
      const {error: workerError} = await admin.from('nfc_workers').insert({
        id: workerId,
        tenant_id: workspaceId,
        username,
        display_name: displayName,
        created_by: caller.id,
      });
      const {error: memberError} = workerError
        ? {error: workerError}
        : await admin.from('nfc_memberships').insert({
            tenant_id: workspaceId,
            user_id: workerId,
            role,
          });
      if (workerError || memberError) {
        // Do not leave an orphan auth account behind.
        await admin.auth.admin.deleteUser(workerId);
        return json({
          error: `تعذّر ربط العامل بمساحة العمل: ${
            (workerError ?? memberError)?.message
          }`,
        }, 500);
      }

      await logEvent('worker_created', displayName, {username, role});
      return json({
        worker: {id: workerId, username, display_name: displayName, role},
      }, 201);
    }

    if (action === 'reset_password') {
      const worker = await workerInWorkspace(String(body.worker_id ?? ''));
      if (!worker) return json({error: 'العامل غير موجود في مساحة العمل.'}, 404);
      const passwordIssue = passwordError(body.password);
      if (passwordIssue) return json({error: passwordIssue}, 400);
      const {error} = await admin.auth.admin.updateUserById(worker.id, {
        password: String(body.password),
      });
      if (error) return json({error: 'تعذّر تحديث كلمة المرور.'}, 400);
      await logEvent('worker_password_reset', worker.display_name, {
        username: worker.username,
      });
      return json({ok: true});
    }

    if (action === 'set_disabled') {
      const worker = await workerInWorkspace(String(body.worker_id ?? ''));
      if (!worker) return json({error: 'العامل غير موجود في مساحة العمل.'}, 404);
      if (await protectsAccount(worker.id)) {
        return json({error: 'لا يمكن تعطيل حساب مالك أو مدير عام.'}, 400);
      }
      const disabled = body.disabled === true;
      const {error: authError} = await admin.auth.admin.updateUserById(
        worker.id,
        {ban_duration: disabled ? '876000h' : 'none'},
      );
      if (authError) return json({error: 'تعذّر تحديث الحساب.'}, 400);
      await admin
        .from('nfc_workers')
        .update({disabled})
        .eq('id', worker.id)
        .eq('tenant_id', workspaceId);
      await logEvent('worker_disabled', worker.display_name, {
        username: worker.username,
        disabled,
      });
      return json({ok: true, disabled});
    }

    if (action === 'delete') {
      const worker = await workerInWorkspace(String(body.worker_id ?? ''));
      if (!worker) return json({error: 'العامل غير موجود في مساحة العمل.'}, 404);
      if (await protectsAccount(worker.id)) {
        return json({error: 'لا يمكن حذف حساب مالك أو مدير عام.'}, 400);
      }
      await admin.auth.admin.deleteUser(worker.id);
      await logEvent('worker_deleted', worker.display_name, {
        username: worker.username,
      });
      return json({ok: true});
    }

    return json({error: 'عملية غير معروفة'}, 400);
  } catch (error) {
    return json({error: `خطأ غير متوقع: ${String(error)}`}, 500);
  }
});
