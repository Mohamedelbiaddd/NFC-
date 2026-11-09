// Supabase Edge Function: shop-upload
//
// Promo pictures for a loyalty shop, uploaded from the shop owner's browser
// dashboard (/s/<shop>). The owner's session token is checked with
// public.nfc_shop_session_check; the image goes to the public `profile-images`
// bucket under shops/<business id>/ and the page saves the returned URL in the
// shop's banners through public.nfc_shop_update.
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
const SESSION = /^[0-9a-f]{48}$/;
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
  const session = String(form.get('session') ?? '').trim();
  const file = form.get('file');
  if (!SLUG.test(slug) || slug.length < 3 || slug.length > 63 || !SESSION.test(session)) {
    return json({error: 'انتهت الجلسة'}, 403);
  }
  if (!(file instanceof File)) return json({error: 'اختر صورة'}, 400);
  if (file.size > MAX_BYTES) return json({error: 'الصورة أكبر من 5 ميغابايت'}, 413);

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: {persistSession: false, autoRefreshToken: false},
  });
  const {data: businessId, error: checkError} = await admin.rpc('nfc_shop_session_check', {
    target_slug: slug,
    session,
  });
  if (checkError) return json({error: 'تعذّر التحقق'}, 500);
  if (!businessId) return json({error: 'انتهت الجلسة'}, 403);

  const bytes = new Uint8Array(await file.arrayBuffer());
  const kind = sniff(bytes);
  if (!kind) return json({error: 'الصيغ المسموحة: JPG وPNG وWEBP'}, 415);

  const path = `shops/${businessId}/${crypto.randomUUID()}.${kind.ext}`;
  const {error: uploadError} = await admin.storage
    .from('profile-images')
    .upload(path, bytes, {contentType: kind.type, upsert: false});
  if (uploadError) return json({error: 'تعذّر رفع الصورة'}, 500);

  const {data} = admin.storage.from('profile-images').getPublicUrl(path);
  return json({url: data.publicUrl});
});
