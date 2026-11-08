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
export function stampRow(shop, stamps, nextFree) {
  const goal = Number(shop.goal) || 5;
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
