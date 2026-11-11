// The digital business card (/p/<slug> of kind "vcard"): a cover, the photo
// with the company logo, name and job, two main buttons (exchange contact,
// save contact), contact rows, social links and a quote. The card owner picks
// the colour theme, an own accent colour if he wants and the shape (layout).
import {safeHttps, safeImageUrl, vcardEscape} from '/routing.mjs';

export const CARD_THEMES = {
  violet:  {bg: '#07040f', card: '#120a24', line: '#ffffff1f', text: '#ffffff', muted: '#b9b0d6', accent: '#8b5cf6', accent2: '#c026d3'},
  navy:    {bg: '#050c1f', card: '#0b1a36', line: '#ffffff1f', text: '#ffffff', muted: '#a3b3d1', accent: '#f6c232', accent2: '#f59e0b', ink: '#1b1400'},
  black:   {bg: '#050505', card: '#121212', line: '#ffffff1c', text: '#f7f3ea', muted: '#a8a193', accent: '#d4af37', accent2: '#a16207', ink: '#1a1405'},
  emerald: {bg: '#03130d', card: '#082319', line: '#ffffff1c', text: '#ecfdf5', muted: '#9cc9b6', accent: '#34d399', accent2: '#059669', ink: '#032016'},
  ocean:   {bg: '#03121c', card: '#072235', line: '#ffffff1c', text: '#f0f9ff', muted: '#9cc3dc', accent: '#38bdf8', accent2: '#2563eb', ink: '#032033'},
  rose:    {bg: '#16060e', card: '#2a0c1b', line: '#ffffff1f', text: '#fff1f7', muted: '#e0a9c2', accent: '#f472b6', accent2: '#db2777'},
  sunset:  {bg: '#140802', card: '#271205', line: '#ffffff1c', text: '#fff7ed', muted: '#e2b48d', accent: '#fb923c', accent2: '#ea580c'},
  crimson: {bg: '#120308', card: '#22070f', line: '#ffffff1c', text: '#fff1f2', muted: '#e3a4ae', accent: '#f43f5e', accent2: '#be123c'},
  neon:    {bg: '#060706', card: '#111411', line: '#ffffff1c', text: '#f4fff0', muted: '#a7b8a2', accent: '#a3e635', accent2: '#16a34a', ink: '#0d1a00'},
  coffee:  {bg: '#120a05', card: '#21140c', line: '#ffffff1c', text: '#fbf3e6', muted: '#cdb59a', accent: '#d6a15a', accent2: '#92400e', ink: '#1e1208'},
  ivory:   {bg: '#f3eee4', card: '#ffffff', line: '#1f1a1218', text: '#1f1a12', muted: '#71685a', accent: '#b8860b', accent2: '#92400e', light: true},
  sky:     {bg: '#eef4fb', card: '#ffffff', line: '#0f172a14', text: '#0f172a', muted: '#55657a', accent: '#2563eb', accent2: '#7c3aed', light: true},
};
export const LAYOUTS = ['classic', 'center', 'minimal'];

// Ready-made designs (crafts and executives) from /card-themes.json: colours,
// layout, button shape, a cover picture and a footer ornament. Their keys are
// the theme ids stored on the card (data.theme).
export const DESIGNS = await fetch('/card-themes.json')
  .then((r) => (r.ok ? r.json() : {themes: []}))
  .then((c) => Object.fromEntries((c.themes ?? []).map((t) => [t.id, t])))
  .catch(() => ({}));
export const DESIGN_LAYOUT = {photo: 'classic', editorial: 'minimal', centered: 'center'};
function shadeHex(hex, k) {
  const n = parseInt(hex.slice(1), 16);
  const ch = (v) => Math.max(0, Math.min(255, Math.round(k >= 0 ? v + (255 - v) * k : v * (1 + k))));
  return `#${((1 << 24) | (ch((n >> 16) & 255) << 16) | (ch((n >> 8) & 255) << 8) | ch(n & 255)).toString(16).slice(1)}`;
}
function isLight(hex) {
  const n = parseInt(hex.slice(1), 16);
  return (0.299 * ((n >> 16) & 255) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255)) / 255 > 0.6;
}
function designTheme(id) {
  const t = DESIGNS[id];
  if (!t) return null;
  const p = t.palette;
  const light = isLight(p.surface);
  return {
    bg: shadeHex(p.surface, light ? -0.06 : -0.35), card: p.surface, line: light ? '#00000014' : '#ffffff1f',
    text: p.text, muted: p.muted, accent: p.accent, accent2: p.button, ink: p.buttonText,
    button: p.button, light, design: t,
  };
}

const I = (d, extra = '') => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" ${extra}>${d}</svg>`;
const B = (d) => `<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">${d}</svg>`;
const ICON = {
  phone: I('<path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8 9.9a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2z"/>'),
  mail: I('<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>'),
  globe: I('<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>'),
  pin: I('<path d="M12 21s-7-6.1-7-11.5A7 7 0 0 1 19 9.5C19 14.9 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>'),
  swap: I('<path d="M16 3l4 4-4 4M20 7H9M8 21l-4-4 4-4M4 17h11"/>'),
  save: I('<path d="M12 3v12M7 10l5 5 5-5M5 21h14"/>'),
  user: I('<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>'),
  whatsapp: B('<path d="M12 2a10 10 0 0 0-8.6 15.1L2 22l5-1.3A10 10 0 1 0 12 2zm0 18.2a8.2 8.2 0 0 1-4.2-1.2l-.3-.2-3 .8.8-2.9-.2-.3A8.2 8.2 0 1 1 12 20.2zm4.5-6.1c-.2-.1-1.5-.7-1.7-.8s-.4-.1-.6.1-.7.8-.8 1-.3.2-.5.1a6.7 6.7 0 0 1-3.3-2.9c-.3-.4.2-.4.7-1.4.1-.2 0-.3 0-.4l-.8-1.8c-.2-.5-.4-.4-.6-.4h-.5a1 1 0 0 0-.7.3 3 3 0 0 0-.9 2.2 5.1 5.1 0 0 0 1.1 2.7 11.6 11.6 0 0 0 4.5 4c1.7.7 2.3.8 3.2.6a2.7 2.7 0 0 0 1.8-1.2 2.2 2.2 0 0 0 .2-1.3c-.1-.1-.2-.2-.5-.3z"/>'),
  instagram: I('<rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.5" cy="6.5" r="1" fill="currentColor"/>'),
  facebook: B('<path d="M14 8V6.5c0-.8.2-1.3 1.4-1.3H17V2.2A21 21 0 0 0 14.6 2C12.2 2 10.6 3.5 10.6 6.1V8H8v3.3h2.6V22H14V11.3h2.7L17 8z"/>'),
  tiktok: B('<path d="M16.6 2h-3.3v13.2a2.9 2.9 0 1 1-2.9-2.9c.3 0 .6 0 .9.1V9a6.3 6.3 0 1 0 5.3 6.2V8.6a8 8 0 0 0 4.4 1.4V6.7a4.6 4.6 0 0 1-4.4-4.7z"/>'),
  linkedin: B('<path d="M4.98 3.5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5zM3 9.5h4V21H3zM9.5 9.5h3.8v1.6h.1c.5-1 1.8-2 3.8-2 4 0 4.8 2.6 4.8 6V21h-4v-5.2c0-1.2 0-2.8-1.7-2.8s-2 1.3-2 2.7V21h-4z"/>'),
  x: B('<path d="M17.8 3h3.1l-6.8 7.7L22 21h-6.2l-4.9-6.4L5.3 21H2.2l7.2-8.3L2 3h6.3l4.4 5.9zm-1.1 16.2h1.7L7.4 4.7H5.6z"/>'),
  youtube: B('<path d="M22 8.2a3 3 0 0 0-2.1-2.1C18 5.6 12 5.6 12 5.6s-6 0-7.9.5A3 3 0 0 0 2 8.2 31 31 0 0 0 1.6 12 31 31 0 0 0 2 15.8a3 3 0 0 0 2.1 2.1c1.9.5 7.9.5 7.9.5s6 0 7.9-.5a3 3 0 0 0 2.1-2.1 31 31 0 0 0 .4-3.8 31 31 0 0 0-.4-3.8zM10 15.1V8.9l5.2 3.1z"/>'),
  snapchat: I('<path d="M12 3c3 0 5 2.2 5 5.2v2.3l1.8-.4c.6 0 .7.7.2 1-.8.4-2 .7-2 1.3.4 1.5 1.8 3 3.5 3.4-.2.8-1.4 1-2.4 1.2-.2.5-.2 1.2-.7 1.2-.8 0-1.6-.4-2.7-.2-1.2.3-1.8 1.5-3.7 1.5s-2.5-1.2-3.7-1.5c-1.1-.2-1.9.2-2.7.2-.5 0-.5-.7-.7-1.2-1-.2-2.2-.4-2.4-1.2 1.7-.4 3.1-1.9 3.5-3.4 0-.6-1.2-.9-2-1.3-.5-.3-.4-1 .2-1l1.8.4V8.2C7 5.2 9 3 12 3z"/>'),
  telegram: B('<path d="M21.9 4.3 18.7 19.5c-.2 1-.9 1.3-1.8.8l-4.9-3.6-2.4 2.3c-.3.3-.5.5-1 .5l.3-5 9.1-8.2c.4-.4-.1-.6-.6-.2L6.2 13.2 1.4 11.7c-1-.3-1-1 .2-1.5L20.6 2.9c.9-.3 1.6.2 1.3 1.4z"/>'),
};
const SOCIAL = {
  instagram: ['Instagram', (h) => `https://instagram.com/${h}`],
  tiktok: ['TikTok', (h) => `https://www.tiktok.com/@${h}`],
  facebook: ['Facebook', (h) => `https://facebook.com/${h}`],
  linkedin: ['LinkedIn', (h) => `https://www.linkedin.com/in/${h}`],
  x: ['X', (h) => `https://x.com/${h}`],
  youtube: ['YouTube', (h) => `https://youtube.com/@${h}`],
  snapchat: ['Snapchat', (h) => `https://snapchat.com/add/${h}`],
  telegram: ['Telegram', (h) => `https://t.me/${h}`],
};

function el(tag, text, cls) {
  const x = document.createElement(tag);
  if (text !== undefined && text !== null) x.textContent = text;
  if (cls) x.className = cls;
  return x;
}
function icon(name, cls = 'vc-ico') {
  const s = el('span', undefined, cls);
  s.innerHTML = ICON[name] ?? ''; // our own constant SVG strings only
  return s;
}
const digits = (v) => String(v ?? '').replace(/[^0-9+]/g, '');
const handle = (v) => String(v ?? '').trim().replace(/^@/, '');
function socialUrl(key, value) {
  const v = String(value ?? '').trim();
  if (!v) return null;
  if (/^https:\/\//.test(v)) return safeHttps(v);
  return /^@?[A-Za-z0-9_.-]{1,80}$/.test(v) ? SOCIAL[key][1](handle(v)) : null;
}
function hexOk(v) { return /^#[0-9a-fA-F]{6}$/.test(v ?? ''); }

function applyCardTheme(d, b) {
  const th = designTheme(d.theme) ?? CARD_THEMES[d.theme] ?? CARD_THEMES[b.theme === 'royal' ? 'violet' : b.theme] ?? CARD_THEMES.violet;
  const accent = hexOk(d.color) ? d.color : th.accent;
  const r = document.documentElement.style;
  for (const [k, v] of Object.entries({bg: th.bg, card: th.card, line: th.line, text: th.text, muted: th.muted, accent, accent2: hexOk(d.color) ? d.color : th.accent2})) r.setProperty(`--vc-${k}`, v);
  r.setProperty('--vc-ink', hexOk(d.color) ? '#ffffff' : th.ink ?? '#ffffff');
  r.setProperty('--primary', accent);
  r.setProperty('--accent', accent);
  document.documentElement.classList.toggle('vc-light', !!th.light);
  r.setProperty('--vc-button', hexOk(d.color) ? d.color : th.button ?? accent);
  document.querySelector('meta[name=theme-color]')?.setAttribute('content', th.bg);
  return th;
}

// vCard 3.0 with the photo (small JPEG) so the contact looks complete.
async function photoBase64(url) {
  try {
    const res = await fetch(url, {cache: 'force-cache'});
    if (!res.ok) return null;
    const bmp = await createImageBitmap(await res.blob());
    const s = 320 / Math.max(bmp.width, bmp.height);
    const c = document.createElement('canvas');
    c.width = Math.round(bmp.width * Math.min(1, s)); c.height = Math.round(bmp.height * Math.min(1, s));
    c.getContext('2d').drawImage(bmp, 0, 0, c.width, c.height);
    return c.toDataURL('image/jpeg', 0.82).split(',')[1];
  } catch { return null; }
}
async function saveContact(p, config) {
  const d = p.data, b = p.business;
  const name = d.full_name || p.title;
  const photo = safeImageUrl(p.image_url, config?.supabaseUrl);
  const b64 = photo ? await photoBase64(photo) : null;
  const lines = ['BEGIN:VCARD', 'VERSION:3.0', `FN:${vcardEscape(name)}`, `N:${vcardEscape(name)};;;;`,
    `ORG:${vcardEscape(d.company || b.name)}`,
    ...(d.job_title ? [`TITLE:${vcardEscape(d.job_title)}`] : []),
    ...(d.phone ? [`TEL;TYPE=CELL:${vcardEscape(d.phone)}`] : []),
    ...(d.whatsapp && digits(d.whatsapp) !== digits(d.phone) ? [`TEL;TYPE=WhatsApp:${vcardEscape(d.whatsapp)}`] : []),
    ...(d.email ? [`EMAIL;TYPE=INTERNET:${vcardEscape(d.email)}`] : []),
    ...(safeHttps(d.website) ? [`URL:${vcardEscape(safeHttps(d.website))}`] : []),
    `URL;TYPE=Card:${vcardEscape(location.origin + location.pathname)}`,
    ...(d.address ? [`ADR;TYPE=WORK:;;${vcardEscape(d.address)};;;;`] : []),
    ...(d.description ? [`NOTE:${vcardEscape(d.description)}`] : []),
    ...(b64 ? [`PHOTO;ENCODING=b;TYPE=JPEG:${b64}`] : []),
    'END:VCARD', ''];
  const blob = new Blob([lines.join('\r\n')], {type: 'text/vcard;charset=utf-8'});
  const file = new File([blob], `${p.custom_slug}.vcf`, {type: 'text/vcard'});
  // Phones open the contact sheet directly when the file is shared.
  if (/android|iphone|ipad/i.test(navigator.userAgent) && navigator.canShare?.({files: [file]})) {
    try { await navigator.share({files: [file]}); return; } catch { /* fall back to download */ }
  }
  const u = URL.createObjectURL(blob); const a = el('a'); a.href = u; a.download = file.name; a.click();
  setTimeout(() => URL.revokeObjectURL(u), 1500);
}

// "Exchange contact": the visitor sends his name and number to the card
// owner on WhatsApp (or by e-mail). Nothing is stored on our side.
function exchangeSheet(p, toast) {
  const d = p.data;
  const target = digits(d.whatsapp || d.phone);
  const box = el('div', undefined, 'sheet');
  const panel = el('div', undefined, 'sheet-panel glass vc-sheet');
  box.append(panel);
  box.addEventListener('click', (e) => { if (e.target === box) box.remove(); });
  panel.append(icon('swap', 'vc-sheet-ico'), el('h2', 'تبادل جهات الاتصال'),
    el('p', `أرسل اسمك ورقمك إلى ${d.full_name || p.title} بضغطة واحدة.`, 'vc-muted'));
  const name = el('input'); name.className = 'field'; name.placeholder = 'اسمك الكامل'; name.autocomplete = 'name'; name.maxLength = 80;
  const phone = el('input'); phone.className = 'field'; phone.placeholder = 'رقم هاتفك'; phone.type = 'tel'; phone.inputMode = 'tel'; phone.dir = 'ltr'; phone.autocomplete = 'tel';
  const note = el('input'); note.className = 'field'; note.placeholder = 'رسالة قصيرة (اختياري)'; note.maxLength = 200;
  const send = el('button', target ? '📲 إرسال عبر واتساب' : '✉️ إرسال بالبريد', 'button vc-primary'); send.type = 'button';
  send.addEventListener('click', () => {
    if (name.value.trim().length < 2) { toast('اكتب اسمك', true); name.focus(); return; }
    if (digits(phone.value).length < 6) { toast('اكتب رقم هاتفك', true); phone.focus(); return; }
    const msg = `مرحباً ${d.full_name || p.title} 👋\nأنا ${name.value.trim()}\nرقمي: ${phone.value.trim()}${note.value.trim() ? `\n${note.value.trim()}` : ''}\n(من بطاقتك الرقمية)`;
    const url = target
      ? `https://wa.me/${target.replace(/^\+/, '')}?text=${encodeURIComponent(msg)}`
      : `mailto:${encodeURIComponent(d.email ?? '')}?subject=${encodeURIComponent('تبادل جهات الاتصال')}&body=${encodeURIComponent(msg)}`;
    window.open(url, '_blank', 'noopener');
    box.remove();
  });
  const cancel = el('button', 'إلغاء', 'button secondary'); cancel.type = 'button';
  cancel.addEventListener('click', () => box.remove());
  panel.append(name, phone, note, send, cancel);
  document.body.append(box);
  setTimeout(() => name.focus(), 60);
}

/** Draws the business card into `root`; returns the element tapped 3 times to edit. */
export function renderVcard(root, p, config, toast) {
  const d = p.data, b = p.business;
  const th = applyCardTheme(d, b);
  const design = th.design;
  const layout = LAYOUTS.includes(d.layout) ? d.layout : design ? DESIGN_LAYOUT[design.layout] ?? 'classic' : 'classic';
  document.body.classList.add('vc-page');
  root.className = `glass vc vc-${layout}${design ? ` vc-design vc-shape-${design.buttonStyle}` : ''}`;
  const name = d.full_name || p.title;
  const company = d.company || b.name;

  // Cover: the card's own picture, else the company cover, else a glow.
  const hero = el('div', undefined, 'vc-hero');
  const cover = safeImageUrl(d.cover_url, config?.supabaseUrl) ?? (design?.assets?.cover ? design.assets.cover : null) ?? safeImageUrl(b.cover_url, config?.supabaseUrl);
  if (cover && layout !== 'minimal') {
    const img = el('img', undefined, 'vc-cover'); img.src = cover; img.alt = ''; img.referrerPolicy = 'no-referrer';
    hero.append(img);
  }
  hero.append(el('div', undefined, 'vc-glow'));
  const logo = safeImageUrl(b.logo_url, config?.supabaseUrl);
  if (layout !== 'minimal') {
    const brand = el('div', undefined, 'vc-brand');
    if (logo) { const l = el('img'); l.src = logo; l.alt = company; l.referrerPolicy = 'no-referrer'; brand.append(l); }
    brand.append(el('b', company));
    hero.append(brand);
  }

  // Photo with the logo as a small badge.
  const ava = el('div', undefined, 'vc-avatar');
  const photo = safeImageUrl(p.image_url, config?.supabaseUrl);
  if (photo) { const i = el('img'); i.src = photo; i.alt = name; i.referrerPolicy = 'no-referrer'; ava.append(i); }
  else ava.append(el('span', Array.from(name)[0] ?? '', 'vc-initial'));
  if (logo && photo) { const badge = el('div', undefined, 'vc-badge'); const l = el('img'); l.src = logo; l.alt = ''; l.referrerPolicy = 'no-referrer'; badge.append(l); ava.append(badge); }

  const who = el('div', undefined, 'vc-who');
  who.append(el('h1', name));
  const role = [d.job_title, d.job_title && company ? company : (d.job_title ? '' : company)].filter(Boolean).join(' · ');
  if (role) who.append(el('p', role, 'vc-role'));

  // Two main buttons.
  const actions = el('div', undefined, 'vc-actions');
  if (digits(d.whatsapp || d.phone).length >= 6 || d.email) {
    const ex = el('button', undefined, 'vc-btn vc-primary'); ex.type = 'button';
    ex.append(icon('swap'), el('span', 'تبادل جهات الاتصال'));
    ex.addEventListener('click', () => exchangeSheet(p, toast));
    actions.append(ex);
  }
  const sv = el('button', undefined, 'vc-btn vc-ghost'); sv.type = 'button';
  sv.append(icon('save'), el('span', 'حفظ جهة الاتصال'));
  sv.addEventListener('click', async () => { sv.disabled = true; try { await saveContact(p, config); } finally { sv.disabled = false; } });
  actions.append(sv);

  // Contact rows.
  const rows = el('div', undefined, 'vc-rows');
  const row = (ico, value, label, href, ltr = false) => {
    const a = el('a', undefined, 'vc-row'); a.href = href;
    if (/^https:/.test(href)) { a.target = '_blank'; a.rel = 'noopener noreferrer'; }
    const v = el('span', value, 'vc-val'); if (ltr) v.dir = 'ltr';
    a.append(icon(ico, 'vc-tile'), v, el('small', label));
    rows.append(a);
  };
  if (d.phone && /^[+0-9 ()-]{3,40}$/.test(d.phone)) row('phone', d.phone, 'اتصال', `tel:${digits(d.phone)}`, true);
  if (digits(d.whatsapp).length >= 6) row('whatsapp', d.whatsapp, 'واتساب', `https://wa.me/${digits(d.whatsapp).replace(/^\+/, '')}`, true);
  if (d.email && /^[^\s@]+@[^\s@]+$/.test(d.email)) row('mail', d.email, 'البريد', `mailto:${d.email}`, true);
  if (safeHttps(d.website)) row('globe', new URL(d.website).host.replace(/^www\./, ''), 'الموقع', safeHttps(d.website), true);
  if (d.address || safeHttps(d.maps_url)) row('pin', d.address || 'الموقع على الخريطة', 'العنوان', safeHttps(d.maps_url) ?? `https://maps.google.com/?q=${encodeURIComponent(d.address)}`);

  // Social chips.
  const chips = el('div', undefined, 'vc-chips');
  for (const key of Object.keys(SOCIAL)) {
    const url = socialUrl(key, d[key]);
    if (!url) continue;
    const a = el('a', undefined, `vc-chip vc-${key}`); a.href = url; a.target = '_blank'; a.rel = 'noopener noreferrer';
    a.append(icon(key), el('span', SOCIAL[key][0]));
    chips.append(a);
  }

  const parts = [hero, ava, who, actions];
  if (rows.childElementCount) parts.push(rows);
  if (chips.childElementCount) parts.push(chips);
  if (d.description) parts.push(el('p', d.description, 'vc-about'));
  if (d.quote) { const q = el('blockquote', `“${d.quote}”`, 'vc-quote'); parts.push(q); }
  if (design?.assets?.footer) {
    const f = el('img', undefined, 'vc-footer'); f.src = design.assets.footer; f.alt = ''; f.decoding = 'async'; f.loading = 'lazy';
    parts.push(f);
  }
  root.replaceChildren(...parts);
  document.title = `${name} · ${company}`;
  return ava;
}
