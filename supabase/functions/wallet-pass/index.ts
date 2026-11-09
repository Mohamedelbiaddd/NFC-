// Supabase Edge Function: wallet-pass
//
// Google Wallet loyalty cards for shop customers.
//   POST {action: 'save', slug, token, lang?} -> {ok, url}  "Add to Google Wallet" link
//   POST {action: 'sync', slug, token}         -> {ok}       refresh points / next booking
//
// The pass uses the shop's theme colours and logo, shows the stamp circles
// (wallet-image), progress, reward and next appointment, and links to call,
// book (#book) and "my booking" (#mybooking) on the shop page.
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

// Page themes (same keys as web_profiles/themes.mjs): card colour, gold, ink.
const THEMES: Record<string, [string, string, string]> = {
  navy: ['#0b1a36', '#f6c232', '#1b1400'], black: ['#101010', '#d4af37', '#1a1405'], emerald: ['#072319', '#34d399', '#032016'],
  royal: ['#170e33', '#c4b5fd', '#1b0f3d'], rose: ['#2a0c1b', '#f9a8d4', '#3b0a22'], ocean: ['#062234', '#38bdf8', '#032033'],
  sunset: ['#271205', '#fb923c', '#2a1102'], crimson: ['#21070f', '#f43f5e', '#ffffff'], ivory: ['#1f1a12', '#b8860b', '#ffffff'],
  mint: ['#0e2a21', '#0f9f6e', '#ffffff'],
};
const AR_NUM = ['', 'واحدة', 'اثنتين', 'ثلاث', 'أربع', 'خمس', 'ست', 'سبع', 'ثماني', 'تسع', 'عشر'];
function visitsText(lang: string, n: number, g: number): string {
  if (lang === 'fr') return `${n} visite(s) sur ${g}`;
  if (lang === 'en') return `${n} of ${g} visits`;
  const count = n === 0 ? 'لا زيارات بعد' : n === 1 ? 'زيارة واحدة' : n === 2 ? 'زيارتان' : n <= 10 ? `${AR_NUM[n]} زيارات` : `${n} زيارة`;
  return `${count} من أصل ${AR_NUM[g] ?? g}`;
}

const TEXT: Record<string, Record<string, string>> = {
  ar: {points: 'الزيارات', reward: 'الهدية', rewards: 'هدايا حصلت عليها', free: '🎁 زيارتك القادمة مجانية!', open: 'افتح بطاقتي', every: 'بعد {0} زيارات', call: 'اتصال', book: 'احجز موعدًا', mine: 'حجزي', next: 'موعدك القادم', progress: 'تقدّمك', scan: 'في كل زيارة امسح الكود الظاهر عند المحل، وتُضاف الدائرة هنا تلقائياً.'},
  fr: {points: 'Visites', reward: 'Cadeau', rewards: 'Cadeaux obtenus', free: '🎁 Votre prochaine visite est offerte !', open: 'Ouvrir ma carte', every: 'Après {0} visites', call: 'Appeler', book: 'Prendre rendez-vous', mine: 'Mon rendez-vous', next: 'Votre prochain rendez-vous', progress: 'Progression', scan: 'À chaque visite, scannez le code affiché au magasin : le cercle s’ajoute ici automatiquement.'},
  en: {points: 'Visits', reward: 'Reward', rewards: 'Rewards earned', free: '🎁 Your next visit is free!', open: 'Open my card', every: 'After {0} visits', call: 'Call', book: 'Book an appointment', mine: 'My booking', next: 'Your next appointment', progress: 'Progress', scan: 'At every visit, scan the code shown at the shop and a circle is added here automatically.'},
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

/// Replaces the resource (PUT, so removed fields disappear) or inserts it.
async function upsert(token: string, kind: string, resource: Record<string, unknown>, createOnly = false) {
  const headers = {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json'};
  const id = encodeURIComponent(String(resource.id));
  let res = await fetch(`${API}/${kind}/${id}`, {method: 'PUT', headers, body: JSON.stringify(resource)});
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
    .select('id, name, shop_slug, primary_color, loyalty_goal, loyalty_reward, loyalty_enabled, suspended, phone, address, card_background, latitude, longitude, logo_url, theme, booking_enabled, services, week_hours, timezone')
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
  const [bg, gold, ink] = THEMES[String(shop.theme)] ?? THEMES.navy;
  const canBook = !!shop.booking_enabled && Array.isArray(shop.services) && shop.services.length > 0 && !!shop.week_hours;
  // Next appointment (shown on the pass).
  const {data: nextBooking} = await db
    .from('nfc_bookings')
    .select('service_name, starts_at')
    .eq('customer_id', customer.id)
    .eq('status', 'booked')
    .gt('starts_at', new Date().toISOString())
    .order('starts_at')
    .limit(1)
    .maybeSingle();
  const tz = String(shop.timezone || 'Africa/Casablanca');
  let nextText: string | null = null;
  if (nextBooking) {
    try {
      nextText = `${nextBooking.service_name} · ${new Intl.DateTimeFormat(lang === 'ar' ? 'ar-MA' : lang, {weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit', hour12: false, timeZone: tz}).format(new Date(nextBooking.starts_at))}`;
    } catch {
      nextText = `${nextBooking.service_name} · ${nextBooking.starts_at}`;
    }
  }
  const logo = typeof shop.logo_url === 'string' && shop.logo_url.startsWith('https://') ? shop.logo_url : `${SITE}/icon-512.png`;

  const loyaltyClass: Record<string, unknown> = {
    id: classId,
    issuerName: String(shop.name).slice(0, 60),
    programName: String(shop.name).slice(0, 60),
    programLogo: {sourceUri: {uri: logo}},
    hexBackgroundColor: bg,
    reviewStatus: 'UNDER_REVIEW',
    countryCode: 'MA',
    multipleDevicesAndHoldersAllowedStatus: 'ONE_USER_ALL_DEVICES',
    ...(shop.latitude != null && shop.longitude != null
      ? {locations: [{latitude: Number(shop.latitude), longitude: Number(shop.longitude)}]}
      : {}),
  };
  const free = stamps >= goal;
  const shown = Math.min(stamps, goal);
  const loyaltyObject: Record<string, unknown> = {
    id: objectId,
    classId,
    state: 'ACTIVE',
    accountId: String(customer.phone),
    accountName: String(customer.name),
    hexBackgroundColor: bg,
    loyaltyPoints: {label: t.points, balance: {string: `${shown} / ${goal}`}},
    secondaryLoyaltyPoints: {label: t.rewards, balance: {int: Number(customer.rewards ?? 0)}},
    // No barcode: the customer scans the shop's live QR, never the other way round.
    heroImage: {
      sourceUri: {
        uri: `${Deno.env.get('SUPABASE_URL')}/functions/v1/wallet-image?s=${shown}&g=${goal}&c=${bg.slice(1)}&a=${gold.slice(1)}&k=${ink.slice(1)}${lang === 'ar' ? '&r=1' : ''}`,
      },
      contentDescription: {defaultValue: {language: lang, value: visitsText(lang, shown, goal)}},
    },
    textModulesData: [
      ...(free ? [{id: 'free', header: '🎁', body: t.free}] : []),
      ...(nextText ? [{id: 'next', header: `📅 ${t.next}`, body: nextText}] : []),
      {id: 'progress', header: `✨ ${t.progress}`, body: visitsText(lang, shown, goal)},
      {id: 'reward', header: `🎁 ${t.reward}`, body: `${reward} · ${t.every.replace('{0}', String(goal))}`},
      {id: 'scan', header: '📷', body: t.scan},
      ...(shop.address ? [{id: 'address', header: '📍', body: String(shop.address)}] : []),
    ],
    linksModuleData: {
      uris: [
        ...(shop.phone ? [{id: 'phone', uri: `tel:${String(shop.phone).replace(/[^+0-9]/g, '')}`, description: `📞 ${t.call} · ${shop.phone}`}] : []),
        ...(canBook ? [{id: 'book', uri: `${cardUrl}#book`, description: `📅 ${t.book}`}] : []),
        ...(canBook ? [{id: 'mine', uri: `${cardUrl}#mybooking`, description: `🗓️ ${t.mine}`}] : []),
        {id: 'card', uri: cardUrl, description: t.open},
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
