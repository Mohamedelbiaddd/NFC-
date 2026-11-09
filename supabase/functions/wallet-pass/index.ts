// Supabase Edge Function: wallet-pass
//
// Google Wallet loyalty cards for shop customers.
//   POST {action: 'save', slug, token, lang?} -> {ok, url}  "Add to Google Wallet" link
//   POST {action: 'sync', slug, token}         -> {ok}       refresh points after a visit
//
// The customer proves who they are with the card token kept in their browser
// (the same token used by nfc_customer_card). One LoyaltyClass per shop and one
// LoyaltyObject per customer are created / updated through the Wallet REST API,
// then a signed "save to wallet" JWT references the object.
//
// Secrets: GOOGLE_WALLET_KEY (service-account JSON), GOOGLE_WALLET_ISSUER_ID.
// Deploy with verify_jwt = false: visitors only hold the publishable key.
import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const TOKEN = /^[0-9a-f]{48}$/;
const API = 'https://walletobjects.googleapis.com/walletobjects/v1';
const SITE = (Deno.env.get('PUBLIC_SITE_URL') ?? 'https://nfc-smart-tags.vercel.app').replace(/\/+$/, '');
const ISSUER = Deno.env.get('GOOGLE_WALLET_ISSUER_ID') ?? '3388000000023223039';

const TEXT: Record<string, Record<string, string>> = {
  ar: {points: 'الزيارات', reward: 'الهدية', rewards: 'هدايا حصلت عليها', free: '🎁 زيارتك القادمة مجانية!', open: 'افتح بطاقتي', every: 'بعد {0} زيارات'},
  fr: {points: 'Visites', reward: 'Cadeau', rewards: 'Cadeaux obtenus', free: '🎁 Votre prochaine visite est offerte !', open: 'Ouvrir ma carte', every: 'Après {0} visites'},
  en: {points: 'Visits', reward: 'Reward', rewards: 'Rewards earned', free: '🎁 Your next visit is free!', open: 'Open my card', every: 'After {0} visits'},
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {status, headers: {...CORS, 'Content-Type': 'application/json'}});
}

const enc = new TextEncoder();
function b64url(data: Uint8Array | string): string {
  const bytes = typeof data === 'string' ? enc.encode(data) : data;
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function sha256(text: string): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', enc.encode(text)));
  return [...digest].map((b) => b.toString(16).padStart(2, '0')).join('');
}

type ServiceKey = {client_email: string; private_key: string};

async function signJwt(key: ServiceKey, payload: Record<string, unknown>): Promise<string> {
  const pem = key.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8', der, {name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256'}, false, ['sign'],
  );
  const unsigned = `${b64url(JSON.stringify({alg: 'RS256', typ: 'JWT'}))}.${b64url(JSON.stringify(payload))}`;
  const sig = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cryptoKey, enc.encode(unsigned)));
  return `${unsigned}.${b64url(sig)}`;
}

async function accessToken(key: ServiceKey): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const assertion = await signJwt(key, {
    iss: key.client_email,
    scope: 'https://www.googleapis.com/auth/wallet_object.issuer',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  });
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: new URLSearchParams({grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion}),
  });
  const body = await res.json();
  if (!res.ok || !body.access_token) throw new Error(`google_auth ${res.status} ${JSON.stringify(body).slice(0, 300)}`);
  return body.access_token;
}

/// Inserts the resource, or replaces it when it already exists.
async function upsert(token: string, kind: string, resource: Record<string, unknown>, createOnly = false) {
  const headers = {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json'};
  const id = encodeURIComponent(String(resource.id));
  let res = await fetch(`${API}/${kind}/${id}`, {method: 'PATCH', headers, body: JSON.stringify(resource)});
  if (res.status === 404) {
    if (createOnly === false) {
      res = await fetch(`${API}/${kind}`, {method: 'POST', headers, body: JSON.stringify(resource)});
    } else {
      return false;
    }
  }
  if (!res.ok) throw new Error(`wallet_${kind} ${res.status} ${(await res.text()).slice(0, 400)}`);
  return true;
}

const plain = (id: string) => id.replace(/[^a-zA-Z0-9]/g, '');
const color = (c: unknown, fallback: string) => (typeof c === 'string' && /^#[0-9a-fA-F]{6}$/.test(c) ? c : fallback);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: CORS});
  if (req.method !== 'POST') return json({ok: false, error: 'method'}, 405);
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ok: false, error: 'body'}, 400);
  }
  const action = body.action === 'sync' ? 'sync' : 'save';
  const slug = String(body.slug ?? '').toLowerCase().trim();
  const cardToken = String(body.token ?? '');
  const lang = ['ar', 'fr', 'en'].includes(String(body.lang)) ? String(body.lang) : 'ar';
  if (!SLUG.test(slug) || !TOKEN.test(cardToken)) return json({ok: false, error: 'card'}, 400);

  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: {persistSession: false},
  });
  // The key comes from the function secret, or else from the private
  // nfc_private.app_secrets table (service role only).
  let rawKey = Deno.env.get('GOOGLE_WALLET_KEY');
  if (!rawKey) {
    const {data} = await db.rpc('nfc_app_secret', {secret_name: 'GOOGLE_WALLET_KEY'});
    if (typeof data === 'string' && data) rawKey = data;
  }
  if (!rawKey) {
    console.error('GOOGLE_WALLET_KEY missing (secret and app_secrets)');
    return json({ok: false, error: 'not_configured'}, 503);
  }
  let key: ServiceKey;
  try {
    key = JSON.parse(rawKey.trim());
    if (!key.client_email || !key.private_key) throw new Error('fields');
  } catch (e) {
    console.error(`GOOGLE_WALLET_KEY is not valid service-account JSON (${rawKey.length} chars): ${String(e).slice(0, 80)}`);
    return json({ok: false, error: 'bad_key'}, 500);
  }

  const {data: shop} = await db
    .from('nfc_businesses')
    .select('id, name, shop_slug, primary_color, loyalty_goal, loyalty_reward, loyalty_enabled, suspended, phone, address, card_background, latitude, longitude')
    .eq('shop_slug', slug)
    .maybeSingle();
  if (!shop || !shop.loyalty_enabled || shop.suspended) return json({ok: false, error: 'shop'}, 404);
  const {data: customer} = await db
    .from('nfc_customers')
    .select('id, name, phone, stamps, rewards, total_visits, goal, reward')
    .eq('business_id', shop.id)
    .eq('token_hash', await sha256(cardToken))
    .maybeSingle();
  if (!customer) return json({ok: false, error: 'card'}, 404);

  const t = TEXT[lang];
  const goal = Number(customer.goal ?? shop.loyalty_goal ?? 5);
  const reward = String(customer.reward ?? shop.loyalty_reward ?? '');
  const stamps = Number(customer.stamps ?? 0);
  const cardUrl = `${SITE}/c/${shop.shop_slug}`;
  const classId = `${ISSUER}.shop_${plain(shop.id)}`;
  const objectId = `${ISSUER}.cust_${plain(customer.id)}`;
  const bg = color(shop.primary_color, '#7367F0');

  const loyaltyClass: Record<string, unknown> = {
    id: classId,
    issuerName: String(shop.name).slice(0, 60),
    programName: String(shop.name).slice(0, 60),
    programLogo: {sourceUri: {uri: `${SITE}/icon-512.png`}},
    hexBackgroundColor: bg,
    reviewStatus: 'UNDER_REVIEW',
    countryCode: 'MA',
    multipleDevicesAndHoldersAllowedStatus: 'ONE_USER_ALL_DEVICES',
    ...(shop.card_background ? {heroImage: {sourceUri: {uri: shop.card_background}}} : {}),
    ...(shop.latitude != null && shop.longitude != null
      ? {locations: [{latitude: Number(shop.latitude), longitude: Number(shop.longitude)}]}
      : {}),
  };
  const free = stamps >= goal;
  const loyaltyObject: Record<string, unknown> = {
    id: objectId,
    classId,
    state: 'ACTIVE',
    accountId: String(customer.phone),
    accountName: String(customer.name),
    hexBackgroundColor: bg,
    loyaltyPoints: {label: t.points, balance: {string: `${Math.min(stamps, goal)} / ${goal}`}},
    secondaryLoyaltyPoints: {label: t.rewards, balance: {int: Number(customer.rewards ?? 0)}},
    barcode: {type: 'QR_CODE', value: cardUrl, alternateText: String(customer.name).slice(0, 30)},
    textModulesData: [
      {id: 'reward', header: t.reward, body: `${reward} · ${t.every.replace('{0}', String(goal))}`},
      ...(free ? [{id: 'free', header: '🎁', body: t.free}] : []),
      ...(shop.address ? [{id: 'address', header: '📍', body: String(shop.address)}] : []),
    ],
    linksModuleData: {
      uris: [
        {id: 'card', uri: cardUrl, description: t.open},
        ...(shop.phone ? [{id: 'phone', uri: `tel:${shop.phone}`, description: String(shop.phone)}] : []),
      ],
    },
  };

  try {
    const token = await accessToken(key);
    if (action === 'sync') {
      // Only refreshes cards the customer already saved.
      const exists = await upsert(token, 'loyaltyObject', loyaltyObject, true);
      if (exists) await upsert(token, 'loyaltyClass', loyaltyClass);
      return json({ok: true, saved: exists});
    }
    await upsert(token, 'loyaltyClass', loyaltyClass);
    await upsert(token, 'loyaltyObject', loyaltyObject);
    const jwt = await signJwt(key, {
      iss: key.client_email,
      aud: 'google',
      typ: 'savetowallet',
      origins: [SITE],
      payload: {loyaltyObjects: [{id: objectId}]},
    });
    return json({ok: true, url: `https://pay.google.com/gp/v/save/${jwt}`});
  } catch (e) {
    console.error(String(e));
    return json({ok: false, error: 'wallet', detail: String(e).slice(0, 300)}, 502);
  }
});
