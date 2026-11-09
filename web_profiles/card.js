import {t, lang, applyLang, langSwitcher} from '/i18n.mjs';
import {applyTheme, ICONS} from '/themes.mjs';
import {loadConfig, rpc, slugFrom, el, applyColors, toast, storage, bannerStrip, industry, unit,
  slotsGrid, safeImage, formatDate, dayName, todayIndex, validWeek, openNow, socialLink, industryLabel, dayText} from '/loyalty.mjs';

const root = document.getElementById('app');
const langs = document.getElementById('langs');
const slug = slugFrom('c');
const tokenKey = `nfc_card_${slug}`;
// The rotating code arrives as ?t=…; it is used once and removed from the URL.
let pendingCode = new URLSearchParams(location.search).get('t');
if (pendingCode && !/^[0-9a-f]{8}$/i.test(pendingCode)) pendingCode = null;
if (pendingCode) history.replaceState(null, '', location.pathname);

let config = null, shop = null, customer = null, notice = null, fresh = -1;
let myBooking = null; // the customer's current appointment (nfc_booking_mine)
let installEvent = null;
window.addEventListener('beforeinstallprompt', e => { e.preventDefault(); installEvent = e; });

function status(title, text) {
  root.replaceChildren(el('div', undefined, 'panel'));
  root.firstChild.append(el('h2', title), el('p', text ?? '', 'muted'));
}

const svg = (name, cls = 'ico') => { const x = el('span', undefined, cls); x.innerHTML = ICONS[name] ?? ''; return x; };
const ext = (a, href) => { a.href = href; if (!href.startsWith('tel:') && !href.startsWith('mailto:')) { a.target = '_blank'; a.rel = 'noopener'; } return a; };

// The digital business card: header, cover with photo, details, links,
// social networks and loyalty points. Four quick taps on the photo open the
// hidden owner login.
function bizCard() {
  const card = el('article', undefined, 'bc');
  const head = el('div', undefined, 'bc-head');
  const badge = el('span', industry(shop).icon, 'bc-badge');
  head.append(badge, el('h2', t('bizCard')), langs);
  card.append(head);

  const coverUrl = safeImage(shop.cover_url, config) ?? safeImage(shop.banners?.[0], config);
  const cover = el('div', undefined, 'bc-cover' + (coverUrl ? '' : ' plain'));
  if (coverUrl) cover.style.setProperty('--cover', `url("${coverUrl}")`);
  const logoUrl = safeImage(shop.logo_url, config);
  const avatar = el('div', logoUrl ? undefined : industry(shop).icon, 'bc-avatar');
  if (logoUrl) { const img = el('img'); img.src = logoUrl; img.alt = ''; img.referrerPolicy = 'no-referrer'; avatar.append(img); }
  let taps = [];
  avatar.addEventListener('click', () => {
    const now = Date.now();
    taps = taps.filter(x => now - x < 1500);
    taps.push(now);
    if (taps.length >= 4) { taps = []; ownerLogin(); }
  });
  const nameRow = el('div', undefined, 'bc-name');
  nameRow.append(el('h1', shop.name), svg('leaf', 'bc-leaf'));
  cover.append(avatar, nameRow, el('p', shop.tagline || industryLabel(shop), 'bc-tagline'));
  const open = shop.closed ? false : openNow(shop.week_hours);
  if (open !== null) cover.append(el('span', `● ${open ? t('openNow') : shop.closed ? t('closedBadge') : t('closedNow')}`, 'chip ' + (open ? 'green' : 'red')));
  card.append(cover);
  // Two big actions: call and book.
  const telLink = socialLink('phone', shop.phone);
  if (telLink || shop.booking_enabled) {
    const acts = el('div', undefined, 'bc-actions');
    if (telLink) {
      const a = ext(el('a', undefined, 'bc-act'), telLink.href);
      a.append(svg('phone', 'ico'), el('span', t('call')));
      acts.append(a);
    }
    if (shop.booking_enabled) {
      const b = el('button', undefined, 'bc-act gold'); b.type = 'button';
      b.append(svg('calendar', 'ico'), el('span', t('bookBtn')));
      b.addEventListener('click', bookingSheet);
      acts.append(b);
    }
    card.append(acts);
  }

  const body = el('div', undefined, 'bc-body');
  // Address | today's hours
  const tiles = el('div', undefined, 'bc-box bc-split');
  if (shop.address) {
    const a = el(shop.latitude != null ? 'a' : 'div', undefined, 'bc-tile');
    if (shop.latitude != null) ext(a, `https://www.google.com/maps/search/?api=1&query=${shop.latitude},${shop.longitude}`);
    a.append(svg('pin', 'bc-ic'), el('span', shop.address));
    tiles.append(a);
  }
  const today = validWeek(shop.week_hours) ? shop.week_hours[todayIndex()] : undefined;
  if (today !== undefined || shop.hours) {
    const h = el('div', undefined, 'bc-tile');
    const txt = el('div');
    txt.append(el('span', t('hours'), 'bc-small'), el('b', today === undefined ? shop.hours : today ? dayText(today).replace(/  ·  /g, '\n') : t('dayOff'), 'bc-ltr bc-lines'));
    h.append(svg('clock', 'bc-ic'), txt);
    tiles.append(h);
  }
  if (tiles.childNodes.length) body.append(tiles);
  // Phone | call
  const tel = socialLink('phone', shop.phone);
  if (tel) {
    // The whole box opens the phone app (tel:).
    const row = ext(el('a', undefined, 'bc-box bc-phone'), tel.href);
    row.setAttribute('aria-label', `${t('call')} ${shop.phone}`);
    const num = el('div', undefined, 'bc-tile');
    num.append(svg('phone', 'bc-ic'), el('b', shop.phone, 'bc-ltr'));
    const call = el('span', undefined, 'bc-call');
    call.append(svg('phone', 'ico'), document.createTextNode(t('call')));
    row.append(num, call);
    body.append(row);
  }
  const socials = Array.isArray(shop.socials) ? shop.socials : [];
  // Links and apps (booking, website, map)
  const appIcons = {booking: 'calendar', website: 'globe', maps: 'map'};
  const apps = socials.filter(x => x.type in appIcons).map(x => [x, socialLink(x.type, x.value)]).filter(([, l]) => l);
  if (apps.length) {
    body.append(el('h3', t('linksApps'), 'bc-title'));
    for (const [x, l] of apps) {
      const a = ext(el('a', undefined, 'bc-box bc-link'), l.href);
      a.append(svg(appIcons[x.type], 'bc-square'), el('b', t('social_' + x.type)), el('span', undefined, 'bc-grow'));
      const go = el('span', t('openLink'), 'bc-open'); go.append(svg('arrow', 'ico'));
      a.append(go);
      body.append(a);
    }
  }
  // Social networks
  const brand = ['whatsapp', 'instagram', 'facebook', 'tiktok', 'snapchat', 'youtube', 'email'];
  const nets = socials.filter(x => brand.includes(x.type)).map(x => [x, socialLink(x.type, x.value)]).filter(([, l]) => l);
  if (shop.email && !nets.some(([x]) => x.type === 'email')) { const l = socialLink('email', shop.email); if (l) nets.push([{type: 'email'}, l]); }
  if (nets.length) {
    body.append(el('h3', t('socialTitle'), 'bc-title'));
    const grid = el('div', undefined, 'bc-grid');
    for (const [x, l] of nets) {
      const a = ext(el('a', undefined, 'bc-net'), l.href);
      a.append(svg(x.type === 'email' ? 'mail' : x.type, 'bc-brand'), el('span', t('social_' + x.type)));
      grid.append(a);
    }
    body.append(grid);
  }
  // Loyalty points only for members, or for someone who just scanned the
  // shop's live QR to join; the public page shows the shop details only.
  if (customer || pendingCode) body.append(points());
  card.append(body);
  return card;
}

// Loyalty points: one circle per visit of the goal, then the free one.
function points() {
  const goal = customer?.goal ?? shop.goal;
  const reward = customer?.reward ?? shop.reward;
  const stamps = Math.min(goal, customer?.stamps ?? 0);
  const box = el('section', undefined, 'bc-box bc-points' + (customer?.next_free ? ' ready' : ''));
  const title = el('h3');
  title.append(svg('sparkle', 'bc-spark'), document.createTextNode(t('pointsTitle')));
  box.append(title);
  const row = el('div', undefined, 'bc-dots');
  row.style.setProperty('--cols', String(Math.min(goal + 1, 7)));
  for (let i = 0; i < goal; i++) {
    const d = el('span', undefined, 'bc-dot' + (i < stamps ? ' on' : '') + (i === fresh ? ' pop' : ''));
    if (i < stamps) d.innerHTML = ICONS.check;
    else d.append(el('i', String(i + 1)));
    row.append(d);
  }
  const gift = el('span', undefined, 'bc-dot gift' + (customer?.next_free ? ' on' : ''));
  gift.innerHTML = ICONS.gift;
  gift.append(el('em', t('freeBadge')));
  row.append(gift);
  box.append(row);
  box.append(el('p', customer
    ? (customer.next_free ? t('giftReady') : visitsText(stamps, goal))
    : `${t('programText', {n: goal, r: reward})} — ${t('programHow')}`, 'bc-progress'));
  const rw = el('p', undefined, 'bc-reward');
  rw.append(svg('gift', 'ico'), el('span', t('rewardLabel')), el('b', reward));
  box.append(rw);
  return box;
}

// Up to six photos; tap one to see it full screen.
function gallery() {
  const urls = (Array.isArray(shop.banners) ? shop.banners : []).map(u => safeImage(u, config)).filter(Boolean);
  if (!urls.length) return null;
  const panel = el('section', undefined, 'panel');
  panel.append(el('h2', `📸 ${t('gallery')}`));
  const grid = el('div', undefined, 'gallery g' + Math.min(urls.length, 3));
  urls.forEach((url) => {
    const img = el('img'); img.src = url; img.loading = 'lazy'; img.alt = ''; img.referrerPolicy = 'no-referrer';
    img.addEventListener('click', () => {
      const box = el('div', undefined, 'lightbox');
      const big = el('img'); big.src = url; big.alt = '';
      box.append(big);
      box.addEventListener('click', () => box.remove());
      document.body.append(box);
    });
    grid.append(img);
  });
  panel.append(grid);
  return panel;
}

function closedBanner() {
  if (!shop.closed) return null;
  const box = el('div', undefined, 'banner red');
  const body = el('div');
  body.append(el('strong', t('closedUntil', {d: formatDate(shop.closed_until, lang)})));
  body.append(el('p', shop.closed_message || t('closedDefault')));
  box.append(el('span', '🚫', 'ico'), body);
  return box;
}

function loyaltyCard() {
  const goal = customer?.goal ?? shop.goal;
  const reward = customer?.reward ?? shop.reward;
  const stamps = customer?.stamps ?? 0;
  const nextFree = !!customer?.next_free;
  const card = el('div', undefined, 'lcard' + (nextFree ? ' free' : ''));
  const bgUrl = safeImage(shop.card_background, config);
  if (bgUrl) {
    const bg = el('div', undefined, 'bg');
    bg.style.backgroundImage = `url("${bgUrl}")`;
    card.append(bg, el('div', undefined, 'shade'));
  }
  const head = el('div', undefined, 'head');
  const left = el('div');
  left.append(el('div', `${industry(shop).icon} ${t('yourCard')}`, 'title'));
  left.append(el('div', customer ? customer.name : shop.name, 'holder'));
  const count = el('div', undefined, 'count');
  count.append(document.createTextNode(`${stamps}/${goal}`), el('small', unit(shop)));
  head.append(left, count);
  card.append(head, slotsGrid(goal, stamps, nextFree, fresh));
  const bar = el('div', undefined, 'progress');
  const fill = el('i'); fill.style.width = `${Math.min(100, Math.round((stamps / goal) * 100))}%`;
  bar.append(fill);
  card.append(bar);
  card.append(el('p', nextFree ? `${t('giftReady')} · ${reward}` : `${t('left', {n: Math.max(0, goal - stamps)})} · 🎁 ${reward}`, 'goal-line'));
  return card;
}

function joinPanel() {
  const panel = el('div', undefined, 'panel');
  panel.append(el('h2', `✨ ${t('join')}`), el('p', t('joinText'), 'muted small'));
  const name = el('input'); name.className = 'field'; name.placeholder = t('name'); name.autocomplete = 'name'; name.maxLength = 80;
  const phone = el('input'); phone.className = 'field'; phone.placeholder = t('phone'); phone.type = 'tel'; phone.autocomplete = 'tel'; phone.inputMode = 'tel'; phone.dir = 'ltr';
  const btn = el('button', t('joinBtn'), 'btn'); btn.type = 'button';
  btn.addEventListener('click', async () => {
    if (!name.value.trim()) { toast(t('badName'), true); return; }
    if (phone.value.replace(/[^0-9]/g, '').length < 6) { toast(t('badPhone'), true); return; }
    btn.disabled = true;
    try {
      const r = await rpc(config, 'nfc_customer_join', {
        target_slug: slug, customer_name: name.value.trim(), customer_phone: phone.value, code: pendingCode,
      });
      if (!r?.ok) { toast(r?.error === 'phone' ? t('badPhone') : t('badName'), true); return; }
      storage(tokenKey, r.token);
      customer = r.customer;
      if (r.visit) { notice = {kind: 'green', text: r.visit.free ? t('stampedFree') : t('stamped')}; fresh = customer.stamps - 1; }
      pendingCode = null;
      render();
      setTimeout(walletPrompt, 900);
    } catch {
      toast(t('network'), true);
    } finally {
      btn.disabled = false;
    }
  });
  panel.append(name, phone, btn);
  return panel;
}

function actions() {
  const panel = el('div', undefined, 'panel');
  const row = el('div', undefined, 'btn-row');
  const coming = el('button', customer.coming ? t('comingSent') : t('coming'), 'btn' + (customer.coming ? ' green' : ''));
  const arrived = el('button', customer.arrived ? t('arrivedSent') : t('arrived'), 'btn' + (customer.arrived ? ' amber' : ' ghost'));
  for (const [btn, fn, msg] of [[coming, 'nfc_customer_coming', 'comingSent'], [arrived, 'nfc_customer_arrived', 'arrivedSent']]) {
    btn.type = 'button';
    btn.disabled = !!shop.closed;
    btn.addEventListener('click', async () => {
      btn.disabled = true;
      try {
        const r = await rpc(config, fn, {target_slug: slug, token: storage(tokenKey)});
        if (r?.ok) { customer = r.customer; toast(t(msg)); render(); }
      } catch {
        toast(t('network'), true);
      } finally {
        btn.disabled = false;
      }
    });
  }
  row.append(coming, arrived);
  panel.append(row, el('p', t('scanHint'), 'muted small'));
  const stats = el('div', undefined, 'info-grid');
  for (const [v, label] of [[customer.total_visits, t('totalVisits')], [customer.rewards, t('rewards')]]) {
    const box = el('div', undefined, 'info'); box.append(el('b', String(v ?? 0)), el('span', label)); stats.append(box);
  }
  panel.append(stats);
  return panel;
}

function infoPanel() {
  const panel = el('div', undefined, 'panel');
  const add = (ico, text, href) => {
    const row = el('div', undefined, 'kv');
    row.append(el('span', ico, 'ico'));
    if (href) { const a = el('a', text); a.href = href; a.target = '_blank'; a.rel = 'noopener'; row.append(a); }
    else row.append(el('p', text));
    panel.append(row);
  };
  if (validWeek(shop.week_hours)) {
    const box = el('div', undefined, 'week');
    const open = openNow(shop.week_hours) && !shop.closed;
    const head = el('div', undefined, 'week-head');
    head.append(el('strong', `🕒 ${t('hours')}`), el('span', open ? `● ${t('openNow')}` : `● ${t('closedNow')}`, open ? 'chip green' : 'chip red'));
    box.append(head);
    shop.week_hours.forEach((d, i) => {
      const row = el('div', undefined, 'week-row' + (i === todayIndex() ? ' today' : ''));
      row.append(el('span', dayName(i, lang)), el('span', d ? dayText(d) : t('dayOff'), d ? 'time' : 'off'));
      box.append(row);
    });
    panel.append(box);
  } else if (shop.hours) add('🕒', `${t('hours')}\n${shop.hours}`);
  return panel.childNodes.length ? panel : null;
}

function render() {
  if (!shop) return;
  document.title = shop.name;
  let appTitle = document.querySelector('meta[name="apple-mobile-web-app-title"]');
  if (!appTitle) { appTitle = document.createElement('meta'); appTitle.name = 'apple-mobile-web-app-title'; document.head.append(appTitle); }
  appTitle.content = shop.name;
  const parts = [];
  const closed = closedBanner(); if (closed) parts.push(closed);
  if (notice) {
    const b = el('div', undefined, `banner ${notice.kind}`);
    b.append(el('span', notice.kind === 'green' ? '🎉' : '⚠️', 'ico'), el('p', notice.text));
    parts.push(b);
  }
  parts.push(bizCard());
  if (customer && shop.booking_enabled) parts.push(myBookingPanel());
  if (customer) {
    parts.push(actions());
    if (canWallet()) parts.push(walletButton());
    const home = el('button', t('addHome'), 'btn ghost'); home.type = 'button';
    home.addEventListener('click', addToHome);
    parts.push(home);
  } else if (pendingCode) {
    parts.push(joinPanel());
  } else {
    const home = el('button', t('saveShop'), 'btn ghost'); home.type = 'button';
    home.addEventListener('click', addToHome);
    parts.push(home);
  }
  const pics = gallery(); if (pics) parts.push(pics);
  const info = infoPanel(); if (info) parts.push(info);
  const legal = el('p', undefined, 'legal');
  const pl = el('a', t('privacy')); pl.href = '/privacy#' + lang;
  const tl = el('a', t('terms')); tl.href = '/terms#' + lang;
  legal.append('MAROC NFC Studio · ', pl, ' · ', tl);
  parts.push(legal);
  root.replaceChildren(...parts);
  fresh = -1;
}

async function wallet(action) {
  const res = await fetch(`${config.supabaseUrl}/functions/v1/wallet-pass`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json', apikey: config.publishableKey,
      Authorization: `Bearer ${config.publishableKey}`},
    body: JSON.stringify({action, slug, token: storage(tokenKey), lang}),
  });
  return res.json().catch(() => ({ok: false}));
}

const walletKey = `nfc_wallet_${slug}`;
const canWallet = () => !/iPhone|iPad|iPod/i.test(navigator.userAgent);

// Right after joining or a stamped visit, offer Google Wallet once per phone.
function walletPrompt() {
  if (storage(walletKey)) return;
  if (!canWallet()) { storage(walletKey, 'home'); addToHome(); return; }
  const {box, panel} = sheet();
  const later = el('button', t('later'), 'btn ghost'); later.type = 'button';
  later.addEventListener('click', () => box.remove());
  panel.append(el('h2', t('walletTitle')), el('p', t('walletText'), 'muted'), walletButton(), later);
}

function walletButton() {
  const btn = el('button', t('wallet'), 'btn wallet'); btn.type = 'button';
  btn.addEventListener('click', async () => {
    btn.disabled = true;
    try {
      const r = await wallet('save');
      if (r?.ok && r.url) { storage(walletKey, '1'); location.href = r.url; return; }
      toast(r?.error === 'not_configured' ? t('walletSoon') : t('walletError'));
    } catch { toast(t('walletError')); }
    btn.disabled = false;
  });
  return btn;
}


// "زيارة واحدة من أصل خمس" / "1 visit of 5"
const AR_NUM = ['', 'واحدة', 'اثنتين', 'ثلاث', 'أربع', 'خمس', 'ست', 'سبع', 'ثماني', 'تسع', 'عشر'];
function visitsText(n, g) {
  if (lang !== 'ar') return t('visitsOf', {n, g});
  const count = n === 0 ? 'لا زيارات بعد' : n === 1 ? 'زيارة واحدة' : n === 2 ? 'زيارتان'
    : n <= 10 ? `${AR_NUM[n] ?? n} زيارات` : `${n} زيارة`;
  return `${count} من أصل ${AR_NUM[g] ?? g}`;
}

/* ---------- Appointments ----------
   Backend RPCs (supabase/migrations/202611090005_bookings.sql):
   nfc_booking_slots, nfc_booking_create, nfc_booking_mine, nfc_booking_cancel. */
const fmtDay = (iso, opts = {weekday: 'long', day: 'numeric', month: 'long'}) => {
  try { return new Intl.DateTimeFormat(lang === 'ar' ? 'ar-MA' : lang, {...opts, timeZone: 'UTC'}).format(new Date(iso + 'T12:00:00Z')); }
  catch { return iso; }
};
const isoDay = d => d.toISOString().slice(0, 10);

async function loadMyBooking() {
  const token = storage(tokenKey);
  if (!token || !shop?.booking_enabled) { myBooking = null; return; }
  try {
    const r = await rpc(config, 'nfc_booking_mine', {target_slug: slug, token});
    myBooking = r?.ok ? r.booking : null;
  } catch { /* keep the previous state */ }
}

// Name + phone before the first booking (joins the shop without a visit).
function detailsStep(panel, done) {
  panel.replaceChildren(el('h2', `📅 ${t('bookBtn')}`), el('p', t('yourDetails'), 'muted small'));
  const name = el('input'); name.className = 'field'; name.placeholder = t('name'); name.autocomplete = 'name'; name.maxLength = 80;
  const phone = el('input'); phone.className = 'field'; phone.placeholder = t('phone'); phone.type = 'tel'; phone.inputMode = 'tel'; phone.dir = 'ltr';
  const go = el('button', t('continue'), 'btn'); go.type = 'button';
  go.addEventListener('click', async () => {
    if (!name.value.trim()) { toast(t('badName'), true); return; }
    if (phone.value.replace(/[^0-9]/g, '').length < 6) { toast(t('badPhone'), true); return; }
    go.disabled = true;
    try {
      const r = await rpc(config, 'nfc_customer_join', {target_slug: slug, customer_name: name.value.trim(), customer_phone: phone.value, code: null});
      if (!r?.ok) { toast(r?.error === 'phone' ? t('badPhone') : t('badName'), true); return; }
      storage(tokenKey, r.token);
      customer = r.customer;
      done();
    } catch { toast(t('network'), true); } finally { go.disabled = false; }
  });
  panel.append(name, phone, go);
}

function bookingSheet() {
  const {box, panel} = sheet();
  panel.classList.add('book');
  if (!storage(tokenKey)) { detailsStep(panel, () => { render(); servicesStep(); }); return; }
  if (myBooking?.status === 'booked' && myBooking.upcoming) {
    panel.append(el('h2', `📅 ${t('bookBtn')}`), el('p', t('bookErr_has_booking'), 'banner amber'));
    const see = el('button', t('myBooking'), 'btn'); see.type = 'button';
    see.addEventListener('click', () => { box.remove(); document.getElementById('my-booking')?.scrollIntoView({behavior: 'smooth'}); });
    panel.append(see);
    return;
  }
  servicesStep();

  function servicesStep() {
    panel.replaceChildren(el('h2', `📅 ${t('bookBtn')}`), el('p', t('chooseService'), 'muted small'));
    const list = el('div', undefined, 'book-list');
    for (const svc of shop.services ?? []) {
      const b = el('button', undefined, 'book-svc'); b.type = 'button';
      b.append(el('b', svc.name), el('span', [`${svc.minutes} ${t('min')}`, svc.price].filter(Boolean).join(' · ')));
      b.addEventListener('click', () => dayStep(svc));
      list.append(b);
    }
    panel.append(list);
  }

  function dayStep(svc) {
    panel.replaceChildren(el('h2', svc.name), el('p', t('chooseDay'), 'muted small'));
    const days = el('div', undefined, 'book-days');
    const week = shop.week_hours;
    const start = new Date();
    for (let i = 0; i < 14; i++) {
      const d = new Date(Date.UTC(start.getFullYear(), start.getMonth(), start.getDate() + i, 12));
      const open = Array.isArray(week) ? !!week[(d.getUTCDay() + 6) % 7] : true;
      const b = el('button', undefined, 'book-day'); b.type = 'button'; b.disabled = !open;
      b.append(el('small', fmtDay(isoDay(d), {weekday: 'short'})), el('b', String(d.getUTCDate())), el('small', fmtDay(isoDay(d), {month: 'short'})));
      b.addEventListener('click', () => timeStep(svc, isoDay(d)));
      days.append(b);
    }
    const back = el('button', `← ${t('back')}`, 'btn ghost small'); back.type = 'button';
    back.addEventListener('click', servicesStep);
    panel.append(days, back);
  }

  async function timeStep(svc, day) {
    panel.replaceChildren(el('h2', svc.name), el('p', fmtDay(day), 'muted'), el('div', undefined, 'spinner'));
    const back = el('button', `← ${t('back')}`, 'btn ghost small'); back.type = 'button';
    back.addEventListener('click', () => dayStep(svc));
    let r;
    try { r = await rpc(config, 'nfc_booking_slots', {target_slug: slug, service_id: svc.id, day}); }
    catch { panel.replaceChildren(el('h2', svc.name), el('p', t('bookErr'), 'banner red'), back); return; }
    const slots = r?.ok ? r.slots ?? [] : [];
    panel.replaceChildren(el('h2', svc.name), el('p', `${fmtDay(day)} · ${t('chooseTime')}`, 'muted small'));
    if (!r?.ok || !slots.length) {
      panel.append(el('p', r?.ok ? t('noSlots') : t('bookErr'), 'banner amber'), back);
      return;
    }
    const grid = el('div', undefined, 'book-times');
    let chosen = null;
    const confirm = el('button', t('confirmBook'), 'btn'); confirm.type = 'button'; confirm.disabled = true;
    for (const time of slots) {
      const b = el('button', time, 'book-time'); b.type = 'button';
      b.addEventListener('click', () => {
        chosen = time;
        grid.querySelectorAll('.book-time').forEach(x => x.classList.toggle('on', x === b));
        confirm.disabled = false;
        confirm.textContent = `${t('confirmBook')} · ${time}`;
      });
      grid.append(b);
    }
    confirm.addEventListener('click', async () => {
      if (!chosen || confirm.disabled) return;
      confirm.disabled = true; // no double submit
      confirm.textContent = t('booking');
      try {
        const res = await rpc(config, 'nfc_booking_create', {target_slug: slug, token: storage(tokenKey), service_id: svc.id, day, start_time: chosen});
        if (res?.ok && res.booking) {
          myBooking = res.booking;
          success(res.booking);
          wallet('sync').catch(() => {});
          return;
        }
        toast(t('bookErr_' + (res?.error ?? '')) === 'bookErr_' + (res?.error ?? '') ? t('bookErr') : t('bookErr_' + res.error), true);
        if (res?.error === 'taken') { timeStep(svc, day); return; }
      } catch { toast(t('network'), true); }
      confirm.disabled = false;
      confirm.textContent = `${t('confirmBook')} · ${chosen}`;
    });
    panel.append(grid, confirm, back);
  }

  function success(k) {
    panel.replaceChildren();
    const ok = el('div', undefined, 'book-ok');
    ok.append(el('div', '✓', 'book-check'), el('h2', t('booked')), el('p', k.service, 'book-big'),
      el('p', `${fmtDay(k.day)} · ${k.time}`, 'book-big'));
    const close = el('button', t('ok'), 'btn'); close.type = 'button';
    close.addEventListener('click', () => { box.remove(); render(); });
    panel.append(ok, close);
  }
}

// "حجزي": status of the appointment and cancellation.
function myBookingPanel() {
  const k = myBooking;
  const panel = el('section', undefined, 'panel my-booking');
  panel.id = 'my-booking';
  panel.append(el('h2', `🗓️ ${t('myBooking')}`));
  if (!k) {
    panel.append(el('p', t('noBooking'), 'muted small'));
    const b = el('button', t('bookBtn'), 'btn'); b.type = 'button';
    b.addEventListener('click', bookingSheet);
    panel.append(b);
    return panel;
  }
  const status = k.status === 'booked' && !k.upcoming ? 'now' : k.status;
  const card = el('div', undefined, 'book-card ' + k.status);
  card.append(el('b', k.service), el('span', `${fmtDay(k.day)} · ${k.time}`, 'bc-ltr-auto'),
    el('span', t('status_' + status), 'chip ' + (k.status === 'booked' ? 'green' : k.status === 'cancelled' ? 'red' : '')));
  if (k.status === 'cancelled' && k.cancelled_by === 'owner') card.append(el('p', t('cancelledByShop'), 'small muted'));
  panel.append(card);
  if (k.status === 'booked' && k.upcoming) {
    const cancel = el('button', t('cancelBooking'), 'btn ghost'); cancel.type = 'button';
    cancel.addEventListener('click', () => {
      const {box, panel: p} = sheet();
      p.append(el('h2', t('cancelBooking')), el('p', `${k.service} · ${fmtDay(k.day)} · ${k.time}`), el('p', t('cancelConfirm'), 'muted'));
      const yes = el('button', t('cancelYes'), 'btn red'); yes.type = 'button';
      const no = el('button', t('cancelNo'), 'btn ghost'); no.type = 'button';
      no.addEventListener('click', () => box.remove());
      yes.addEventListener('click', async () => {
        yes.disabled = true; no.disabled = true;
        try {
          const r = await rpc(config, 'nfc_booking_cancel', {target_slug: slug, token: storage(tokenKey), booking: k.id});
          if (r?.ok) {
            myBooking = r.booking;
            box.remove();
            toast(t('cancelledOk'));
            wallet('sync').catch(() => {});
            render();
            return;
          }
          toast(t('bookErr'), true);
        } catch { toast(t('network'), true); }
        yes.disabled = false; no.disabled = false;
      });
      p.append(yes, no);
    });
    panel.append(cancel);
  } else if (shop.booking_enabled) {
    const b = el('button', t('bookBtn'), 'btn'); b.type = 'button';
    b.addEventListener('click', bookingSheet);
    panel.append(b);
  }
  return panel;
}

function sheet() {
  const box = el('div', undefined, 'sheet');
  const panel = el('div', undefined, 'sheet-panel');
  box.append(panel);
  box.addEventListener('click', e => { if (e.target === box) box.remove(); });
  document.body.append(box);
  return {box, panel};
}

function addToHome() {
  if (installEvent) { installEvent.prompt(); installEvent = null; return; }
  const {box, panel} = sheet();
  const ios = /iphone|ipad|ipod/i.test(navigator.userAgent);
  // iPhone: the icon opens exactly this address, so it must carry the card.
  const token = storage(tokenKey);
  if (ios && token) history.replaceState(null, '', `${location.pathname}#k=${token}`);
  const ok = el('button', t('ok'), 'btn'); ok.type = 'button';
  ok.addEventListener('click', () => box.remove());
  panel.append(el('h2', t('addHome')), el('p', ios ? t('iosHelp') : t('androidHelp')), ok);
}

// Owner login from the customer page (hidden entry) → dashboard.
function ownerLogin() {
  const {box, panel} = sheet();
  const pass = el('input'); pass.type = 'password'; pass.className = 'field'; pass.placeholder = t('password'); pass.autocomplete = 'current-password';
  const go = el('button', t('login'), 'btn'); go.type = 'button';
  const forgot = el('button', t('forgot'), 'btn ghost'); forgot.type = 'button';
  const info = el('p', '', 'banner amber small'); info.hidden = true;
  const submit = async () => {
    go.disabled = true;
    try {
      const r = await rpc(config, 'nfc_shop_login', {target_slug: slug, password: pass.value});
      if (!r?.ok) {
        info.textContent = r?.error === 'locked' ? t('locked') : r?.left ? t('triesLeft', {n: r.left}) : t('wrongPass');
        info.hidden = false;
        if (r?.error === 'locked') { pass.disabled = true; go.hidden = true; }
        return;
      }
      storage(`nfc_shop_${slug}`, r.session);
      location.href = `/s/${slug}`;
    } catch {
      toast(t('network'), true);
    } finally {
      go.disabled = false;
    }
  };
  go.addEventListener('click', submit);
  pass.addEventListener('keydown', e => { if (e.key === 'Enter') submit(); });
  forgot.addEventListener('click', async () => {
    try { await rpc(config, 'nfc_shop_forgot', {target_slug: slug}); } catch { /* same message */ }
    box.remove();
    const s = sheet();
    const ok = el('button', t('ok'), 'btn'); ok.type = 'button'; ok.addEventListener('click', () => s.box.remove());
    s.panel.append(el('h2', '📨'), el('p', t('forgotSent')), ok);
  });
  panel.append(el('h2', `🔐 ${t('ownerAccess')}`), pass, info, go, forgot);
  setTimeout(() => pass.focus(), 60);
}

async function start() {
  applyLang();
  langSwitcher(langs, render);
  if (!slug) { status(t('unavailable'), t('unavailableText')); return; }
  try {
    config = await loadConfig();
    shop = await rpc(config, 'nfc_shop_public', {target_slug: slug});
    if (!shop) { status(t('unavailable'), t('unavailableText')); return; }
    applyColors(shop);
    applyTheme(shop.theme);
    // An iPhone home-screen app has its own storage: its start URL carries
    // the card token in the hash (#k=…), set when the customer added it.
    const fromHash = /(?:^#|&)k=([0-9a-f]{48})/.exec(location.hash)?.[1];
    if (fromHash) storage(tokenKey, fromHash);
    const token = storage(tokenKey);
    if (token) {
      if (pendingCode) {
        const r = await rpc(config, 'nfc_customer_visit', {target_slug: slug, token, code: pendingCode});
        pendingCode = null;
        if (r?.error === 'card') storage(tokenKey, null);
        else {
          customer = r.customer;
          if (r.ok) { notice = {kind: 'green', text: r.free ? t('stampedFree') : t('stamped')}; fresh = r.free ? -1 : customer.stamps - 1; wallet('sync').catch(() => {}); setTimeout(walletPrompt, 1200); }
          else notice = {kind: 'amber', text: r.error === 'too_soon' ? t('tooSoon') : t('codeExpired')};
        }
      }
      if (!customer && storage(tokenKey)) {
        const r = await rpc(config, 'nfc_customer_card', {target_slug: slug, token});
        if (r?.ok) customer = r.customer;
        else storage(tokenKey, null);
      }
    }
    await loadMyBooking();
    render();
    // Links from Google Wallet: #book opens booking, #mybooking shows it.
    if (/(?:^#|&)book(?:&|$)/.test(location.hash) && shop.booking_enabled) bookingSheet();
    if (/(?:^#|&)mybooking(?:&|$)/.test(location.hash)) document.getElementById('my-booking')?.scrollIntoView({behavior: 'smooth'});
  } catch (e) {
    console.error(e);
    status(t('network'), '');
  }
}
start();
