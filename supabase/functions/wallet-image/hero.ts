// The picture on the Google Wallet card, drawn as SVG in the shop's theme:
// the shop name in an elegant Arabic font with a gold gradient, an ornament,
// the visit circles (gift last) and a short line saying how many are left.

export interface Hero {
  name: string;
  stamps: number;
  goal: number;
  bg: string;     // card colour, hex without '#'
  accent: string; // theme gold
  ink: string;    // colour drawn on the gold
  rtl: boolean;
  lang: 'ar' | 'fr' | 'en';
  sector?: string; // shop industry: picks the stamp icon and the word used
}

// Stamp icons (24-unit line drawings) by sector; same shapes as the shop page.
const ICON: Record<string, string> = {
  barber: '<circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M20 4 8.1 15.9M14.5 14.5 20 20M8.1 8.1 12 12"/>',
  cafe: '<path d="M4 8h13v5a6 6 0 0 1-6 6h-1a6 6 0 0 1-6-6z"/><path d="M17 9h1.5a2.5 2.5 0 0 1 0 5H17"/><path d="M8 2.5c0 1 1 1.5 1 2.5M12 2.5c0 1 1 1.5 1 2.5"/>',
  carwash: '<path d="M5.5 18H3v-5l2-5.5A2 2 0 0 1 6.9 6h10.2a2 2 0 0 1 1.9 1.5L21 13v5h-2.5M3 13h18M9.5 18h5"/><circle cx="7.5" cy="17.5" r="2"/><circle cx="16.5" cy="17.5" r="2"/>',
  snack: '<path d="M12 21 3.5 5.5a14 14 0 0 1 17 0z"/><path d="M5.6 9.3a11 11 0 0 1 12.8 0"/><circle cx="12" cy="12" r="1.2"/><circle cx="9.6" cy="14.6" r="1"/><circle cx="14.2" cy="15.4" r="1"/>',
  gym: '<path d="M6.5 6.5v11M17.5 6.5v11M3.5 9v6M20.5 9v6M6.5 12h11"/>',
};
ICON.bakery = ICON.cafe;

// Word for one stamp, by sector: [singular, dual, plural (3-10), feminine?] + fr/en.
const NOUN: Record<string, {ar: [string, string, string, boolean]; fr: [string, string]; en: [string, string]}> = {
  cafe: {ar: ['كوب', 'كوبان', 'أكواب', false], fr: ['café', 'cafés'], en: ['coffee', 'coffees']},
  bakery: {ar: ['زيارة', 'زيارتان', 'زيارات', true], fr: ['visite', 'visites'], en: ['visit', 'visits']},
  carwash: {ar: ['غسلة', 'غسلتان', 'غسلات', true], fr: ['lavage', 'lavages'], en: ['wash', 'washes']},
  snack: {ar: ['طلب', 'طلبان', 'طلبات', false], fr: ['commande', 'commandes'], en: ['order', 'orders']},
  gym: {ar: ['حصة', 'حصتان', 'حصص', true], fr: ['séance', 'séances'], en: ['session', 'sessions']},
};
const VISIT = {ar: ['زيارة', 'زيارتان', 'زيارات', true] as [string, string, string, boolean], fr: ['visite', 'visites'] as [string, string], en: ['visit', 'visits'] as [string, string]};

export const W = 1032, H = 336;

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c]!));

function shade(hex: string, k: number): string {
  const n = parseInt(hex, 16);
  const ch = (v: number) => Math.max(0, Math.min(255, Math.round(k >= 0 ? v + (255 - v) * k : v * (1 + k))));
  const r = ch((n >> 16) & 255), g = ch((n >> 8) & 255), b = ch(n & 255);
  return `#${((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1)}`;
}

function bottomLine(h: Hero): string {
  const left = Math.max(0, h.goal - h.stamps);
  const w = NOUN[h.sector ?? ''] ?? VISIT;
  if (h.lang === 'fr') return left === 0 ? 'Votre cadeau est prêt' : `Encore ${left} ${left > 1 ? w.fr[1] : w.fr[0]} avant le cadeau`;
  if (h.lang === 'en') return left === 0 ? 'Your gift is ready' : `${left} more ${left > 1 ? w.en[1] : w.en[0]} to your gift`;
  if (left === 0) return 'هديتك جاهزة، اطلبها في زيارتك القادمة';
  const [one, two, many, fem] = w.ar;
  const n = left === 1 ? `${one} ${fem ? 'واحدة' : 'واحد'}` : left === 2 ? two : left <= 10 ? `${left} ${many}` : `${left} ${one}`;
  return `${fem || left > 2 ? 'تبقّت' : 'تبقّى'} ${n} على الهدية`;
}

export function heroSvg(h: Hero): string {
  const gold = `#${h.accent}`, bg = `#${h.bg}`, ink = `#${h.ink}`;
  const light = shade(h.accent, 0.45), deep = shade(h.accent, -0.3);
  const name = esc(h.name.trim().slice(0, 40));
  // Fit the name: Amiri is wide, about 0.5 em per character on average.
  const nameSize = Math.max(34, Math.min(72, Math.floor(820 / Math.max(1, h.name.trim().length * 0.5))));

  const n = h.goal + 1; // circles + gift
  const rows = n <= 9 ? 1 : n <= 18 ? 2 : 3;
  const cols = Math.ceil(n / rows);
  const top = 150, bottom = rows === 1 ? 266 : 318;
  const cell = Math.min(104, (W - 120) / cols, (bottom - top) / rows);
  const R = cell * 0.4;
  const ready = h.stamps >= h.goal;
  let circles = '';
  for (let k = 0; k < n; k++) {
    const row = Math.floor(k / cols);
    const inRow = row === rows - 1 ? n - cols * (rows - 1) : cols;
    const col = h.rtl ? inRow - 1 - (k % cols) : k % cols;
    const cx = (W - inRow * cell) / 2 + cell * (col + 0.5);
    const cy = top + ((bottom - top) - rows * cell) / 2 + cell * (row + 0.5);
    const gift = k === n - 1;
    const filled = gift ? ready : k < h.stamps;
    const s = R / 40; // icon scale (drawn for R = 40)
    if (filled) {
      circles += `<circle cx="${cx}" cy="${cy}" r="${R}" fill="url(#goldFill)" filter="url(#glow)"/>`;
    } else {
      circles += `<circle cx="${cx}" cy="${cy}" r="${R - 2}" fill="${gold}" fill-opacity="0.08" stroke="${gold}" stroke-opacity="${gift ? 1 : 0.8}" stroke-width="${Math.max(2.5, R * 0.08)}"/>`;
    }
    if (gift) {
      const c = filled ? ink : gold;
      circles += `<g transform="translate(${cx} ${cy}) scale(${s})" fill="${c}">
        <rect x="-15" y="-3" width="30" height="20" rx="2"/>
        <rect x="-18" y="-11" width="36" height="8" rx="2"/>
        <rect x="-2.2" y="-11" width="4.4" height="28" fill="${filled ? gold : bg}"/>
        <path d="M0 -11 C -4 -20 -14 -21 -13 -14 C -12 -10 -5 -11 0 -11 Z M0 -11 C 4 -20 14 -21 13 -14 C 12 -10 5 -11 0 -11 Z"/>
      </g>`;
    } else if (filled && ICON[h.sector ?? '']) {
      // The sector's icon (cup, car, scissors...) drawn in the ink colour.
      const k2 = (R * 1.15) / 24;
      circles += `<g transform="translate(${cx - 12 * k2} ${cy - 12 * k2}) scale(${k2})" fill="none" stroke="${ink}" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">${ICON[h.sector!]}</g>`;
    } else if (filled) {
      circles += `<path transform="translate(${cx} ${cy}) scale(${s})" d="M-15 1 L-4 12 L16 -10" fill="none" stroke="${ink}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>`;
    } else {
      circles += `<text x="${cx}" y="${cy + R * 0.3}" font-family="Cairo" font-weight="700" font-size="${R * 0.8}" fill="${gold}" fill-opacity="0.55" text-anchor="middle">${k + 1}</text>`;
    }
  }

  const line = rows === 1
    ? `<text x="${W / 2}" y="306" font-family="Cairo" font-weight="600" font-size="23" fill="${light}" fill-opacity="0.9" text-anchor="middle">${esc(bottomLine(h))}</text>`
    : '';

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${shade(h.bg, 0.08)}"/>
      <stop offset="1" stop-color="${shade(h.bg, -0.35)}"/>
    </linearGradient>
    <radialGradient id="halo" cx="0.5" cy="0.18" r="0.6">
      <stop offset="0" stop-color="${gold}" stop-opacity="0.22"/>
      <stop offset="1" stop-color="${gold}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="goldText" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${light}"/>
      <stop offset="0.55" stop-color="${gold}"/>
      <stop offset="1" stop-color="${deep}"/>
    </linearGradient>
    <linearGradient id="goldFill" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${light}"/>
      <stop offset="1" stop-color="${gold}"/>
    </linearGradient>
    <filter id="shadow" x="-10%" y="-30%" width="120%" height="160%">
      <feDropShadow dx="0" dy="3" stdDeviation="3" flood-color="#000" flood-opacity="0.45"/>
    </filter>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
      <feDropShadow dx="0" dy="0" stdDeviation="6" flood-color="${gold}" flood-opacity="0.55"/>
    </filter>
    <pattern id="dots" width="22" height="22" patternUnits="userSpaceOnUse">
      <circle cx="2" cy="2" r="1.2" fill="${gold}" fill-opacity="0.07"/>
    </pattern>
  </defs>
  <rect width="${W}" height="${H}" fill="url(#bg)"/>
  <rect width="${W}" height="${H}" fill="url(#dots)"/>
  <rect width="${W}" height="${H}" fill="url(#halo)"/>
  <rect x="14" y="14" width="${W - 28}" height="${H - 28}" rx="24" fill="none" stroke="${gold}" stroke-opacity="0.55" stroke-width="2"/>
  <rect x="22" y="22" width="${W - 44}" height="${H - 44}" rx="19" fill="none" stroke="${gold}" stroke-opacity="0.18" stroke-width="1"/>
  <text x="${W / 2}" y="${58 + nameSize * 0.55}" font-family="Amiri" font-weight="700" font-size="${nameSize}" fill="url(#goldText)" text-anchor="middle" filter="url(#shadow)">${name}</text>
  <g stroke="${gold}" stroke-width="1.6" stroke-linecap="round">
    <line x1="${W / 2 - 190}" y1="132" x2="${W / 2 - 22}" y2="132" stroke-opacity="0.7"/>
    <line x1="${W / 2 + 22}" y1="132" x2="${W / 2 + 190}" y2="132" stroke-opacity="0.7"/>
  </g>
  <path d="M${W / 2} 123 L${W / 2 + 9} 132 L${W / 2} 141 L${W / 2 - 9} 132 Z" fill="${gold}"/>
  <circle cx="${W / 2 - 196}" cy="132" r="2.5" fill="${gold}"/>
  <circle cx="${W / 2 + 196}" cy="132" r="2.5" fill="${gold}"/>
  ${circles}
  ${line}
</svg>`;
}

// Wide logo for the front of the card (Wallet home screen): the shop name in
// the theme gold on a transparent 1280 x 400 canvas (Google's recommended size).
export const WW = 1280, WH = 400;
export function wideSvg(nameRaw: string, accent: string): string {
  const gold = `#${accent}`, light = shade(accent, 0.5), deep = shade(accent, -0.25);
  const text = nameRaw.trim().slice(0, 40);
  const size = Math.max(90, Math.min(190, Math.floor(2300 / Math.max(1, text.length))));
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${WW}" height="${WH}" viewBox="0 0 ${WW} ${WH}">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${light}"/>
      <stop offset="0.55" stop-color="${gold}"/>
      <stop offset="1" stop-color="${deep}"/>
    </linearGradient>
    <filter id="s" x="-10%" y="-30%" width="120%" height="160%">
      <feDropShadow dx="0" dy="4" stdDeviation="5" flood-color="#000" flood-opacity="0.5"/>
    </filter>
  </defs>
  <text x="${WW / 2}" y="${/[\u0600-\u06FF]/.test(text) ? 190 + size * 0.32 : 262}" font-family="Amiri" font-weight="700" font-size="${size}" fill="url(#g)" text-anchor="middle" filter="url(#s)">${esc(text)}</text>
  <g stroke="${gold}" stroke-width="3" stroke-linecap="round" stroke-opacity="0.8">
    <line x1="${WW / 2 - 260}" y1="352" x2="${WW / 2 - 30}" y2="352"/>
    <line x1="${WW / 2 + 30}" y1="352" x2="${WW / 2 + 260}" y2="352"/>
  </g>
  <path d="M${WW / 2} 338 L${WW / 2 + 14} 352 L${WW / 2} 366 L${WW / 2 - 14} 352 Z" fill="${gold}"/>
</svg>`;
}
