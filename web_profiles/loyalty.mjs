// Shared helpers for the loyalty pages (/c/<shop> for customers and
// /s/<shop> for the shop owner).
import {lang} from '/i18n.mjs';

export const INDUSTRIES = {
  barber: {icon: '✂️', label: {ar: 'حلاقة', fr: 'Barbier', en: 'Barber', it: 'Barbiere'}, unit: {ar: 'زيارة', en: 'visit', fr: 'visite', it: 'visita'}},
  beauty: {icon: '💅', label: {ar: 'تجميل', fr: 'Beauté', en: 'Beauty', it: 'Bellezza'}, unit: {ar: 'زيارة', en: 'visit', fr: 'visite', it: 'visita'}},
  carwash: {icon: '🚗', label: {ar: 'غسيل سيارات', fr: 'Lavage auto', en: 'Car wash', it: 'Autolavaggio'}, unit: {ar: 'غسلة', en: 'wash', fr: 'lavage', it: 'lavaggio'}},
  bakery: {icon: '🥐', label: {ar: 'مخبزة', fr: 'Boulangerie', en: 'Bakery', it: 'Panetteria'}, unit: {ar: 'شراء', en: 'purchase', fr: 'achat', it: 'acquisto'}},
  cafe: {icon: '☕', label: {ar: 'مقهى', fr: 'Café', en: 'Café', it: 'Caffè'}, unit: {ar: 'كوب', en: 'cup', fr: 'café', it: 'caffè'}},
  snack: {icon: '🍕', label: {ar: 'سناك / بيتزاريا', fr: 'Snack / Pizzeria', en: 'Snack / Pizzeria', it: 'Snack / Pizzeria'}, unit: {ar: 'طلب', en: 'order', fr: 'commande', it: 'ordine'}},
  other: {icon: '⭐', label: {ar: 'محل', fr: 'Commerce', en: 'Shop', it: 'Negozio'}, unit: {ar: 'زيارة', en: 'visit', fr: 'visite', it: 'visita'}},
};
export function industry(shop) {
  return INDUSTRIES[shop?.industry] ?? INDUSTRIES.other;
}
export function industryLabel(shop) {
  const l = industry(shop).label ?? {};
  return l[lang] ?? l.en ?? '';
}
export function unit(shop) {
  return industry(shop).unit[lang] ?? industry(shop).unit.en;
}

export async function loadConfig() {
  const res = await fetch('/config.json', {cache: 'no-store'});
  if (!res.ok) throw new Error('config');
  const config = await res.json();
  if (!/^https:\/\//.test(config?.supabaseUrl ?? '') || !config.publishableKey) throw new Error('config');
  return config;
}

export async function rpc(config, name, body) {
  const res = await fetch(`${config.supabaseUrl}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json', apikey: config.publishableKey},
    body: JSON.stringify(body),
    cache: 'no-store',
  });
  if (!res.ok) throw new Error('rpc ' + res.status);
  const text = await res.text();
  return text ? JSON.parse(text) : null;
}

export function slugFrom(prefix) {
  const m = new RegExp(`^/${prefix}/([a-z0-9]+(?:-[a-z0-9]+)*)/?$`).exec(location.pathname);
  return m && m[1].length >= 3 && m[1].length <= 63 ? m[1] : null;
}

export function el(tag, text, cls) {
  const x = document.createElement(tag);
  if (text !== undefined && text !== null) x.textContent = text;
  if (cls) x.className = cls;
  return x;
}

export function safeImage(url, config) {
  try {
    const u = new URL(url), base = new URL(config.supabaseUrl);
    return u.origin === base.origin && u.pathname.startsWith('/storage/v1/object/public/') ? u.href : null;
  } catch {
    return null;
  }
}

export function applyColors(shop) {
  for (const [key, v] of [['primary_color', '--primary'], ['accent_color', '--accent']]) {
    if (/^#[0-9a-f]{6}$/i.test(shop?.[key] ?? '')) document.documentElement.style.setProperty(v, shop[key]);
  }
}

export function toast(text, bad) {
  const t = el('div', text, 'toast' + (bad ? ' bad' : ''));
  document.body.append(t);
  setTimeout(() => t.remove(), 3500);
}

export function storage(key, value) {
  try {
    if (value === undefined) return localStorage.getItem(key);
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch {
    /* private mode: the page still works for this visit */
  }
  return null;
}

// Stamp row: `goal` paid stamps + one green reward slot.
// `goal` is the customer's own (locked) goal; the shop's goal is a fallback.
export function stampRow(shop, stamps, nextFree, customerGoal) {
  const goal = Number(customerGoal) || Number(shop.goal) || 5;
  const row = el('div', undefined, 'stamps');
  const icon = industry(shop).icon;
  for (let i = 0; i < goal; i++) {
    row.append(el('span', i < stamps ? icon : '', 'stamp' + (i < stamps ? ' on' : '')));
  }
  row.append(el('span', '🎁', 'stamp gift' + (nextFree ? ' ready' : '')));
  return row;
}

export function bannerStrip(shop, config) {
  const urls = (Array.isArray(shop.banners) ? shop.banners : []).map(u => safeImage(u, config)).filter(Boolean);
  if (!urls.length) return null;
  const strip = el('div', undefined, 'banners');
  for (const url of urls) {
    const img = el('img');
    img.src = url;
    img.loading = 'lazy';
    img.referrerPolicy = 'no-referrer';
    img.alt = '';
    strip.append(img);
  }
  return strip;
}

// Customer card: round numbered slots + a gift slot. `fresh` animates the
// slot that was just stamped.
export function slotsGrid(goal, stamps, nextFree, fresh = -1) {
  const grid = el('div', undefined, 'slots');
  const n = Math.max(1, Number(goal) || 5);
  for (let i = 0; i < n; i++) {
    const on = i < stamps;
    const slot = el('div', on ? '✓' : String(i + 1), 'slot' + (on ? ' on' : '') + (i === fresh ? ' new' : ''));
    slot.dataset.n = String(i + 1);
    grid.append(slot);
  }
  grid.append(el('div', '🎁', 'slot gift' + (nextFree ? ' ready' : '')));
  return grid;
}

// Owner list: numbered circles 1..goal filled up to `stamps`, then the gift.
export function numbersRow(goal, stamps, nextFree) {
  const row = el('div', undefined, 'nums');
  const n = Math.max(1, Number(goal) || 5);
  for (let i = 0; i < n; i++) row.append(el('span', String(i + 1), 'num' + (i < stamps ? ' on' : '')));
  row.append(el('span', '🎁', 'num gift' + (nextFree ? ' ready' : '')));
  return row;
}

export function initials(name) {
  return Array.from(String(name ?? '').trim())[0]?.toUpperCase() ?? '•';
}

export function formatDate(iso, lang) {
  try {
    return new Date(iso + 'T12:00:00').toLocaleDateString(lang === 'ar' ? 'ar-MA' : lang, {weekday: 'long', day: 'numeric', month: 'long'});
  } catch {
    return iso;
  }
}

/* ---------- Weekly opening hours (Monday first) ---------- */
const MONDAY = new Date(Date.UTC(2024, 0, 1, 12)); // a Monday

export function dayName(i, lng, style = 'long') {
  const d = new Date(MONDAY.getTime() + i * 86400000);
  try { return new Intl.DateTimeFormat(lng === 'ar' ? 'ar-MA' : lng, {weekday: style, timeZone: 'UTC'}).format(d); }
  catch { return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i]; }
}

export const todayIndex = () => (new Date().getDay() + 6) % 7;

export function validWeek(week) {
  return Array.isArray(week) && week.length === 7;
}

/** true / false when the week is known, null otherwise. */
export function openNow(week) {
  if (!validWeek(week)) return null;
  const now = new Date();
  const minutes = now.getHours() * 60 + now.getMinutes();
  const toMin = s => { const [h, m] = s.split(':').map(Number); return h * 60 + m; };
  const today = week[todayIndex()];
  const yesterday = week[(todayIndex() + 6) % 7];
  if (today) {
    const o = toMin(today.o), c = toMin(today.c);
    if (c > o ? minutes >= o && minutes < c : minutes >= o || minutes < c) {
      if (c > o || minutes >= o) return true;
    }
  }
  if (yesterday) {
    const o = toMin(yesterday.o), c = toMin(yesterday.c);
    if (c <= o && minutes < c) return true; // open past midnight
  }
  return false;
}

/* ---------- Shop links (phone, WhatsApp, social networks) ---------- */
const SOCIAL = {
  phone: {icon: '📞', color: '#2563eb'},
  whatsapp: {icon: '💬', color: '#25d366'},
  instagram: {icon: '📸', color: 'linear-gradient(45deg,#f58529,#dd2a7b,#8134af)'},
  tiktok: {icon: '🎵', color: '#111'},
  facebook: {icon: '👍', color: '#1877f2'},
  snapchat: {icon: '👻', color: '#fffc00', ink: '#111'},
  youtube: {icon: '▶️', color: '#ff0000'},
  website: {icon: '🌐', color: '#0ea5e9'},
  maps: {icon: '📍', color: '#ea4335'},
  email: {icon: '✉️', color: '#6366f1'},
};
export const SOCIAL_TYPES = Object.keys(SOCIAL);

function httpsUrl(value, hosts) {
  try {
    const u = new URL(value);
    if (u.protocol !== 'https:') return null;
    if (hosts && !hosts.some(h => u.hostname === h || u.hostname.endsWith('.' + h))) return null;
    return u.href;
  } catch { return null; }
}

/** {href, icon, color, ink} for one link, or null when the value is not usable. */
export function socialLink(type, raw) {
  const value = String(raw ?? '').trim();
  const meta = SOCIAL[type];
  if (!meta || !value) return null;
  const handle = value.replace(/^@/, '').replace(/[^A-Za-z0-9._-]/g, '');
  const digits = value.replace(/[^0-9]/g, '');
  let href = null;
  switch (type) {
    case 'phone': href = digits.length >= 6 ? 'tel:' + value.replace(/[^+0-9]/g, '') : null; break;
    case 'whatsapp': href = digits.length >= 6 ? `https://wa.me/${digits}` : httpsUrl(value, ['wa.me', 'whatsapp.com']); break;
    case 'email': href = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value) ? 'mailto:' + value : null; break;
    case 'instagram': href = httpsUrl(value, ['instagram.com']) ?? (handle ? `https://instagram.com/${handle}` : null); break;
    case 'tiktok': href = httpsUrl(value, ['tiktok.com']) ?? (handle ? `https://www.tiktok.com/@${handle}` : null); break;
    case 'facebook': href = httpsUrl(value, ['facebook.com', 'fb.com', 'fb.me']) ?? (handle ? `https://facebook.com/${handle}` : null); break;
    case 'snapchat': href = httpsUrl(value, ['snapchat.com']) ?? (handle ? `https://snapchat.com/add/${handle}` : null); break;
    case 'youtube': href = httpsUrl(value, ['youtube.com', 'youtu.be']) ?? (handle ? `https://youtube.com/@${handle}` : null); break;
    default: href = httpsUrl(value);
  }
  return href ? {href, ...meta} : null;
}
