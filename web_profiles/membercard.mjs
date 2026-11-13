// The TapMaroc member card: a physical-looking loyalty card drawn in the
// shop's theme. Shown big on the customer's loyalty page and small in the
// design catalog (shop dashboard). Every colour comes from the theme object,
// so several cards with different themes can sit on one page.
//
// Decoration ("art") sits on the far side of the card, away from the text,
// so it never covers the shop name.
import {THEMES, ICONS, STAMP} from '/themes.mjs';

const WORDS = {
  ar: {member: 'العضو', card: 'بطاقة الولاء', guest: 'زبون مميّز'},
  fr: {member: 'MEMBRE', card: 'Carte de fidélité', guest: 'Client privilégié'},
  en: {member: 'MEMBER', card: 'Loyalty card', guest: 'Valued guest'},
  it: {member: 'MEMBRO', card: 'Tessera fedeltà', guest: 'Cliente speciale'},
};

// Which decoration each look uses.
const ART = {
  luxe: 'arc', soft: 'arc', arch: 'arch', hex: 'arc', ribbon: 'ribbon',
  square: 'lines', offset: 'lines', tilt: 'lines',
  frame: 'frame', ticket: 'frame', grid: 'grid', glow: 'glow',
};

const NFC = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M7 8.5a5 5 0 0 1 0 7"/><path d="M10.5 6a9 9 0 0 1 0 12"/><path d="M14 3.5a13 13 0 0 1 0 17"/></svg>';

function node(tag, cls, text) {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text != null) n.textContent = text;
  return n;
}

/**
 * @param {object} o
 * @param {object} o.shop      shop row (name, industry, tagline, theme)
 * @param {string} [o.theme]   theme key (defaults to the shop's)
 * @param {string} [o.holder]  customer name
 * @param {number} [o.stamps]
 * @param {number} [o.goal]
 * @param {string} [o.lang]
 * @param {boolean} [o.mini]   small version for the catalog
 */
export function memberCard({shop, theme, holder, stamps, goal, lang = 'ar', mini = false}) {
  const key = THEMES[theme] ? theme : THEMES[shop?.theme] ? shop.theme : 'navy';
  const th = THEMES[key];
  const w = WORDS[lang] ?? WORDS.en;
  const light = th.light ?? ['ivory', 'mint'].includes(key);
  const card = node('div', 'mc' + (mini ? ' mini' : '') + (light ? ' light' : ''));
  card.dataset.art = ART[th.look] ?? 'arc';
  const s = card.style;
  s.setProperty('--m-a', th.card2);
  s.setProperty('--m-b', th.bg);
  s.setProperty('--m-gold', th.gold);
  s.setProperty('--m-text', th.text);
  s.setProperty('--m-muted', th.muted);
  s.setProperty('--m-ink', th.ink);
  card.setAttribute('role', 'img');
  card.setAttribute('aria-label', `${w.card} · ${shop?.name ?? ''}`);

  const art = node('div', 'mc-art');
  art.setAttribute('aria-hidden', 'true');
  card.append(art);

  const top = node('div', 'mc-top');
  const brand = node('div', 'mc-brand');
  const tile = node('span', 'mc-tile');
  tile.innerHTML = ICONS[STAMP[shop?.industry]] ?? ICONS.sparkle;
  brand.append(tile, node('span', 'mc-label', w.card));
  const right = node('div', 'mc-right');
  right.append(node('span', 'mc-chip'));
  const nfc = node('span', 'mc-nfc');
  nfc.innerHTML = NFC;
  right.append(nfc);
  top.append(brand, right);

  const mid = node('div', 'mc-mid');
  // <bdi>: a Latin name keeps its own order but follows the card's alignment.
  const name = node('div', 'mc-name');
  name.append(node('bdi', null, shop?.name ?? ''));
  mid.append(name);
  if (!mini && shop?.tagline) mid.append(node('div', 'mc-tag', shop.tagline));

  const bottom = node('div', 'mc-bottom');
  const who = node('div', 'mc-who');
  who.append(node('span', 'mc-small', w.member));
  const h = node('b', 'mc-holder');
  h.append(node('bdi', null, holder || w.guest));
  who.append(h);
  const end = node('div', 'mc-end');
  if (goal) {
    // Numbers always left to right: "5 / 8", never "8 / 5".
    const pill = node('bdi', 'mc-pill', `${Math.min(stamps ?? 0, goal)} / ${goal}`);
    pill.dir = 'ltr';
    end.append(pill);
  }
  end.append(node('span', 'mc-mark', 'TapMaroc'));
  bottom.append(who, end);

  card.append(top, mid, bottom);
  const wrap = node('div', 'mc-wrap');
  wrap.append(card);
  return wrap;
}
