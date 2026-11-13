// TapMaroc landing page: language switch (ar / fr / en), live card designer
// with made-up sample data, WhatsApp ordering and small UI touches.
// Static only: it talks to no database.

// Orders and questions arrive on this WhatsApp number (digits only). The
// admin can change it (and every text) from the hidden editor: /#studio.
const DEFAULT_WHATSAPP = '393295586046';
let CONTENT = {};      // published overrides {ar:{key:text}, fr:{}, en:{}, settings:{}}
const DRAFT = {ar: {}, fr: {}, en: {}, it: {}}; // unsaved edits in the editor
let CONFIG = null;
const whatsapp = () => DRAFT.whatsapp ?? CONTENT.settings?.whatsapp ?? DEFAULT_WHATSAPP;

import {T, TITLES, DESCS} from '/home-text.mjs';

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const h = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };

// ---------------------------------------------------------------- i18n
// Arabic lives in the HTML; French and English here, keyed by data-i.
const AR = {};
// On / the page itself is Arabic; the /fr, /en, /it pages carry the Arabic texts.
const AR_JSON = document.getElementById('ar-text');
if (AR_JSON) Object.assign(AR, JSON.parse(AR_JSON.textContent));
else $$('[data-i]').forEach((e) => { AR[e.dataset.i] = e.textContent; });
const SOON = {ar: 'قريباً', fr: 'Bientôt', en: 'Soon', it: 'Presto'};
const AR_DESC = AR.__desc ?? document.querySelector('meta[name=description]')?.content ?? '';
let lang = 'ar';
const base = (k, l = lang) => (l === 'ar' ? AR[k] : T[l][k]) ?? AR[k] ?? k;
const t = (k) => DRAFT[lang][k] ?? CONTENT[lang]?.[k] ?? base(k);
const pick = (o) => o?.[lang] ?? (lang === 'it' ? o?.en ?? o?.fr : undefined) ?? o?.ar ?? '';
const L = (ar, fr, en, it) => ({ar, fr, en, it})[lang] ?? en;

// ---------------------------------------------------------------- sample data
// Made-up people and numbers from around the world, only for the live preview.
// Placeholders only: no real-looking person or phone number is ever shown.
const PEOPLE = [
  {ar: 'اسمك هنا', fr: 'Votre Nom', en: 'Your Name', it: 'Il Tuo Nome'},
];
const CITIES = [
  {ar: 'الدار البيضاء', fr: 'Casablanca', en: 'Casablanca', cc: '+212 6'},
  {ar: 'باريس', fr: 'Paris', en: 'Paris', it: 'Parigi', cc: '+33 6'},
  {ar: 'دبي', fr: 'Dubaï', en: 'Dubai', it: 'Dubai', cc: '+971 50'},
  {ar: 'روما', fr: 'Rome', en: 'Rome', it: 'Roma', cc: '+39 3'},
  {ar: 'لندن', fr: 'Londres', en: 'London', it: 'Londra', cc: '+44 7'},
  {ar: 'مدريد', fr: 'Madrid', en: 'Madrid', cc: '+34 6'},
  {ar: 'مونتريال', fr: 'Montréal', en: 'Montreal', cc: '+1 514'},
];
// Example number and city follow the page language; digits stay hidden.
const DEMO = {
  ar: {phone: '+212 6 ** ** ** **', city: 0},
  fr: {phone: '+33 6 ** ** ** **', city: 1},
  en: {phone: '+44 7*** ******', city: 4},
  it: {phone: '+39 3** *** ****', city: 3},
};
const demo = () => DEMO[lang] ?? DEMO.ar;

const SHOP_TYPES = [
  {id: 'barber', e: '✂️', name: {ar: 'حلاق', fr: 'Barbier', en: 'Barber', it: 'Barbiere'}, shop: {ar: 'صالون الأناقة', fr: 'Salon Élégance', en: 'Elegance Barber', it: 'Barberia Eleganza'}, reward: {ar: 'حلاقة مجانية', fr: 'Une coupe offerte', en: 'A free haircut', it: 'Un taglio gratis'}, turn: true},
  {id: 'cafe', e: '☕', name: {ar: 'مقهى', fr: 'Café', en: 'Café', it: 'Bar'}, shop: {ar: 'مقهى الأطلس', fr: 'Café Atlas', en: 'Atlas Café', it: 'Caffè Atlas'}, reward: {ar: 'قهوة مجانية', fr: 'Un café offert', en: 'A free coffee', it: 'Un caffè gratis'}},
  {id: 'bakery', e: '🥐', name: {ar: 'مخبزة وحلويات', fr: 'Boulangerie', en: 'Bakery', it: 'Panetteria'}, shop: {ar: 'مخبزة السعادة', fr: 'Boulangerie Saâda', en: 'Saada Bakery', it: 'Panetteria Saada'}, reward: {ar: 'علبة حلويات مجانية', fr: 'Une boîte de pâtisseries', en: 'A free box of pastries', it: 'Una scatola di dolci gratis'}},
  {id: 'carwash', e: '🚗', name: {ar: 'غسل السيارات', fr: 'Lavage auto', en: 'Car wash', it: 'Autolavaggi'}, shop: {ar: 'لافاج النجمة', fr: 'Lavage Najma', en: 'Najma Car Wash', it: 'Autolavaggio Najma'}, reward: {ar: 'غسلة كاملة مجانية', fr: 'Un lavage complet offert', en: 'A free full wash', it: 'Un lavaggio completo gratis'}},
  {id: 'beauty', e: '💅', name: {ar: 'صالون تجميل', fr: 'Institut de beauté', en: 'Beauty salon', it: 'Centro estetico'}, shop: {ar: 'صالون ياسمين', fr: 'Institut Yasmine', en: 'Yasmine Beauty', it: 'Estetica Yasmine'}, reward: {ar: 'جلسة عناية مجانية', fr: 'Un soin offert', en: 'A free treatment', it: 'Un trattamento gratis'}, turn: true},
  {id: 'snack', e: '🍕', name: {ar: 'سناك / بيتزاريا', fr: 'Snack / Pizzeria', en: 'Snack / Pizzeria', it: 'Snack / Pizzeria'}, shop: {ar: 'بيتزا الريف', fr: 'Pizza Rif', en: 'Rif Pizza', it: 'Pizzeria Rif'}, reward: {ar: 'بيتزا مجانية', fr: 'Une pizza offerte', en: 'A free pizza', it: 'Una pizza gratis'}},
  {id: 'gym', e: '🏋️', name: {ar: 'قاعة رياضة', fr: 'Salle de sport', en: 'Gym', it: 'Palestra'}, shop: {ar: 'نادي القوة', fr: 'Club Force', en: 'Force Gym', it: 'Palestra Force'}, reward: {ar: 'أسبوع مجاني', fr: 'Une semaine offerte', en: 'A free week', it: 'Una settimana gratis'}},
];
const COLORS = ['#c81e2c', '#138a45', '#1e3a8a', '#b7791f', '#6d28d9', '#1f2937', '#0e7490'];

const SECTORS = [
  {e: '✂️', n: {ar: 'الحلاقون', fr: 'Barbiers', en: 'Barbers', it: 'Barbieri'}, d: {ar: 'الدور، الحجز والولاء', fr: 'File, réservation, fidélité', en: 'Queue, booking, loyalty', it: 'Coda, prenotazioni, fedeltà'}},
  {e: '💅', n: {ar: 'صالونات التجميل', fr: 'Instituts de beauté', en: 'Beauty salons', it: 'Centri estetici'}, d: {ar: 'مواعيد وهدايا للزبونات', fr: 'Rendez-vous et cadeaux', en: 'Appointments and gifts', it: 'Appuntamenti e regali'}},
  {e: '☕', n: {ar: 'المقاهي', fr: 'Cafés', en: 'Cafés', it: 'Bar e caffetterie'}, d: {ar: 'القهوة العاشرة مجانية', fr: 'Le 10e café offert', en: 'The 10th coffee is free', it: 'Il 10° caffè è gratis'}},
  {e: '🥐', n: {ar: 'المخابز والحلويات', fr: 'Boulangeries', en: 'Bakeries', it: 'Panetterie e pasticcerie'}, d: {ar: 'زبائن يعودون كل يوم', fr: 'Des clients chaque jour', en: 'Customers every day', it: 'Clienti ogni giorno'}},
  {e: '🚗', n: {ar: 'غسل السيارات', fr: 'Lavage auto', en: 'Car wash', it: 'Autolavaggi'}, d: {ar: 'غسلات مجانية للأوفياء', fr: 'Lavages offerts', en: 'Free washes for regulars', it: 'Lavaggi gratis ai clienti fedeli'}},
  {e: '🏋️', n: {ar: 'القاعات الرياضية', fr: 'Salles de sport', en: 'Gyms', it: 'Palestre'}, d: {ar: 'متابعة الحضور والهدايا', fr: 'Présences et cadeaux', en: 'Attendance and rewards', it: 'Presenze e premi'}},
  {e: '🛠️', n: {ar: 'الحرفيون', fr: 'Artisans', en: 'Craftsmen', it: 'Artigiani'}, d: {ar: 'كهربائي، سباك، نجار، دهّان…', fr: 'Électricien, plombier, peintre…', en: 'Electrician, plumber, painter…', it: 'Elettricista, idraulico, imbianchino…'}},
  {e: '💼', n: {ar: 'المهن الحرة والشركات', fr: 'Professions et entreprises', en: 'Professionals and companies', it: 'Professionisti e aziende'}, d: {ar: 'بطاقات أعمال أنيقة', fr: 'Cartes de visite élégantes', en: 'Elegant business cards', it: 'Biglietti da visita eleganti'}},
  {e: '🛍️', n: {ar: 'المحلات التجارية', fr: 'Boutiques', en: 'Shops', it: 'Negozi'}, d: {ar: 'ولاء وعروض للزبائن', fr: 'Fidélité et offres', en: 'Loyalty and offers', it: 'Fedeltà e offerte'}},
  {e: '🍽️', n: {ar: 'المطاعم', fr: 'Restaurants', en: 'Restaurants', it: 'Ristoranti'}, d: {ar: 'القوائم الرقمية', fr: 'Menus digitaux', en: 'Digital menus', it: 'Menu digitali'}, soon: true},
];

// ---------------------------------------------------------------- state
const state = {
  mode: 'vcard', design: 'barber', person: 0, city: 0, phone: DEMO.ar.phone,
  name: null, job: null, cityText: null, phoneText: null, // user edits (null = sample)
  shopType: 'barber', shop: null, reward: null, stamps: 10, color: COLORS[0],
};
let DESIGNS = [];

// ---------------------------------------------------------------- previews
function shade(hex, k) {
  const n = parseInt(hex.slice(1), 16);
  const ch = (v) => Math.max(0, Math.min(255, Math.round(k >= 0 ? v + (255 - v) * k : v * (1 + k))));
  return `#${((1 << 24) | (ch((n >> 16) & 255) << 16) | (ch((n >> 8) & 255) << 8) | ch(n & 255)).toString(16).slice(1)}`;
}
const light = (hex) => { const n = parseInt(hex.slice(1), 16); return (0.299 * ((n >> 16) & 255) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255)) / 255 > 0.6; };

function vcardScreen(d, data) {
  const p = d?.palette ?? {surface: '#3e1720', text: '#fff', muted: '#e5c9c9', accent: '#f5ce87', button: '#5a2230', buttonText: '#fff'};
  const lt = light(p.surface);
  const root = h('div', `vc${d?.buttonStyle === 'pill' ? ' vc-shape-pill' : ''}`);
  root.style.cssText = `--vbg:${shade(p.surface, lt ? -0.04 : -0.3)};--vcard:${p.surface};--vtext:${p.text};--vmuted:${p.muted};--vaccent:${p.accent};--vink:${light(p.accent) ? '#111' : '#fff'};--vline:${lt ? '#0000001a' : '#ffffff1f'}`;
  const cover = h('div', 'vc-cover');
  if (d?.assets?.cover) cover.style.backgroundImage = `url(${d.assets.cover})`;
  else cover.style.background = `linear-gradient(135deg,${p.accent},${p.button})`;
  const ava = h('div', 'vc-ava', Array.from(data.name.trim())[0] ?? 'T');
  const name = h('h4', '', data.name);
  const job = h('p', 'job', data.job);
  const btns = h('div', 'row-btns');
  btns.append(h('span', '', L('تبادل الاتصال', 'Échanger le contact', 'Exchange contact', 'Scambia contatto')),
    h('span', '', L('حفظ الرقم', 'Enregistrer', 'Save contact', 'Salva contatto')));
  const rows = h('div', 'rows');
  const row = (i, txt, ltr) => { const r = h('div'); const ic = h('i', '', i); const s = h('span', '', txt); if (ltr) s.dir = 'ltr'; r.append(ic, s); rows.append(r); };
  row('📞', data.phone, true);
  row('💬', 'WhatsApp', true);
  row('📍', data.city);
  row('✉️', 'contact@exemple.com', true);
  const soc = h('div', 'socials');
  ['f', 'in', '◎', '♪'].forEach((x) => soc.append(h('span', '', x)));
  root.append(cover, ava, name, job, btns, rows, soc);
  if (d?.assets?.footer) { const f = h('div', 'foot-orn'); f.style.backgroundImage = `url(${d.assets.footer})`; root.append(f); }
  return root;
}

function loyaltyScreen(data) {
  const type = SHOP_TYPES.find((x) => x.id === data.type) ?? SHOP_TYPES[0];
  const root = h('div', 'ly');
  root.style.setProperty('--lc', data.color);
  const card = h('div', 'ly-card');
  const head = h('div', 'ly-head');
  const logo = h('div', 'ly-logo', type.e);
  const tt = h('div'); tt.append(h('b', '', data.shop), h('small', '', data.city));
  head.append(logo, tt);
  const who = h('div', 'ly-name');
  who.append(document.createTextNode(L('بطاقة الزبون', 'Carte client', 'Customer card', 'Tessera cliente')), h('b', '', data.customer));
  const n = data.stamps, got = Math.max(1, Math.round(n * 0.6));
  const grid = h('div', 'stamps');
  grid.style.gridTemplateColumns = `repeat(${n > 10 ? 6 : 5},1fr)`;
  for (let i = 0; i < n; i++) grid.append(h('div', `stamp${i < got ? ' on' : ''}${i === n - 1 ? ' gift' : ''}`, i === n - 1 ? '🎁' : type.e));
  const bar = h('div', 'ly-bar'); const fill = h('i'); fill.style.width = `${(got / n) * 100}%`; bar.append(fill);
  const rw = h('div', 'ly-reward');
  rw.append(h('span', '', `🎁 ${data.reward}`), h('span', '', `${got}/${n}`));
  card.append(head, who, grid, bar, rw);
  const tile = h('div', 'ly-tile');
  const box = h('div');
  if (type.turn) {
    tile.append(h('span', 'big', '#3'));
    box.append(h('b', '', L('دورك قريب', 'Votre tour approche', 'Your turn is close', 'Il tuo turno è vicino')),
      h('small', '', L('سننبّهك قبل دورك', 'On vous prévient avant', 'We’ll notify you before', 'Ti avvisiamo prima')));
  } else {
    tile.append(h('span', 'big', `${n - got}`));
    box.append(h('b', '', L('زيارات متبقية للهدية', 'visites avant le cadeau', 'visits to your reward', 'visite al premio')),
      h('small', '', L('آخر زيارة: اليوم', 'Dernière visite : aujourd’hui', 'Last visit: today', 'Ultima visita: oggi')));
  }
  tile.append(box);
  const wallet = h('div', 'ly-wallet', L('＋ إضافة إلى Google Wallet', '＋ Ajouter à Google Wallet', '＋ Add to Google Wallet', '＋ Aggiungi a Google Wallet'));
  root.append(card, tile, wallet);
  return root;
}

// ---------------------------------------------------------------- builder
const designById = (id) => DESIGNS.find((d) => d.id === id);
function vData() {
  const d = designById(state.design);
  return {
    name: state.name ?? pick(PEOPLE[state.person]),
    job: state.job ?? (pick(d?.sampleSubtitleI18n) || pick(d?.name) || ''),
    phone: state.phoneText ?? state.phone,
    city: state.cityText ?? pick(CITIES[state.city]),
  };
}
function lData() {
  const type = SHOP_TYPES.find((x) => x.id === state.shopType);
  return {
    type: state.shopType, color: state.color, stamps: state.stamps,
    shop: state.shop ?? pick(type.shop), reward: state.reward ?? pick(type.reward),
    city: pick(CITIES[state.city]), customer: pick(PEOPLE[state.person]),
  };
}
function syncInputs() {
  const v = vData(), l = lData();
  $('#vName').value = v.name; $('#vJob').value = v.job; $('#vPhone').value = v.phone; $('#vCity').value = v.city;
  $('#lShop').value = l.shop; $('#lReward').value = l.reward; $('#stOut').value = state.stamps;
}
function renderPreview() {
  const screen = $('#screen');
  screen.replaceChildren(state.mode === 'vcard' ? vcardScreen(designById(state.design), vData()) : loyaltyScreen(lData()));
  $$('.design').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.id === state.design)));
  $$('#sectorsPick .chip').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.id === state.shopType)));
  $$('#swatches button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.c === state.color)));
  $('#orderDesign').href = waLink(orderText());
}
// Thumbnail for designs without a picture: a tiny mock of the card itself.
function miniCard(p) {
  const m = h('span', 'mini');
  m.style.cssText = `--m-bg:${p.surface};--m-tx:${p.text};--m-mu:${p.muted};--m-ac:${p.accent};--m-bt:${p.button}`;
  m.append(h('i', 'mi-av'), h('i', 'mi-l1'), h('i', 'mi-l2'), h('i', 'mi-bt'));
  return m;
}
function buildDesigns() {
  const box = $('#designs');
  box.replaceChildren();
  for (const d of DESIGNS) {
    const b = h('button', 'design'); b.type = 'button'; b.dataset.id = d.id; b.title = pick(d.name);
    if (d.assets?.cover) { const i = h('img'); i.src = d.assets.cover; i.alt = ''; i.loading = 'lazy'; b.append(i); }
    else b.append(miniCard(d.palette));
    b.append(h('span', 'design-name', pick(d.name)));
    b.addEventListener('click', () => { state.design = d.id; state.job = null; syncInputs(); renderPreview(); });
    box.append(b);
  }
}
function buildShopTypes() {
  const box = $('#sectorsPick');
  box.replaceChildren();
  for (const s of SHOP_TYPES) {
    const b = h('button', 'chip', `${s.e} ${pick(s.name)}`); b.type = 'button'; b.dataset.id = s.id;
    b.addEventListener('click', () => { state.shopType = s.id; state.shop = null; state.reward = null; syncInputs(); renderPreview(); });
    box.append(b);
  }
}
function buildSwatches() {
  const box = $('#swatches');
  for (const c of COLORS) {
    const b = h('button'); b.type = 'button'; b.dataset.c = c; b.style.background = c; b.setAttribute('aria-label', c);
    b.addEventListener('click', () => { state.color = c; renderPreview(); });
    box.append(b);
  }
}
function setMode(m) {
  state.mode = m;
  $$('.seg button').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.mode === m)));
  $('#formVcard').hidden = m !== 'vcard';
  $('#formLoyalty').hidden = m !== 'loyalty';
  renderPreview();
}

// ---------------------------------------------------------------- WhatsApp
const waLink = (text) => `https://wa.me/${whatsapp()}?text=${encodeURIComponent(text)}`;
function orderText() {
  if (state.mode === 'vcard') {
    const d = designById(state.design), v = vData();
    return lang === 'fr'
      ? `Bonjour TapMaroc 👋\nJe veux une carte de visite NFC.\nDesign : ${pick(d?.name)}\nNom : ${v.name}\nMétier : ${v.job}\nVille : ${v.city}`
      : lang === 'en'
        ? `Hello TapMaroc 👋\nI’d like an NFC business card.\nDesign: ${pick(d?.name)}\nName: ${v.name}\nProfession: ${v.job}\nCity: ${v.city}`
        : lang === 'it'
          ? `Ciao TapMaroc 👋\nVorrei un biglietto da visita NFC.\nDesign: ${pick(d?.name)}\nNome: ${v.name}\nProfessione: ${v.job}\nCittà: ${v.city}`
        : `مرحباً TapMaroc 👋\nأريد بطاقة أعمال NFC.\nالتصميم: ${pick(d?.name)}\nالاسم: ${v.name}\nالمهنة: ${v.job}\nالمدينة: ${v.city}`;
  }
  const l = lData(), type = SHOP_TYPES.find((x) => x.id === state.shopType);
  return lang === 'fr'
    ? `Bonjour TapMaroc 👋\nJe veux une carte de fidélité pour mon commerce.\nType : ${pick(type.name)}\nNom : ${l.shop}\nCadeau : ${l.reward} après ${l.stamps} tampons`
    : lang === 'en'
      ? `Hello TapMaroc 👋\nI’d like a loyalty card for my shop.\nType: ${pick(type.name)}\nName: ${l.shop}\nReward: ${l.reward} after ${l.stamps} stamps`
      : lang === 'it'
        ? `Ciao TapMaroc 👋\nVorrei una tessera fedeltà per il mio negozio.\nTipo: ${pick(type.name)}\nNome: ${l.shop}\nPremio: ${l.reward} dopo ${l.stamps} timbri`
      : `مرحباً TapMaroc 👋\nأريد بطاقة ولاء لمحلي.\nالنوع: ${pick(type.name)}\nاسم المحل: ${l.shop}\nالهدية: ${l.reward} بعد ${l.stamps} طوابع`;
}
const PLAN_MSG = {
  app: {ar: 'مرحباً TapMaroc 👋\nأريد الاشتراك في تطبيق TapMaroc.', fr: 'Bonjour TapMaroc 👋\nJe veux m’abonner à l’application TapMaroc.', en: 'Hello TapMaroc 👋\nI’d like to subscribe to the TapMaroc app.', it: 'Ciao TapMaroc 👋\nVorrei abbonarmi all’app TapMaroc.'},
  agent: {ar: 'مرحباً TapMaroc 👋\nأريد العمل معكم كوكيل.', fr: 'Bonjour TapMaroc 👋\nJe souhaite devenir agent.', en: 'Hello TapMaroc 👋\nI’d like to become an agent.', it: 'Ciao TapMaroc 👋\nVorrei diventare agente.'},
  trial: {ar: 'مرحباً TapMaroc 👋\nأريد تجربة مجانية لمحلّي عند الإطلاق.', fr: 'Bonjour TapMaroc 👋\nJe veux l’essai gratuit pour mon commerce dès le lancement.', en: 'Hello TapMaroc 👋\nI’d like the free trial for my shop when it launches.', it: 'Ciao TapMaroc 👋\nVorrei la prova gratuita per il mio negozio al lancio.'},
  p1: {ar: 'مرحباً TapMaroc 👋\nأريد طلب «بطاقة الأعمال».', fr: 'Bonjour TapMaroc 👋\nJe souhaite commander la « Carte de visite ».', en: 'Hello TapMaroc 👋\nI’d like to order the “Business card”.', it: 'Ciao TapMaroc 👋\nVorrei ordinare il « Biglietto da visita ».'},
  p2: {ar: 'مرحباً TapMaroc 👋\nأريد طلب «باقة المحل».', fr: 'Bonjour TapMaroc 👋\nJe souhaite commander la « Formule commerce ».', en: 'Hello TapMaroc 👋\nI’d like to order the “Shop plan”.', it: 'Ciao TapMaroc 👋\nVorrei ordinare il « Pacchetto negozio ».'},
  p3: {ar: 'مرحباً TapMaroc 👋\nأريد طلب «باقة الشركات».', fr: 'Bonjour TapMaroc 👋\nJe souhaite commander la « Formule entreprise ».', en: 'Hello TapMaroc 👋\nI’d like to order the “Business plan”.', it: 'Ciao TapMaroc 👋\nVorrei ordinare il « Pacchetto aziende ».'},
  contact: {ar: 'مرحباً TapMaroc 👋\nأريد معلومات عن خدماتكم.', fr: 'Bonjour TapMaroc 👋\nJe voudrais des informations sur vos services.', en: 'Hello TapMaroc 👋\nI’d like some information about your services.', it: 'Ciao TapMaroc 👋\nVorrei informazioni sui vostri servizi.'},
};
const updateWaLinks = () => $$('a.wa').forEach((a) => { a.href = waLink(pick(PLAN_MSG[a.dataset.plan] ?? PLAN_MSG.contact)); });

// ---------------------------------------------------------------- sectors grid
function buildSectors() {
  const box = $('#sectorsGrid');
  box.replaceChildren();
  for (const s of SECTORS) {
    const c = h('div', 'sector reveal in');
    c.append(h('span', 'e', s.e), h('b', '', pick(s.n)), h('small', '', pick(s.d)));
    if (s.soon) c.append(h('span', 'soon-pill', SOON[lang]));
    box.append(c);
  }
}

// ---------------------------------------------------------------- hero phone
let heroTick = 0;
function renderHero() {
  const screen = $('#heroScreen');
  if (!screen) return;
  const barber = designById('barber');
  const show = heroTick % 2 === 0
    ? vcardScreen(barber, {name: pick(PEOPLE[0]), job: pick(barber?.sampleSubtitleI18n) || '', phone: demo().phone, city: pick(CITIES[demo().city])})
    : loyaltyScreen({type: 'cafe', color: '#138a45', stamps: 10, shop: pick(SHOP_TYPES[1].shop), reward: pick(SHOP_TYPES[1].reward), city: pick(CITIES[2]), customer: pick(PEOPLE[0])});
  show.style.animation = 'fadeIn .6s ease';
  screen.replaceChildren(show);
}
const fade = document.createElement('style');
fade.textContent = '@keyframes fadeIn{from{opacity:0;transform:scale(.98)}to{opacity:1;transform:none}}';
document.head.append(fade);

// ---------------------------------------------------------------- language
function setLang(l) {
  lang = T[l] || l === 'ar' ? l : 'ar';
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
  $$('[data-i]').forEach((e) => { e.textContent = t(e.dataset.i); });
  $$('.langs button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.lang === lang)));
  $$('.pay-methods .off').forEach((e) => { e.dataset.soon = SOON[lang]; });
  document.title = TITLES[lang];
  try { localStorage.setItem('tm_lang', lang); } catch { /* private mode */ }
  // One address per language (/, /fr, /en) so search engines index each.
  const path = lang === 'ar' ? '/' : `/${lang}`;
  if (location.pathname !== path) history.replaceState(null, '', path + location.hash);
  $('link[rel=canonical]')?.setAttribute('href', `https://tapmaroc.com${path}`);
  const desc = lang === 'ar' ? AR_DESC : DESCS[lang];
  $('meta[name=description]')?.setAttribute('content', desc);
  state.phone = demo().phone; state.city = demo().city;
  buildDesigns(); buildShopTypes(); buildSectors(); syncInputs(); renderPreview(); renderHero(); updateWaLinks();
}

// ---------------------------------------------------------------- wiring
function wire() {
  $$('.langs button').forEach((b) => b.addEventListener('click', () => setLang(b.dataset.lang)));
  $$('.seg button').forEach((b) => b.addEventListener('click', () => setMode(b.dataset.mode)));
  const bind = (id, key) => $(id).addEventListener('input', (e) => { state[key] = e.target.value; renderPreview(); });
  bind('#vName', 'name'); bind('#vJob', 'job'); bind('#vPhone', 'phoneText'); bind('#vCity', 'cityText');
  bind('#lShop', 'shop'); bind('#lReward', 'reward');
  $('#stMinus').addEventListener('click', () => { state.stamps = Math.max(5, state.stamps - 1); syncInputs(); renderPreview(); });
  $('#stPlus').addEventListener('click', () => { state.stamps = Math.min(12, state.stamps + 1); syncInputs(); renderPreview(); });
  $('#shuffle').addEventListener('click', () => {
    if (DESIGNS.length > 1) {
      let next = state.design;
      while (next === state.design) next = DESIGNS[Math.floor(Math.random() * DESIGNS.length)].id;
      state.design = next; state.job = null;
    }
    if (state.mode === 'loyalty') {
      const i = SHOP_TYPES.findIndex((x) => x.id === state.shopType);
      state.shopType = SHOP_TYPES[(i + 1) % SHOP_TYPES.length].id; state.shop = state.reward = null;
    }
    syncInputs(); renderPreview();
  });
  const menu = $('#menu'), nav = $('#nav');
  menu.addEventListener('click', () => { const open = nav.classList.toggle('open'); menu.setAttribute('aria-expanded', String(open)); });
  $$('#nav a').forEach((a) => a.addEventListener('click', () => { nav.classList.remove('open'); menu.setAttribute('aria-expanded', 'false'); }));
  $('#year').textContent = new Date().getFullYear();

  const io = 'IntersectionObserver' in window
    ? new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }), {threshold: 0.12})
    : null;
  $$('.reveal').forEach((e) => (io ? io.observe(e) : e.classList.add('in')));

  if (!matchMedia('(prefers-reduced-motion: reduce)').matches) setInterval(() => { heroTick++; renderHero(); }, 4500);
}

async function start() {
  // E-mail confirmation / reset links may land here: hand them to the account page.
  if (/access_token=|error_description=/.test(location.hash)) { location.replace('/start' + location.hash); return; }
  const [designs, config] = await Promise.all([
    fetch('/card-themes.json').then((r) => (r.ok ? r.json() : {})).catch(() => ({})),
    fetch('/config.json', {cache: 'no-store'}).then((r) => (r.ok ? r.json() : null)).catch(() => null),
  ]);
  DESIGNS = designs.themes ?? [];
  CONFIG = config;
  CONTENT = await loadContent();
  buildSwatches();
  wire();
  let saved = null;
  try { saved = localStorage.getItem('tm_lang'); } catch { /* ignore */ }
  const nav = (navigator.language || '').slice(0, 2);
  const fromPath = /^\/(fr|en|it)\/?$/.exec(location.pathname)?.[1];
  // Search robots read each address in its own language (/ is Arabic);
  // people get their saved choice, else their phone's language (English
  // for languages we do not have).
  const robot = /bot|crawl|spider|slurp|lighthouse|inspect/i.test(navigator.userAgent);
  const guess = ['ar', 'fr', 'it'].includes(nav) ? nav : 'en';
  setLang(fromPath || (robot ? 'ar' : saved || guess));
  initStudio();
}

// ---------------------------------------------------------------- content
async function loadContent() {
  if (!CONFIG?.supabaseUrl) return {};
  try {
    const r = await fetch(`${CONFIG.supabaseUrl}/rest/v1/rpc/nfc_site_content`, {
      method: 'POST', headers: {'Content-Type': 'application/json', apikey: CONFIG.publishableKey}, body: '{}', cache: 'no-store',
    });
    const doc = r.ok ? await r.json() : {};
    return doc && typeof doc === 'object' ? doc : {};
  } catch { return {}; }
}

// ---------------------------------------------------------------- studio
// Hidden editor for the site owner: open tapmaroc.com/#studio (or tap the
// © line 5 times), sign in with the admin account, then click any text on
// the page to change it, in each language. Only a super admin can save:
// the database checks it, the hidden address is just a convenience.
const SESSION_KEY = 'tm_studio';
const getSession = () => { try { const s = JSON.parse(sessionStorage.getItem(SESSION_KEY) || 'null'); return s && s.exp > Date.now() / 1000 + 30 ? s : null; } catch { return null; } };
const setSession = (s) => { try { s ? sessionStorage.setItem(SESSION_KEY, JSON.stringify(s)) : sessionStorage.removeItem(SESSION_KEY); } catch { /* ignore */ } };
const S = {
  ar: {title: 'دخول الإدارة', email: 'البريد الإلكتروني', pass: 'كلمة المرور', go: 'دخول', cancel: 'إلغاء', bad: 'البريد أو كلمة المرور غير صحيحة.', notAdmin: 'هذا الحساب ليس حساب إدارة.', net: 'تعذّر الاتصال. حاول مجدداً.',
    bar: '✏️ وضع التعديل — اضغط على أي نص لتغييره', lang: 'اللغة', wa: 'واتساب', save: 'حفظ ونشر', saved: '✓ تم الحفظ والنشر', discard: 'إلغاء التغييرات', exit: 'خروج', changes: 'تغييرات غير محفوظة', expired: 'انتهت الجلسة، سجّل الدخول مجدداً.', waBad: 'رقم واتساب غير صحيح (أرقام فقط مع رمز الدولة).', reset: 'استرجاع النص الأصلي لهذا العنصر'},
  fr: {title: 'Accès administrateur', email: 'E-mail', pass: 'Mot de passe', go: 'Connexion', cancel: 'Annuler', bad: 'E-mail ou mot de passe incorrect.', notAdmin: 'Ce compte n’est pas administrateur.', net: 'Connexion impossible. Réessayez.',
    bar: '✏️ Mode édition — cliquez sur un texte pour le modifier', lang: 'Langue', wa: 'WhatsApp', save: 'Enregistrer et publier', saved: '✓ Enregistré et publié', discard: 'Annuler les modifications', exit: 'Quitter', changes: 'modifications non enregistrées', expired: 'Session expirée, reconnectez-vous.', waBad: 'Numéro WhatsApp invalide (chiffres avec indicatif).', reset: 'Rétablir le texte d’origine'},
  it: {title: 'Accesso amministratore', email: 'E-mail', pass: 'Password', go: 'Accedi', cancel: 'Annulla', bad: 'E-mail o password errata.', notAdmin: 'Questo account non è amministratore.', net: 'Connessione non riuscita. Riprova.',
    bar: '✏️ Modalità modifica — tocca un testo per cambiarlo', lang: 'Lingua', wa: 'WhatsApp', save: 'Salva e pubblica', saved: '✓ Salvato e pubblicato', discard: 'Annulla modifiche', exit: 'Esci', changes: 'modifiche non salvate', expired: 'Sessione scaduta, accedi di nuovo.', waBad: 'Numero WhatsApp non valido (solo cifre con prefisso).', reset: 'Ripristina il testo originale'},
  en: {title: 'Admin sign-in', email: 'Email', pass: 'Password', go: 'Sign in', cancel: 'Cancel', bad: 'Wrong email or password.', notAdmin: 'This account is not an admin.', net: 'Connection failed. Try again.',
    bar: '✏️ Edit mode — click any text to change it', lang: 'Language', wa: 'WhatsApp', save: 'Save & publish', saved: '✓ Saved and published', discard: 'Discard changes', exit: 'Exit', changes: 'unsaved changes', expired: 'Session expired, sign in again.', waBad: 'Invalid WhatsApp number (digits with country code).', reset: 'Restore the original text'},
};
const s_ = (k) => S[lang][k];
let studioOn = false;

async function api(path, body, token) {
  const r = await fetch(`${CONFIG.supabaseUrl}${path}`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json', apikey: CONFIG.publishableKey, ...(token ? {Authorization: `Bearer ${token}`} : {})},
    body: JSON.stringify(body ?? {}), cache: 'no-store',
  });
  const data = await r.json().catch(() => null);
  return {ok: r.ok, status: r.status, data};
}

function loginDialog() {
  const dlg = h('dialog', 'studio-login');
  const f = h('form');
  f.method = 'dialog';
  const title = h('h3', '', s_('title'));
  const email = h('input'); email.type = 'email'; email.required = true; email.autocomplete = 'username'; email.placeholder = s_('email'); email.dir = 'ltr';
  const pass = h('input'); pass.type = 'password'; pass.required = true; pass.autocomplete = 'current-password'; pass.placeholder = s_('pass'); pass.dir = 'ltr';
  const msg = h('p', 'studio-msg');
  const row = h('div', 'studio-row');
  const go = h('button', 'btn btn-red btn-sm', s_('go')); go.type = 'submit';
  const cancel = h('button', 'btn btn-ghost btn-sm', s_('cancel')); cancel.type = 'button';
  row.append(go, cancel);
  f.append(title, email, pass, msg, row);
  dlg.append(f);
  document.body.append(dlg);
  cancel.addEventListener('click', () => { dlg.close(); dlg.remove(); history.replaceState(null, '', location.pathname); });
  f.addEventListener('submit', async (e) => {
    e.preventDefault();
    go.disabled = true; msg.textContent = '…';
    try {
      const auth = await api('/auth/v1/token?grant_type=password', {email: email.value.trim(), password: pass.value});
      if (!auth.ok || !auth.data?.access_token) { msg.textContent = s_('bad'); return; }
      const token = auth.data.access_token;
      const admin = await api('/rest/v1/rpc/nfc_site_is_admin', {}, token);
      if (admin.data !== true) { msg.textContent = s_('notAdmin'); return; }
      setSession({token, exp: Math.floor(Date.now() / 1000) + (auth.data.expires_in ?? 3600)});
      pass.value = '';
      dlg.close(); dlg.remove();
      enterStudio();
    } catch { msg.textContent = s_('net'); } finally { go.disabled = false; }
  });
  dlg.showModal();
  email.focus();
}

function markEditable() {
  $$('[data-i]').forEach((e) => {
    try { e.contentEditable = 'plaintext-only'; } catch { e.contentEditable = 'true'; }
    if (e.contentEditable !== 'plaintext-only') e.contentEditable = 'true';
    e.spellcheck = false;
  });
}
function changedCount() { return ['ar', 'fr', 'en', 'it'].reduce((n, l) => n + Object.keys(DRAFT[l]).length, 0) + (DRAFT.whatsapp != null ? 1 : 0); }

function studioBar() {
  const bar = h('div', 'studio-bar');
  bar.id = 'studioBar';
  const info = h('b', '', s_('bar'));
  const count = h('span', 'studio-count');
  const wa = h('label', 'studio-wa');
  const waIn = h('input'); waIn.inputMode = 'numeric'; waIn.dir = 'ltr'; waIn.value = whatsapp(); waIn.maxLength = 15;
  wa.append(h('span', '', s_('wa')), waIn);
  waIn.addEventListener('input', () => { waIn.value = waIn.value.replace(/\D/g, ''); DRAFT.whatsapp = waIn.value; refreshCount(); updateWaLinks(); renderPreview(); });
  const save = h('button', 'btn btn-green btn-sm', s_('save'));
  const discard = h('button', 'btn btn-ghost btn-sm', s_('discard'));
  const exit = h('button', 'btn btn-ghost btn-sm', s_('exit'));
  const msg = h('span', 'studio-msg');
  bar.append(info, count, wa, save, discard, exit, msg);
  document.body.append(bar);
  function refreshCount() { const n = changedCount(); count.textContent = n ? `• ${n} ${s_('changes')}` : ''; save.disabled = !n; }
  refreshCount();
  bar.refresh = refreshCount;

  save.addEventListener('click', async () => {
    const ses = getSession();
    if (!ses) { msg.textContent = s_('expired'); exitStudio(); loginDialog(); return; }
    if (DRAFT.whatsapp != null && !/^[0-9]{8,15}$/.test(DRAFT.whatsapp)) { msg.textContent = s_('waBad'); return; }
    const doc = {ar: {...CONTENT.ar}, fr: {...CONTENT.fr}, en: {...CONTENT.en}, it: {...CONTENT.it}, settings: {...CONTENT.settings}};
    for (const l of ['ar', 'fr', 'en', 'it']) {
      for (const [k, v] of Object.entries(DRAFT[l])) {
        const text = v.replace(/\s+/g, ' ').trim();
        if (!text || text === base(k, l)) delete doc[l][k]; else doc[l][k] = text.slice(0, 2000);
      }
    }
    if (DRAFT.whatsapp != null) { if (DRAFT.whatsapp === DEFAULT_WHATSAPP) delete doc.settings.whatsapp; else doc.settings.whatsapp = DRAFT.whatsapp; }
    save.disabled = true; msg.textContent = '…';
    try {
      const r = await api('/rest/v1/rpc/nfc_site_save', {new_doc: doc}, ses.token);
      if (r.status === 401) { msg.textContent = s_('expired'); setSession(null); return; }
      if (!r.ok) { msg.textContent = r.data?.message || s_('net'); save.disabled = false; return; }
      CONTENT = r.data;
      for (const l of ['ar', 'fr', 'en', 'it']) DRAFT[l] = {};
      delete DRAFT.whatsapp;
      msg.textContent = s_('saved');
      setLang(lang);
      refreshCount();
    } catch { msg.textContent = s_('net'); save.disabled = false; }
  });
  discard.addEventListener('click', () => { for (const l of ['ar', 'fr', 'en', 'it']) DRAFT[l] = {}; delete DRAFT.whatsapp; waIn.value = whatsapp(); msg.textContent = ''; setLang(lang); refreshCount(); });
  exit.addEventListener('click', () => { setSession(null); exitStudio(); history.replaceState(null, '', location.pathname); });
}

function onEdit(e) {
  const el = e.target.closest?.('[data-i]');
  if (!studioOn || !el) return;
  DRAFT[lang][el.dataset.i] = el.textContent;
  // Same key used in several places (e.g. the "Soon" badges): keep them in step.
  $$(`[data-i="${CSS.escape(el.dataset.i)}"]`).forEach((o) => { if (o !== el) o.textContent = el.textContent; });
  $('#studioBar')?.refresh();
}
function blockClicks(e) {
  if (!studioOn) return;
  if (e.target.closest('#studioBar, .langs, .studio-login')) return;
  const a = e.target.closest('a, button, summary');
  if (a && (a.matches('[data-i]') || a.querySelector('[data-i]') || a.closest('[data-i]'))) e.preventDefault();
}
function blockKeys(e) {
  if (studioOn && e.key === 'Enter' && e.target.closest?.('[data-i]')) e.preventDefault();
}

function enterStudio() {
  studioOn = true;
  document.body.classList.add('studio');
  markEditable();
  studioBar();
}
function exitStudio() {
  studioOn = false;
  document.body.classList.remove('studio');
  $$('[data-i]').forEach((e) => e.removeAttribute('contenteditable'));
  $('#studioBar')?.remove();
  for (const l of ['ar', 'fr', 'en', 'it']) DRAFT[l] = {};
  delete DRAFT.whatsapp;
  setLang(lang);
}
function openStudio() {
  if (studioOn || !CONFIG?.supabaseUrl) return;
  if (getSession()) enterStudio(); else if (!$('.studio-login')) loginDialog();
}
function initStudio() {
  document.addEventListener('input', onEdit, true);
  document.addEventListener('click', blockClicks, true);
  document.addEventListener('keydown', blockKeys, true);
  window.addEventListener('hashchange', () => { if (location.hash === '#studio') openStudio(); });
  let taps = 0, timer;
  $('.foot p')?.addEventListener('click', () => { taps++; clearTimeout(timer); timer = setTimeout(() => { taps = 0; }, 1500); if (taps >= 5) { taps = 0; openStudio(); } });
  if (location.hash === '#studio') openStudio();
}

start();
