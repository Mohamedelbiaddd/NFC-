// Supabase Edge Function: owner-upload
//
// Lets the owner of a public profile upload a photo from the profile page after
// entering the profile PIN. The PIN is checked by public.nfc_owner_login (which
// also counts failed attempts and locks the profile for 15 minutes after five
// wrong codes). The image is stored in the public `profile-images` bucket under
// owner/<slug>/ and its public URL is returned; the page then saves that URL
// through public.nfc_owner_update.
//
// Deploy with verify_jwt = false: visitors only hold the publishable key.
import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const PIN = /^[0-9]{6,12}$/;
const MAX_BYTES = 5 * 1024 * 1024;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {...CORS, 'Content-Type': 'application/json'},
  });
}

// Trust the bytes, not the declared content type.
function sniff(bytes: Uint8Array): {type: string; ext: string} | null {
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return {type: 'image/jpeg', ext: 'jpg'};
  }
  if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) {
    return {type: 'image/png', ext: 'png'};
  }
  if (
    bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
    bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50
  ) {
    return {type: 'image/webp', ext: 'webp'};
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: CORS});
  if (req.method !== 'POST') return json({error: 'Method not allowed'}, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!supabaseUrl || !serviceKey) return json({error: 'إعدادات الخادم غير مكتملة'}, 500);

  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return json({error: 'طلب غير صالح'}, 400);
  }
  const slug = String(form.get('slug') ?? '').trim().toLowerCase();
  const pin = String(form.get('pin') ?? '').trim();
  const file = form.get('file');
  if (!SLUG.test(slug) || slug.length < 3 || slug.length > 63 || !PIN.test(pin)) {
    return json({error: 'الرمز غير صحيح'}, 403);
  }
  if (!(file instanceof File)) return json({error: 'اختر صورة'}, 400);
  if (file.size > MAX_BYTES) return json({error: 'الصورة أكبر من 5 ميغابايت'}, 413);

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: {persistSession: false, autoRefreshToken: false},
  });
  const {data: login, error: loginError} = await admin.rpc('nfc_owner_login', {
    target_slug: slug,
    pin,
  });
  if (loginError) return json({error: 'تعذّر التحقق'}, 500);
  if (!login?.ok) return json({error: 'الرمز غير صحيح أو المحاولات كثيرة'}, 403);

  const bytes = new Uint8Array(await file.arrayBuffer());
  const kind = sniff(bytes);
  if (!kind) return json({error: 'الصيغ المسموحة: JPG وPNG وWEBP'}, 415);

  const path = `owner/${slug}/${crypto.randomUUID()}.${kind.ext}`;
  const {error: uploadError} = await admin.storage
    .from('profile-images')
    .upload(path, bytes, {contentType: kind.type, upsert: false});
  if (uploadError) return json({error: 'تعذّر رفع الصورة'}, 500);

  const {data} = admin.storage.from('profile-images').getPublicUrl(path);
  return json({url: data.publicUrl});
});
