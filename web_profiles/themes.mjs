// Ten looks for the public shop page. The owner picks one in his settings;
// each only changes colours, so every layout stays the same and readable.
export const THEMES = {
  navy:    {name: {ar: 'كحلي وذهبي', fr: 'Marine et or', en: 'Navy & gold'},       bg: '#06112a', card: '#0b1a36', card2: '#0f2346', line: '#2b4373', text: '#ffffff', muted: '#a3b3d1', gold: '#f6c232', ink: '#1b1400'},
  black:   {name: {ar: 'أسود فاخر', fr: 'Noir luxe', en: 'Black luxury'},          bg: '#050505', card: '#101010', card2: '#181818', line: '#353026', text: '#f7f3ea', muted: '#a8a193', gold: '#d4af37', ink: '#1a1405'},
  emerald: {name: {ar: 'زمردي', fr: 'Émeraude', en: 'Emerald'},                     bg: '#03140e', card: '#072319', card2: '#0b2e22', line: '#1f5c46', text: '#ecfdf5', muted: '#9cc9b6', gold: '#34d399', ink: '#032016'},
  royal:   {name: {ar: 'بنفسجي ملكي', fr: 'Violet royal', en: 'Royal purple'},      bg: '#0d0720', card: '#170e33', card2: '#211647', line: '#40307a', text: '#f5f3ff', muted: '#b9b0de', gold: '#c4b5fd', ink: '#1b0f3d'},
  rose:    {name: {ar: 'وردي أنيق', fr: 'Rose chic', en: 'Chic rose'},             bg: '#1a0711', card: '#2a0c1b', card2: '#381226', line: '#6e2c4b', text: '#fff1f7', muted: '#e0a9c2', gold: '#f9a8d4', ink: '#3b0a22'},
  ocean:   {name: {ar: 'أزرق المحيط', fr: 'Océan', en: 'Ocean'},                   bg: '#03131e', card: '#062234', card2: '#0a2e46', line: '#1d5277', text: '#f0f9ff', muted: '#9cc3dc', gold: '#38bdf8', ink: '#032033'},
  sunset:  {name: {ar: 'برتقالي الغروب', fr: 'Coucher de soleil', en: 'Sunset'},    bg: '#170902', card: '#271205', card2: '#361a08', line: '#6d3913', text: '#fff7ed', muted: '#e2b48d', gold: '#fb923c', ink: '#2a1102'},
  crimson: {name: {ar: 'أحمر قرمزي', fr: 'Pourpre', en: 'Crimson'},                bg: '#130409', card: '#21070f', card2: '#2f0b16', line: '#61192c', text: '#fff1f2', muted: '#e3a4ae', gold: '#f43f5e', ink: '#ffffff'},
  ivory:   {name: {ar: 'عاجي فاتح', fr: 'Ivoire', en: 'Ivory light'},              bg: '#f3eee4', card: '#ffffff', card2: '#f8f4ec', line: '#e2d9c8', text: '#1f1a12', muted: '#71685a', gold: '#b8860b', ink: '#ffffff'},
  mint:    {name: {ar: 'نعناعي فاتح', fr: 'Menthe', en: 'Mint light'},             bg: '#ecf6f2', card: '#ffffff', card2: '#f1f9f6', line: '#cfe6dc', text: '#0e2a21', muted: '#557268', gold: '#0f9f6e', ink: '#ffffff'},
  // Sector themes (picked automatically from the shop's sector).
  coffee:  {name: {ar: 'قهوة: بني وذهبي', fr: 'Café : brun et or', en: 'Coffee: brown & gold'}, bg: '#140c07', card: '#21140c', card2: '#2c1b10', line: '#5a3a22', text: '#fbf3e6', muted: '#cdb59a', gold: '#d6a15a', ink: '#1e1208'},
  aqua:    {name: {ar: 'غسيل: سماوي ومعدني', fr: 'Lavage : bleu ciel et acier', en: 'Wash: sky & steel'}, bg: '#0a1520', card: '#122230', card2: '#1a2d3d', line: '#3a5468', text: '#f4f9fc', muted: '#a9bccb', gold: '#4cc9f0', ink: '#04202c'},
  pizza:   {name: {ar: 'مطعم: أحمر وبرتقالي', fr: 'Pizzeria : rouge et orange', en: 'Pizzeria: red & orange'}, bg: '#0d0807', card: '#1a0f0c', card2: '#241510', line: '#5c2a1d', text: '#fff4ec', muted: '#e0b8a3', gold: '#ff7a2f', ink: '#2a0d02'},
  neon:    {name: {ar: 'رياضة: أسود ونيون', fr: 'Sport : noir et néon', en: 'Gym: black & neon'}, bg: '#070807', card: '#101210', card2: '#171a17', line: '#2f3a2c', text: '#f4fff0', muted: '#a7b8a2', gold: '#b6ff3b', ink: '#0d1a00'},
};

// Premium looks: colours plus a shape ("look") for the photo, the stamps and
// the points box. Text on the accent colour is picked for contrast.
const hex = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const mix = (a, b, w) => '#' + hex(a).map((x, i) => Math.round(x * w + hex(b)[i] * (1 - w)).toString(16).padStart(2, '0')).join('');
const lum = (h) => { const [r, g, b] = hex(h).map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
const premium = (ar, fr, en, it, bg, accent, text, card, look) => {
  const light = lum(bg) > 0.5;
  return {
    name: {ar, fr, en, it}, bg, card, card2: mix(card, bg, 0.55), line: mix(text, card, light ? 0.16 : 0.18),
    text, muted: mix(text, bg, light ? 0.78 : 0.66), gold: accent, ink: lum(accent) > 0.36 ? '#111111' : '#ffffff', light, look,
  };
};
Object.assign(THEMES, {
  onyx:     premium('أونيكس ملكي', 'Onyx royal', 'Royal Onyx', 'Onice reale', '#101114', '#d7b77a', '#ffffff', '#242322', 'luxe'),
  imperial: premium('ليل إمبراطوري', 'Nuit impériale', 'Imperial Night', 'Notte imperiale', '#151020', '#f1c77e', '#fff5dc', '#272035', 'hex'),
  amber:    premium('صالون كهرماني', 'Salon ambre', 'Amber Lounge', 'Lounge ambra', '#25190f', '#dba64d', '#fff3d7', '#382919', 'ribbon'),
  espresso: premium('إسبريسو', 'Espresso', 'Espresso House', 'Espresso', '#2b211d', '#d7a578', '#fff4e9', '#3b302a', 'square'),
  velvet:   premium('مخملي عنابي', 'Velours bordeaux', 'Velvet Burgundy', 'Velluto bordeaux', '#3d1223', '#e7b2aa', '#fff4ed', '#561d30', 'soft'),
  midnight: premium('أزرق منتصف الليل', 'Bleu minuit', 'Midnight Blue', 'Blu notte', '#0c1a36', '#b9c9ff', '#f6f8ff', '#182849', 'frame'),
  drive:    premium('أزرق السيارات', 'Ocean Drive', 'Ocean Drive', 'Ocean Drive', '#092c45', '#35b9e5', '#f0faff', '#16465d', 'square'),
  pulse:    premium('نبض تقني', 'Pulse tech', 'Future Pulse', 'Pulse tech', '#0e2026', '#25e0bd', '#e4fffa', '#17353a', 'grid'),
  district: premium('نيون ليلي', 'Néon urbain', 'Neon District', 'Neon urbano', '#0b0c1b', '#d4ff39', '#f8faff', '#1b1d30', 'glow'),
  redline:  premium('أحمر رياضي', 'Rouge sport', 'Redline Sport', 'Rosso sport', '#191c20', '#f0524d', '#ffffff', '#282b31', 'tilt'),
  sahara:   premium('تراث الصحراء', 'Héritage Sahara', 'Sahara Heritage', 'Eredità Sahara', '#f3e5cf', '#a75b32', '#4d3328', '#f8efdf', 'arch'),
  terra:    premium('مخبزة طينية', 'Terre boulangerie', 'Terra Bakery', 'Forno terracotta', '#f9ebd5', '#ad713f', '#4a2f1b', '#fff9ed', 'ticket'),
  atelier:  premium('وردي أتولييه', 'Atelier rose', 'Rose Atelier', 'Atelier rosa', '#fff1f5', '#be5684', '#432b37', '#fffafd', 'soft'),
  candy:    premium('حلوى وردية', 'Bonbon', 'Candy Pop', 'Caramella', '#fff0fa', '#e95a9d', '#662c51', '#ffffff', 'square'),
  coral:    premium('نادي المرجان', 'Club corail', 'Coral Club', 'Club corallo', '#fff0e7', '#e0654e', '#62372e', '#ffffff', 'offset'),
  street:   premium('شارع حضري', 'Urbain', 'Urban Street', 'Urbano', '#f7f3e9', '#f04a22', '#1c1b1a', '#ffffff', 'offset'),
  jade:     premium('عيادة اليشم', 'Jade clinique', 'Jade Clinic', 'Giada', '#e7f4f0', '#2b9a7b', '#1b5347', '#ffffff', 'soft'),
  nordic:   premium('هدوء شمالي', 'Calme nordique', 'Nordic Calm', 'Calma nordica', '#e9eee9', '#5d7a64', '#34463a', '#f8fbf8', 'soft'),
  platinum: premium('بلاتيني', 'Platine', 'Platinum Edge', 'Platino', '#e7eaed', '#5b6677', '#26313b', '#ffffff', 'frame'),
  mono:     premium('أبيض وأسود', 'Monochrome', 'Monochrome', 'Monocromo', '#f7f7f7', '#111111', '#111111', '#ffffff', 'square'),
});

// Icon drawn in a filled loyalty circle, by sector.
export const STAMP = {barber: 'scissors', cafe: 'cup', bakery: 'cup', carwash: 'car', snack: 'pizza', gym: 'dumbbell', beauty: 'sparkle'};
export function stampIcon(shop) {
  return ICONS[STAMP[shop?.industry]] ?? ICONS.check;
}

// The sector's own symbol for the shop photo when there is no logo.
export function sectorIcon(shop) {
  return ICONS[STAMP[shop?.industry]] ?? ICONS.sparkle;
}

export function themeOf(shop) {
  return THEMES[shop?.theme] ?? THEMES.navy;
}

export function applyTheme(key) {
  const th = THEMES[key] ?? THEMES.navy;
  const r = document.documentElement.style;
  r.setProperty('--t-bg', th.bg);
  r.setProperty('--t-card', th.card);
  r.setProperty('--t-card2', th.card2);
  r.setProperty('--t-line', th.line);
  r.setProperty('--t-text', th.text);
  r.setProperty('--t-muted', th.muted);
  r.setProperty('--t-gold', th.gold);
  r.setProperty('--t-ink', th.ink);
  // Shared page variables follow the theme too (panels, buttons, text).
  r.setProperty('--bg', th.bg);
  r.setProperty('--panel', th.card);
  r.setProperty('--panel-2', th.card2);
  r.setProperty('--line', th.line + '99');
  r.setProperty('--line-2', th.line);
  r.setProperty('--text', th.text);
  r.setProperty('--muted', th.muted);
  r.setProperty('--primary', th.gold);
  r.setProperty('--accent', th.gold);
  const light = th.light ?? ['ivory', 'mint'].includes(key);
  document.documentElement.dataset.look = th.look ?? '';
  document.documentElement.dataset.light = String(light);
  document.documentElement.style.colorScheme = light ? 'light' : 'dark';
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', th.bg);
}

// Small line icons (stroke follows currentColor) and brand marks.
const S = (d, extra = '') => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" ${extra}>${d}</svg>`;
export const ICONS = {
  pin: S('<path d="M12 21s-7-6.1-7-11a7 7 0 1 1 14 0c0 4.9-7 11-7 11z"/><circle cx="12" cy="10" r="2.6"/>'),
  clock: S('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
  phone: S('<path d="M5 3h4l2 5-2.5 1.5a11 11 0 0 0 6 6L16 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 5a2 2 0 0 1 2-2z"/>'),
  calendar: S('<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M8 3v4M16 3v4M3 10h18M8 14h.01M12 14h.01M16 14h.01M8 17.5h.01M12 17.5h.01"/>'),
  globe: S('<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>'),
  map: S('<path d="M9 4 3 6v14l6-2 6 2 6-2V4l-6 2-6-2z"/><path d="M9 4v14M15 6v14"/>'),
  mail: S('<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>'),
  arrow: S('<path d="M19 12H5M11 6l-6 6 6 6"/>'),
  sparkle: S('<path d="M12 3l2.2 6.8L21 12l-6.8 2.2L12 21l-2.2-6.8L3 12l6.8-2.2z" fill="currentColor" stroke="none"/>'),
  gift: S('<rect x="3" y="9" width="18" height="12" rx="2"/><path d="M12 9v12M3 13h18M12 9s-1.5-5-4.5-5a2.2 2.2 0 0 0 0 4.4C10 8.4 12 9 12 9zM12 9s1.5-5 4.5-5a2.2 2.2 0 0 1 0 4.4C14 8.4 12 9 12 9z"/>'),
  check: S('<path d="m5 12.5 4.5 4.5L19 7.5"/>', 'stroke-width="3"'),
  // Stamp icons per sector (a filled loyalty circle shows the sector's icon).
  scissors: S('<circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M20 4 8.1 15.9M14.5 14.5 20 20M8.1 8.1 12 12"/>', 'stroke-width="2.4"'),
  cup: S('<path d="M4 8h13v5a6 6 0 0 1-6 6h-1a6 6 0 0 1-6-6z"/><path d="M17 9h1.5a2.5 2.5 0 0 1 0 5H17"/><path d="M8 2.5c0 1 1 1.5 1 2.5M12 2.5c0 1 1 1.5 1 2.5"/>', 'stroke-width="2.4"'),
  car: S('<path d="M5.5 18H3v-5l2-5.5A2 2 0 0 1 6.9 6h10.2a2 2 0 0 1 1.9 1.5L21 13v5h-2.5M3 13h18M9.5 18h5"/><circle cx="7.5" cy="17.5" r="2"/><circle cx="16.5" cy="17.5" r="2"/>', 'stroke-width="2.2"'),
  pizza: S('<path d="M12 21 3.5 5.5a14 14 0 0 1 17 0z"/><path d="M5.6 9.3a11 11 0 0 1 12.8 0"/><circle cx="12" cy="12" r="1.2"/><circle cx="9.6" cy="14.6" r="1"/><circle cx="14.2" cy="15.4" r="1"/>', 'stroke-width="2.2"'),
  dumbbell: S('<path d="M6.5 6.5v11M17.5 6.5v11M3.5 9v6M20.5 9v6M6.5 12h11"/>', 'stroke-width="2.6"'),
  leaf: `<svg viewBox="0 0 24 24"><path fill="#22c55e" d="M20 4c-9 0-15 4-15 11 0 1.6.5 3 1.2 4.1C8 14 11 11 16 9c-4 2.6-7 6-8.4 10.4C8.8 20.4 10.3 21 12 21c6 0 9-6 8-17z"/></svg>`,
  whatsapp: `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#25d366"/><path fill="#25d366" d="M3.5 21 5 16l4 3z"/><path fill="#fff" d="M9.2 7.4c.3-.1.6 0 .8.3l.9 2c.1.3 0 .6-.2.8l-.6.6c.6 1.3 1.6 2.3 2.9 2.9l.6-.6c.2-.2.5-.3.8-.2l2 .9c.3.2.4.5.3.8-.3 1-1.2 1.7-2.3 1.6-3.5-.4-6.3-3.2-6.7-6.7-.1-1.1.6-2 1.5-2.4z"/></svg>`,
  instagram: `<svg viewBox="0 0 24 24"><defs><linearGradient id="ig" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#f9a825"/><stop offset=".5" stop-color="#e91e63"/><stop offset="1" stop-color="#7b1fa2"/></linearGradient></defs><rect x="2.5" y="2.5" width="19" height="19" rx="5.5" fill="none" stroke="url(#ig)" stroke-width="2.4"/><circle cx="12" cy="12" r="4.3" fill="none" stroke="url(#ig)" stroke-width="2.4"/><circle cx="17.4" cy="6.6" r="1.4" fill="url(#ig)"/></svg>`,
  facebook: `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#1877f2"/><path fill="#fff" d="M13.3 22.4v-7.2h2.4l.4-2.9h-2.8v-1.8c0-.8.3-1.4 1.4-1.4h1.5V6.5c-.3 0-1.2-.1-2.2-.1-2.2 0-3.6 1.3-3.6 3.7v2.2H8v2.9h2.4v7.2z"/></svg>`,
  tiktok: `<svg viewBox="0 0 24 24"><path fill="#25f4ee" d="M9.4 10.2v-1A6 6 0 1 0 14 15V8.7a7.6 7.6 0 0 0 4.4 1.4V7.2a4.4 4.4 0 0 1-3.4-3.9h-2.9v11.6a2.6 2.6 0 1 1-2.6-2.6z" transform="translate(-.8 -.6)"/><path fill="#fe2c55" d="M9.4 10.2v-1A6 6 0 1 0 14 15V8.7a7.6 7.6 0 0 0 4.4 1.4V7.2a4.4 4.4 0 0 1-3.4-3.9h-2.9v11.6a2.6 2.6 0 1 1-2.6-2.6z" transform="translate(.8 .6)"/><path fill="currentColor" d="M9.4 10.2v-1A6 6 0 1 0 14 15V8.7a7.6 7.6 0 0 0 4.4 1.4V7.2a4.4 4.4 0 0 1-3.4-3.9h-2.9v11.6a2.6 2.6 0 1 1-2.6-2.6z"/></svg>`,
  snapchat: `<svg viewBox="0 0 24 24"><rect x="2" y="2" width="20" height="20" rx="6" fill="#fffc00"/><path fill="#fff" stroke="#111" stroke-width="1.1" d="M12 5.5c2.3 0 3.8 1.7 3.8 3.9v1.7l1.3-.3c.5 0 .6.6.2.8l-1.4.7c.5 1.4 1.5 2.3 2.6 2.7-.2.6-1.2.8-2 .9l-.2.9c-1-.1-1.7.1-2.4.6-1.1.8-2.7.8-3.8 0-.7-.5-1.4-.7-2.4-.6l-.2-.9c-.8-.1-1.8-.3-2-.9 1.1-.4 2.1-1.3 2.6-2.7l-1.4-.7c-.4-.2-.3-.8.2-.8l1.3.3V9.4c0-2.2 1.5-3.9 3.8-3.9z"/></svg>`,
  youtube: `<svg viewBox="0 0 24 24"><rect x="1.5" y="5" width="21" height="14" rx="4.5" fill="#ff0000"/><path fill="#fff" d="m10 8.8 5.4 3.2-5.4 3.2z"/></svg>`,
};
