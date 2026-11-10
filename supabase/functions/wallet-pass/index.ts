// Supabase Edge Function: wallet-pass
//
// Google Wallet loyalty cards for shop customers.
//   POST {action: 'save', slug, token, lang?} -> {ok, url}  "Add to Google Wallet" link
//   POST {action: 'sync', slug, token}         -> {ok}       refresh points / next booking
//   POST {action: 'call', slug, session, customer_id} -> {ok, saved} the owner says
//        "your turn": the saved card gets a message Google pushes as a notification
//   POST {action: 'birthdays', secret}          -> {ok, sent} daily job (pg_cron): birthday
//        cards are refreshed with a Wallet notification (secret = app_secrets CRON_SECRET)
//
// Sector extras: points-by-amount shops show points and the MAD rule, gyms the
// subscription end, car washes the vehicle and last wash; a menu link when set.
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
  coffee: ['#21140c', '#d6a15a', '#1e1208'], aqua: ['#122230', '#4cc9f0', '#04202c'],
  pizza: ['#1a0f0c', '#ff7a2f', '#2a0d02'], neon: ['#101210', '#b6ff3b', '#0d1a00'],
};
// What one stamp is called, by sector (label of the points on the pass).
const UNITS: Record<string, Record<string, string>> = {
  cafe: {ar: 'الأكواب', fr: 'Cafés', en: 'Coffees'}, carwash: {ar: 'الغسلات', fr: 'Lavages', en: 'Washes'},
  snack: {ar: 'الطلبات', fr: 'Commandes', en: 'Orders'}, gym: {ar: 'الحصص', fr: 'Séances', en: 'Sessions'},
};
const AR_NUM = ['', 'واحدة', 'اثنتين', 'ثلاث', 'أربع', 'خمس', 'ست', 'سبع', 'ثماني', 'تسع', 'عشر'];
function visitsText(lang: string, n: number, g: number): string {
  if (lang === 'fr') return `${n} visite(s) sur ${g}`;
  if (lang === 'en') return `${n} of ${g} visits`;
  const count = n === 0 ? 'لا زيارات بعد' : n === 1 ? 'زيارة واحدة' : n === 2 ? 'زيارتان' : n <= 10 ? `${AR_NUM[n]} زيارات` : `${n} زيارة`;
  return `${count} من أصل ${AR_NUM[g] ?? g}`;
}

const TEXT: Record<string, Record<string, string>> = {
  ar: {pts: 'النقاط', perPoint: 'كل {0} درهم = نقطة', menu: 'المنيو / اطلب الآن', subUntil: 'الاشتراك صالح حتى', subExpired: '⚠️ انتهى الاشتراك، جدّده عند الاستقبال', vehicle: 'السيارة', lastWash: 'آخر غسلة', bday: '🎂 عيد ميلاد سعيد!', bdayBody: 'هديتك اليوم: {0}', bdayNoGift: 'كل عام وأنت بخير، ننتظرك اليوم!', small: 'سيارة صغيرة', suv: 'SUV', x4: 'دفع رباعي 4x4', points: 'الزيارات', reward: 'الهدية', rewards: 'هدايا حصلت عليها', free: '🎁 زيارتك القادمة مجانية!', open: 'افتح بطاقتي', every: 'بعد {0} زيارات', call: 'اتصال', book: 'احجز موعدًا', mine: 'حجزي', next: 'موعدك القادم', progress: 'تقدّمك', scan: 'في كل زيارة امسح الكود الظاهر عند المحل، وتُضاف الدائرة هنا تلقائياً.'},
  fr: {pts: 'Points', perPoint: '{0} MAD = 1 point', menu: 'Menu / Commander', subUntil: 'Abonnement valable jusqu’au', subExpired: '⚠️ Abonnement expiré, renouvelez-le à l’accueil', vehicle: 'Véhicule', lastWash: 'Dernier lavage', bday: '🎂 Joyeux anniversaire !', bdayBody: 'Votre cadeau aujourd’hui : {0}', bdayNoGift: 'Bon anniversaire, on vous attend aujourd’hui !', small: 'Petite voiture', suv: 'SUV', x4: '4x4', points: 'Visites', reward: 'Cadeau', rewards: 'Cadeaux obtenus', free: '🎁 Votre prochaine visite est offerte !', open: 'Ouvrir ma carte', every: 'Après {0} visites', call: 'Appeler', book: 'Prendre rendez-vous', mine: 'Mon rendez-vous', next: 'Votre prochain rendez-vous', progress: 'Progression', scan: 'À chaque visite, scannez le code affiché au magasin : le cercle s’ajoute ici automatiquement.'},
  en: {pts: 'Points', perPoint: '{0} MAD = 1 point', menu: 'Menu / Order now', subUntil: 'Subscription valid until', subExpired: '⚠️ Subscription expired, renew it at the desk', vehicle: 'Vehicle', lastWash: 'Last wash', bday: '🎂 Happy birthday!', bdayBody: 'Your gift today: {0}', bdayNoGift: 'Happy birthday, see you today!', small: 'Small car', suv: 'SUV', x4: '4x4', points: 'Visits', reward: 'Reward', rewards: 'Rewards earned', free: '🎁 Your next visit is free!', open: 'Open my card', every: 'After {0} visits', call: 'Call', book: 'Book an appointment', mine: 'My booking', next: 'Your next appointment', progress: 'Progress', scan: 'At every visit, scan the code shown at the shop and a circle is added here automatically.'},
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

type Row = Record<string, any>;
const SHOP_FIELDS = 'id, name, shop_slug, primary_color, loyalty_goal, loyalty_reward, loyalty_enabled, suspended, phone, address, card_background, latitude, longitude, logo_url, theme, industry, booking_enabled, services, week_hours, timezone, loyalty_mode, points_per, menu_url, birthday_reward';
const CUSTOMER_FIELDS = 'id, name, phone, stamps, rewards, total_visits, goal, reward, vehicle_type, dob, expiry_date, last_visit_at, wallet_lang, birthday_year';

// Today's date (YYYY-MM-DD) in the shop's time zone.
function todayIn(tz: string): string {
  try {
    return new Intl.DateTimeFormat('en-CA', {timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit'}).format(new Date());
  } catch {
    return new Date().toISOString().slice(0, 10);
  }
}
function fmtDate(lang: string, iso: string, tz: string): string {
  try {
    return new Intl.DateTimeFormat(lang === 'ar' ? 'ar-MA' : lang, {day: 'numeric', month: 'long', year: 'numeric', timeZone: tz})
      .format(new Date(iso.length === 10 ? `${iso}T12:00:00Z` : iso));
  } catch {
    return iso.slice(0, 10);
  }
}

/// The loyalty class (one per shop) and object (one per customer).
async function buildPass(db: any, shop: Row, customer: Row, lang: string) {
  const t = TEXT[lang];
  const tz = String(shop.timezone || 'Africa/Casablanca');
  const today = todayIn(tz);
  const points = shop.loyalty_mode === 'points';
  const goal = Number(customer.goal ?? shop.loyalty_goal ?? 5);
  const reward = String(customer.reward ?? shop.loyalty_reward ?? '');
  const stamps = Number(customer.stamps ?? 0);
  const cardUrl = `${SITE}/c/${shop.shop_slug}`;
  const classId = `${ISSUER}.shop_${plain(shop.id)}`;
  const objectId = `${ISSUER}.cust_${plain(customer.id)}`;
  const [bg, gold, ink] = THEMES[String(shop.theme)] ?? THEMES.navy;
  const canBook = !!shop.booking_enabled && !!shop.week_hours;
  const birthday = !!customer.dob && String(customer.dob).slice(5, 10) === today.slice(5, 10);
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
  let nextText: string | null = null;
  if (nextBooking) {
    try {
      nextText = `${nextBooking.service_name} · ${new Intl.DateTimeFormat(lang === 'ar' ? 'ar-MA' : lang, {weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit', hour12: false, timeZone: tz}).format(new Date(nextBooking.starts_at))}`;
    } catch {
      nextText = `${nextBooking.service_name} · ${nextBooking.starts_at}`;
    }
  }
  const logo = typeof shop.logo_url === 'string' && shop.logo_url.startsWith('https://') ? shop.logo_url : `${SITE}/icon-512.png`;
  const fn = `${Deno.env.get('SUPABASE_URL')}/functions/v1/wallet-image`;
  const name40 = encodeURIComponent(String(shop.name).slice(0, 40));

  const loyaltyClass: Record<string, unknown> = {
    id: classId,
    issuerName: String(shop.name).slice(0, 60),
    // The shop name is drawn large and elegant on the card picture itself.
    programName: lang === 'fr' ? 'Carte de fidélité' : lang === 'en' ? 'Loyalty card' : 'بطاقة الولاء',
    programLogo: {sourceUri: {uri: logo}},
    // The shop name in the theme's gold and Amiri on the front of the card.
    wideProgramLogo: {
      sourceUri: {uri: `${fn}?t=wide&a=${gold.slice(1)}&n=${name40}&v=1`},
      contentDescription: {defaultValue: {language: lang, value: String(shop.name).slice(0, 60)}},
    },
    hexBackgroundColor: bg,
    reviewStatus: 'UNDER_REVIEW',
    countryCode: 'MA',
    multipleDevicesAndHoldersAllowedStatus: 'ONE_USER_ALL_DEVICES',
    ...(shop.latitude != null && shop.longitude != null
      ? {locations: [{latitude: Number(shop.latitude), longitude: Number(shop.longitude)}]}
      : {}),
  };
  const free = stamps >= goal;
  const shown = points ? stamps : Math.min(stamps, goal);
  const vehicle = ({small: t.small, suv: t.suv, '4x4': t.x4} as Record<string, string>)[String(customer.vehicle_type)] ?? null;
  const expired = !!customer.expiry_date && String(customer.expiry_date) < today;
  const year = today.slice(0, 4);
  const loyaltyObject: Record<string, unknown> = {
    id: objectId,
    classId,
    state: 'ACTIVE',
    accountName: String(customer.name),
    hexBackgroundColor: bg,
    loyaltyPoints: {
      label: points ? t.pts : UNITS[String(shop.industry)]?.[lang] ?? t.points,
      balance: {string: `${shown} / ${goal}`},
    },
    secondaryLoyaltyPoints: {label: t.rewards, balance: {int: Number(customer.rewards ?? 0)}},
    // No barcode: the customer scans the shop's live QR, never the other way round.
    heroImage: {
      sourceUri: {
        uri: `${fn}?s=${shown}&g=${goal}&c=${bg.slice(1)}&a=${gold.slice(1)}&k=${ink.slice(1)}${lang === 'ar' ? '&r=1' : ''}&l=${lang}&n=${name40}&i=${String(shop.industry ?? '')}${points ? '&m=p' : ''}&v=3`,
      },
      contentDescription: {defaultValue: {language: lang, value: points ? `${shown} / ${goal}` : visitsText(lang, shown, goal)}},
    },
    textModulesData: [
      ...(birthday ? [{id: 'bday', header: t.bday, body: shop.birthday_reward ? t.bdayBody.replace('{0}', String(shop.birthday_reward)) : t.bdayNoGift}] : []),
      ...(free ? [{id: 'free', header: '🎁', body: t.free}] : []),
      ...(nextText ? [{id: 'next', header: `📅 ${t.next}`, body: nextText}] : []),
      ...(shop.industry === 'gym' && customer.expiry_date
        ? [{id: 'sub', header: `🗓️ ${t.subUntil}`, body: expired ? `${fmtDate(lang, String(customer.expiry_date), tz)} · ${t.subExpired}` : fmtDate(lang, String(customer.expiry_date), tz)}]
        : []),
      ...(shop.industry === 'carwash' && vehicle ? [{id: 'vehicle', header: `🚘 ${t.vehicle}`, body: vehicle}] : []),
      ...(shop.industry === 'carwash' && customer.last_visit_at ? [{id: 'wash', header: `🧽 ${t.lastWash}`, body: fmtDate(lang, String(customer.last_visit_at), tz)}] : []),
      {id: 'reward', header: `🎁 ${t.reward}`, body: points ? `${reward} · ${goal} ${t.pts}` : `${reward} · ${t.every.replace('{0}', String(goal))}`},
      ...(points ? [{id: 'rule', header: '💰', body: t.perPoint.replace('{0}', String(shop.points_per ?? 10))}] : []),
      {id: 'scan', header: '📷', body: t.scan},
      ...(shop.address ? [{id: 'address', header: '📍', body: String(shop.address)}] : []),
    ],
    linksModuleData: {
      uris: [
        ...(shop.menu_url ? [{id: 'menu', uri: String(shop.menu_url), description: `🍽️ ${t.menu}`}] : []),
        ...(shop.phone ? [{id: 'phone', uri: `tel:${String(shop.phone).replace(/[^+0-9]/g, '')}`, description: `📞 ${t.call} · ${shop.phone}`}] : []),
        ...(canBook ? [{id: 'book', uri: `${cardUrl}#book`, description: `📅 ${t.book}`}] : []),
        ...(canBook ? [{id: 'mine', uri: `${cardUrl}#mybooking`, description: `🗓️ ${t.mine}`}] : []),
        {id: 'card', uri: cardUrl, description: t.open},
      ],
    },
    // On the birthday a message that Google pushes as a notification (once per year).
    ...(birthday
      ? {messages: [{
          id: `bday-${year}`,
          header: t.bday,
          body: shop.birthday_reward ? t.bdayBody.replace('{0}', String(shop.birthday_reward)) : t.bdayNoGift,
          messageType: 'TEXT_AND_NOTIFY',
        }]}
      : {}),
  };
  return {loyaltyClass, loyaltyObject, objectId, birthday, year: Number(year)};
}

async function loadKey(db: any): Promise<ServiceKey | Response> {
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
  try {
    const key = JSON.parse(rawKey.trim());
    if (!key.client_email || !key.private_key) throw new Error('fields');
    return key;
  } catch (e) {
    console.error(`GOOGLE_WALLET_KEY is not valid service-account JSON (${rawKey.length} chars): ${String(e).slice(0, 80)}`);
    return json({ok: false, error: 'bad_key'}, 500);
  }
}

// Daily job: customers whose birthday is today get their saved card refreshed
// with the birthday message (Google shows a notification).
async function birthdays(db: any, key: ServiceKey): Promise<Response> {
  const {data: shops} = await db.from('nfc_businesses').select(SHOP_FIELDS)
    .eq('loyalty_enabled', true).eq('suspended', false).not('shop_slug', 'is', null);
  const token = await accessToken(key);
  let sent = 0;
  for (const shop of shops ?? []) {
    const today = todayIn(String(shop.timezone || 'Africa/Casablanca'));
    const {data: customers} = await db.from('nfc_customers').select(CUSTOMER_FIELDS)
      .eq('business_id', shop.id).not('dob', 'is', null);
    for (const c of customers ?? []) {
      if (String(c.dob).slice(5, 10) !== today.slice(5, 10) || Number(c.birthday_year) === Number(today.slice(0, 4))) continue;
      try {
        const pass = await buildPass(db, shop, c, String(c.wallet_lang || 'ar'));
        const exists = await upsert(token, 'loyaltyObject', pass.loyaltyObject, true);
        await db.from('nfc_customers').update({birthday_year: pass.year}).eq('id', c.id);
        if (exists) sent++;
      } catch (e) {
        console.error('birthday', String(e).slice(0, 200));
      }
    }
  }
  return json({ok: true, sent});
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: CORS});
  if (req.method !== 'POST') return json({ok: false, error: 'method'}, 405);
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ok: false, error: 'body'}, 400);
  }
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: {persistSession: false},
  });

  if (body.action === 'birthdays') {
    const {data: secret} = await db.rpc('nfc_app_secret', {secret_name: 'CRON_SECRET'});
    if (typeof secret !== 'string' || !secret || body.secret !== secret) return json({ok: false, error: 'forbidden'}, 403);
    const key = await loadKey(db);
    if (key instanceof Response) return key;
    try {
      return await birthdays(db, key);
    } catch (e) {
      console.error(String(e));
      return json({ok: false, error: 'wallet'}, 502);
    }
  }

  if (body.action === 'call') {
    const slug = String(body.slug ?? '').toLowerCase().trim();
    const session = String(body.session ?? '');
    const customerId = String(body.customer_id ?? '');
    if (!SLUG.test(slug) || !/^[0-9a-f]{48}$/.test(session) || !/^[0-9a-f-]{36}$/.test(customerId)) {
      return json({ok: false, error: 'bad'}, 400);
    }
    const {data: businessId} = await db.rpc('nfc_shop_session_check', {target_slug: slug, session});
    if (!businessId) return json({ok: false, error: 'session'}, 403);
    const key = await loadKey(db);
    if (key instanceof Response) return key;
    const {data: shop} = await db.from('nfc_businesses').select(SHOP_FIELDS).eq('id', businessId).maybeSingle();
    const {data: customer} = await db.from('nfc_customers').select(CUSTOMER_FIELDS)
      .eq('id', customerId).eq('business_id', businessId).maybeSingle();
    if (!shop || !customer) return json({ok: false, error: 'customer'}, 404);
    try {
      const lang = String(customer.wallet_lang || 'ar');
      const pass = await buildPass(db, shop, customer, lang);
      const turn = {
        ar: ['🔔 حان دورك!', `تفضّل، ${shop.name} في انتظارك الآن.`],
        fr: ['🔔 C’est votre tour !', `${shop.name} vous attend maintenant.`],
        en: ['🔔 It’s your turn!', `${shop.name} is ready for you now.`],
      }[lang] ?? ['🔔', String(shop.name)];
      const obj = pass.loyaltyObject as Record<string, any>;
      obj.messages = [...(obj.messages ?? []), {id: `turn-${Date.now()}`, header: turn[0], body: turn[1], messageType: 'TEXT_AND_NOTIFY'}];
      const token = await accessToken(key);
      const saved = await upsert(token, 'loyaltyObject', obj, true);
      return json({ok: true, saved});
    } catch (e) {
      console.error(String(e));
      return json({ok: false, error: 'wallet'}, 502);
    }
  }

  const action = body.action === 'sync' ? 'sync' : 'save';
  const slug = String(body.slug ?? '').toLowerCase().trim();
  const cardToken = String(body.token ?? '');
  const lang = ['ar', 'fr', 'en'].includes(String(body.lang)) ? String(body.lang) : 'ar';
  if (!SLUG.test(slug) || !TOKEN.test(cardToken)) return json({ok: false, error: 'card'}, 400);

  const key = await loadKey(db);
  if (key instanceof Response) return key;

  const {data: shop} = await db.from('nfc_businesses').select(SHOP_FIELDS).eq('shop_slug', slug).maybeSingle();
  if (!shop || !shop.loyalty_enabled || shop.suspended) return json({ok: false, error: 'shop'}, 404);
  const {data: customer} = await db
    .from('nfc_customers')
    .select(CUSTOMER_FIELDS)
    .eq('business_id', shop.id)
    .eq('token_hash', await sha256(cardToken))
    .maybeSingle();
  if (!customer) return json({ok: false, error: 'card'}, 404);
  // Remember the card's language for the birthday job.
  const passLang = action === 'save' ? lang : String(customer.wallet_lang || lang);
  if (action === 'save' && customer.wallet_lang !== lang) {
    await db.from('nfc_customers').update({wallet_lang: lang}).eq('id', customer.id);
  }

  try {
    const pass = await buildPass(db, shop, customer, passLang);
    const token = await accessToken(key);
    if (action === 'sync') {
      // Only refreshes cards the customer already saved.
      const exists = await upsert(token, 'loyaltyObject', pass.loyaltyObject, true);
      if (exists) await upsert(token, 'loyaltyClass', pass.loyaltyClass);
      if (exists && pass.birthday) await db.from('nfc_customers').update({birthday_year: pass.year}).eq('id', customer.id);
      return json({ok: true, saved: exists});
    }
    await upsert(token, 'loyaltyClass', pass.loyaltyClass);
    await upsert(token, 'loyaltyObject', pass.loyaltyObject);
    const jwt = await signJwt(key, {
      iss: key.client_email,
      aud: 'google',
      typ: 'savetowallet',
      origins: [SITE],
      payload: {loyaltyObjects: [{id: pass.objectId}]},
    });
    return json({ok: true, url: `https://pay.google.com/gp/v/save/${jwt}`});
  } catch (e) {
    console.error(String(e));
    return json({ok: false, error: 'wallet', detail: String(e).slice(0, 300)}, 502);
  }
});
