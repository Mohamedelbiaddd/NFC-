// Shared helpers for the loyalty pages (/c/<shop> for customers and
// /s/<shop> for the shop owner).
import {lang} from '/i18n.mjs';

export const INDUSTRIES = {
  barber: {icon: '✂️', unit: {ar: 'زيارة', en: 'visit', fr: 'visite', it: 'visita'}},
  beauty: {icon: '💅', unit: {ar: 'زيارة', en: 'visit', fr: 'visite', it: 'visita'}},
  carwash: {icon: '🚗', unit: {ar: 'غسلة', en: 'wash', fr: 'lavage', it: 'lavaggio'}},
  bakery: {icon: '🥐', unit: {ar: 'شراء', en: 'purchase', fr: 'achat', it: 'acquisto'}},
  cafe: {icon: '☕', unit: {ar: 'كوب', en: 'cup', fr: 'café', it: 'caffè'}},
  snack: {icon: '🍕', unit: {ar: 'طلب', en: 'order', fr: 'commande', it: 'ordine'}},
  other: {icon: '⭐', unit: {ar: 'زيارة', en: 'visit', fr: 'visite', it: 'visita'}},
};
export function industry(shop) {
  return INDUSTRIES[shop?.industry] ?? INDUSTRIES.other;
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
