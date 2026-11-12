import {t, lang, applyLang, langSwitcher} from '/i18n.mjs';
import {applyTheme, ICONS, stampIcon} from '/themes.mjs';
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
if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(() => {});

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
  if (shop.menu_url) {
    const m = ext(el('a', undefined, 'bc-menu'), shop.menu_url);
    m.append(el('span', '🍽️'), el('b', t('menuBtn')));
    card.append(m);
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
  if (shop.loyalty_mode === 'points') {
    const pts = customer?.stamps ?? 0;
    const bar = el('div', undefined, 'bc-bar');
    const fill = el('i'); fill.style.width = `${Math.min(100, Math.round((pts / goal) * 100))}%`;
    bar.append(fill);
    const big = el('p', undefined, 'bc-pts');
    big.append(el('b', String(pts)), el('span', ` / ${goal} ${t('pointsWord')}`));
    box.append(big, bar, el('p', t('perPoint', {n: shop.points_per ?? 10}), 'bc-progress small'));
    if (customer?.next_free) box.append(el('p', t('giftReady'), 'bc-progress'));
    const rw0 = el('p', undefined, 'bc-reward');
    rw0.append(svg('gift', 'ico'), el('span', t('rewardLabel')), el('b', reward));
    box.append(rw0);
    sectorInfo(box);
    return box;
  }
  const row = el('div', undefined, 'bc-dots');
  row.style.setProperty('--cols', String(Math.min(goal + 1, 7)));
  for (let i = 0; i < goal; i++) {
    const d = el('span', undefined, 'bc-dot' + (i < stamps ? ' on' : '') + (i === fresh ? ' pop' : ''));
    if (i < stamps) d.innerHTML = stampIcon(shop);
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
  sectorInfo(box);
  return box;
}

// Sector lines under the points: birthday, gym subscription, car wash.
function sectorInfo(box) {
  if (!customer) return;
  const line = (icon, label, value, cls = '') => {
    const p = el('p', undefined, 'bc-info ' + cls);
    p.append(el('span', icon), el('span', label), el('b', value));
    box.append(p);
  };
  const day = (iso) => { try { return new Intl.DateTimeFormat(lang === 'ar' ? 'ar-MA' : lang, {day: 'numeric', month: 'long', year: 'numeric'}).format(new Date(iso)); } catch { return iso; } };
  if (customer.birthday) {
    const b = el('p', `🎂 ${t('happyBirthday')}${shop.birthday_reward ? ` — ${t('birthdayGift')}: ${shop.birthday_reward}` : ''}`, 'banner green');
    box.prepend(b);
  }
  if (shop.industry === 'gym' && customer.expiry_date) {
    line('🗓️', t('subscriptionUntil'), day(customer.expiry_date + 'T12:00:00'), customer.expired ? 'bad' : '');
    if (customer.expired) box.append(el('p', t('subscriptionExpired'), 'banner amber'));
  }
  if (shop.industry === 'carwash') {
    if (customer.vehicle_type) line('🚘', t('vehicle'), t('vehicle_' + customer.vehicle_type));
    if (customer.last_visit_at) line('🧽', t('lastWash'), day(customer.last_visit_at));
  }
}

// Optional extras at sign-up: birthday (all sectors) and vehicle (car wash).
function extraFields() {
  const wrap = el('div', undefined, 'extra-fields');
  const dl = el('label', `🎂 ${t('dobLabel')}`, 'small muted');
  const dob = el('input'); dob.type = 'date'; dob.className = 'field'; dob.max = new Date().toISOString().slice(0, 10); dob.min = '1920-01-01';
  wrap.append(dl, dob);
  let veh = null;
  if (shop.industry === 'carwash') {
    veh = el('select'); veh.className = 'field';
    for (const [v, label] of [['', t('vehiclePick')], ['small', t('vehicle_small')], ['suv', t('vehicle_suv')], ['4x4', t('vehicle_4x4')]]) {
      const o = el('option', label); o.value = v; veh.append(o);
    }
    wrap.append(el('label', `🚘 ${t('vehicle')}`, 'small muted'), veh);
  }
  return {
    node: wrap,
    async save() {
      const birth = dob.value || null, vehicle = veh?.value || null;
      if (!birth && !vehicle) return;
      try {
        const r = await rpc(config, 'nfc_customer_profile', {target_slug: slug, token: storage(tokenKey), birth_date: birth, vehicle});
        if (r?.ok) customer = r.customer;
      } catch { /* optional */ }
    },
  };
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
  card.append(head, slotsGrid(goal, stamps, nextFree, fresh, industry(shop).icon));
  const bar = el('div', undefined, 'progress');
  const fill = el('i'); fill.style.width = `${Math.min(100, Math.round((stamps / goal) * 100))}%`;
  bar.append(fill);
  card.append(bar);
  card.append(el('p', nextFree ? `${t('giftReady')} · ${reward}` : `${t('left', {n: Math.max(0, goal - stamps)})} · 🎁 ${reward}`, 'goal-line'));
  return card;
}

// Name (+ phone when the shop's rule asks for it). Booking always needs a way
// to call, unless the shop asks no phone at all.
const phoneRule = () => shop.phone_policy ?? 'optional';
function personFields(forBooking = false) {
  const rule = phoneRule();
  const needed = rule === 'required' || (forBooking && rule === 'optional');
  const name = el('input'); name.className = 'field'; name.placeholder = t('fullName'); name.autocomplete = 'name'; name.maxLength = 80;
  const nodes = [name];
  let phone = null;
  if (rule !== 'none') {
    phone = el('input'); phone.className = 'field'; phone.type = 'tel'; phone.autocomplete = 'tel'; phone.inputMode = 'tel'; phone.dir = 'ltr';
    phone.placeholder = needed ? t('phoneForCall') : t('phoneOptional');
    nodes.push(phone);
  }
  return {
    nodes, name, phone,
    check() {
      if (name.value.trim().length < 2) { toast(t('badName'), true); name.focus(); return false; }
      const digits = (phone?.value ?? '').replace(/[^0-9]/g, '');
      if ((needed || digits) && digits.length < 6) { toast(t('badPhone'), true); phone?.focus(); return false; }
      return true;
    },
    values: () => ({customer_name: name.value.trim(), customer_phone: phone?.value ?? ''}),
  };
}

// A refused join: the number already has a card here -> the lost-card path.
function joinError(r, panel, f) {
  if (r?.error === 'exists') {
    panel.querySelector('.exists-box')?.remove();
    const box = el('div', undefined, 'banner amber exists-box');
    const b = el('button', `🔑 ${t('lostCardBtn')}`, 'btn small'); b.type = 'button';
    b.addEventListener('click', () => { document.querySelector('.sheet')?.remove(); recoverSheet(f.values()); });
    box.append(el('p', t('phoneExists')), b);
    panel.append(box);
    return;
  }
  toast(r?.error === 'phone' ? t('badPhone') : t('badName'), true);
}

// Lost card: name + phone send a request; the owner, who sees the person,
// approves it on his screen and the card comes to this phone.
const recoverKey = `nfc_recover_${slug}`;
function recoverSheet(prefill = {}) {
  const {box, panel} = sheet();
  panel.append(el('h2', `🔑 ${t('haveCardTitle')}`), el('p', t('recoverNote'), 'muted small'));
  const f = personFields(true);
  f.name.value = prefill.customer_name ?? '';
  if (f.phone) f.phone.value = prefill.customer_phone ?? '';
  const go = el('button', t('recoverSend'), 'btn'); go.type = 'button';
  go.addEventListener('click', async () => {
    if (!f.check()) return;
    go.disabled = true;
    try {
      const r = await rpc(config, 'nfc_customer_recover', {target_slug: slug, ...f.values()});
      if (!r?.ok) { toast(r?.error === 'too_many' ? t('recoverTooMany') : t('recoverNotFound'), true); return; }
      storage(recoverKey, JSON.stringify({id: r.request, token: r.token, name: f.name.value.trim()}));
      waitRecover(box, panel);
    } catch { toast(t('network'), true); } finally { go.disabled = false; }
  });
  panel.append(...f.nodes, go);
}

function waitRecover(box, panel) {
  let req = null;
  try { req = JSON.parse(storage(recoverKey) ?? 'null'); } catch { /* none */ }
  if (!req?.id) { box.remove(); return; }
  panel.replaceChildren(el('div', '⏳', 'wait-ico'), el('h2', t('recoverWait')), el('p', req.name, 'book-big'), el('p', t('recoverWaitNote'), 'muted small'));
  const cancel = el('button', t('recoverCancel'), 'link-btn'); cancel.type = 'button';
  cancel.addEventListener('click', () => { storage(recoverKey, null); box.remove(); });
  panel.append(cancel);
  const end = (msg) => {
    storage(recoverKey, null);
    panel.replaceChildren(el('div', '✋', 'wait-ico'), el('p', msg));
    const ok = el('button', t('close'), 'btn ghost'); ok.type = 'button';
    ok.addEventListener('click', () => box.remove());
    panel.append(ok);
  };
  const poll = async () => {
    if (!box.isConnected) return;
    try {
      const r = await rpc(config, 'nfc_customer_recover_status', {target_slug: slug, request: req.id, token: req.token});
      if (!r?.ok) { end(t('recoverRefused')); return; }
      if (r.status === 'approved') {
        storage(tokenKey, req.token); storage(recoverKey, null);
        customer = r.customer;
        box.remove();
        toast(t('cardBack'));
        await loadMyBooking();
        render(); watchTurn();
        wallet('sync').catch(() => {});
        return;
      }
      if (r.status !== 'pending') { end(t('recoverRefused')); return; }
    } catch { /* try again */ }
    setTimeout(poll, 4000);
  };
  setTimeout(poll, 3000);
}

// The free reward waits for the owner's yes: show it big, the owner taps ✓.
function claimBanner() {
  if (!customer?.claim) return null;
  const box = el('section', undefined, 'claim-alert');
  box.id = 'claim';
  box.append(el('div', '🎁', 'claim-ico'), el('b', t('claimTitle'), 'turn-title'),
    el('p', customer.reward ?? shop.reward ?? '', 'claim-reward'), el('p', t('claimShow'), 'small'),
    el('div', undefined, 'dots'));
  return box;
}

function joinPanel() {
  const panel = el('div', undefined, 'panel');
  panel.append(el('h2', `✨ ${t('join')}`), el('p', t('joinText'), 'muted small'));
  const f = personFields(false);
  const extra = extraFields();
  const btn = el('button', t('joinBtn'), 'btn'); btn.type = 'button';
  btn.addEventListener('click', async () => {
    if (!f.check()) return;
    btn.disabled = true;
    try {
      const r = await rpc(config, 'nfc_customer_join', {target_slug: slug, ...f.values(), code: pendingCode});
      if (!r?.ok) { joinError(r, panel, f); return; }
      storage(tokenKey, r.token);
      customer = r.customer;
      await extra.save();
      if (r.visit) { notice = {kind: 'green', text: r.visit.free ? t('stampedFree') : scanText(r.visit)}; fresh = customer.stamps - 1; }
      pendingCode = null;
      render();
      watchTurn();
      setTimeout(walletPrompt, 900);
    } catch {
      toast(t('network'), true);
    } finally {
      btn.disabled = false;
    }
  });
  panel.append(...f.nodes, extra.node, btn);
  return panel;
}

// "Your turn": the shop called this customer. One big answer button.
function turnBanner() {
  if (!customer?.called) return null;
  const box = el('section', undefined, 'turn-alert' + (customer.coming ? ' answered' : ''));
  box.id = 'turn';
  if (customer.coming) {
    box.append(el('b', t('comingTurn'), 'turn-title'), el('p', t('turnSeeYou', {shop: shop.name}), 'small'));
    return box;
  }
  box.append(el('div', '🔔', 'turn-bell'), el('b', t('turnTitle'), 'turn-title'), el('p', t('turnBody', {shop: shop.name})));
  const go = el('button', t('imComing'), 'btn turn-go'); go.type = 'button';
  go.addEventListener('click', async () => {
    go.disabled = true;
    try {
      const r = await rpc(config, 'nfc_customer_coming', {target_slug: slug, token: storage(tokenKey)});
      if (r?.ok) { customer = r.customer; toast(t('comingSent')); render(); return; }
      toast(t('network'), true);
    } catch { toast(t('network'), true); }
    go.disabled = false;
  });
  box.append(go);
  return box;
}

// Rings once when the shop calls: sound, vibration and a system notification.
let audioCtx = null;
function ringTurn() {
  try {
    audioCtx ??= new (window.AudioContext || window.webkitAudioContext)();
    const now = audioCtx.currentTime;
    for (const [i, f] of [[0, 880], [0.2, 1175], [0.4, 1568], [0.9, 880], [1.1, 1175], [1.3, 1568]]) {
      const o = audioCtx.createOscillator(), g = audioCtx.createGain();
      o.frequency.value = f; o.type = 'sine';
      g.gain.setValueAtTime(0.0001, now + i);
      g.gain.exponentialRampToValueAtTime(0.4, now + i + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, now + i + 0.28);
      o.connect(g).connect(audioCtx.destination); o.start(now + i); o.stop(now + i + 0.3);
    }
  } catch { /* audio not available */ }
  try { navigator.vibrate?.([300, 120, 300, 120, 600]); } catch { /* optional */ }
  try {
    if (document.visibilityState !== 'visible' && window.Notification?.permission === 'granted') {
      new Notification(t('turnTitle'), {body: t('turnBody', {shop: shop.name}), tag: 'turn'});
    }
  } catch { /* optional */ }
}

// While the page is open the card refreshes itself, so "your turn" shows up
// without reloading.
let watchTimer = null;
function watchTurn() {
  clearTimeout(watchTimer);
  const tick = async () => {
    const token = storage(tokenKey);
    if (customer && token && document.visibilityState === 'visible') {
      try {
        const r = await rpc(config, 'nfc_customer_card', {target_slug: slug, token});
        if (r?.ok) {
          const before = JSON.stringify([customer, myBooking]);
          const was = customer;
          customer = r.customer;
          await loadMyBooking();
          if (!was.called && customer.called) ringTurn();
          // The owner said yes to the reward.
          if (was.claim && !customer.claim && customer.rewards > was.rewards) {
            notice = {kind: 'green', text: t('stampedFree')};
            try { navigator.vibrate?.([120, 60, 120]); } catch { /* optional */ }
            wallet('sync').catch(() => {});
          }
          if (JSON.stringify([customer, myBooking]) !== before && !document.querySelector('.sheet')) {
            render();
            if (!was.called && customer.called) document.getElementById('turn')?.scrollIntoView({behavior: 'smooth', block: 'center'});
          }
        } else if (r?.error === 'card' || r?.ok === false) {
          // The card moved to another phone (lost-card request): this one is out.
          storage(tokenKey, null); customer = null; render(); return;
        }
      } catch { /* try again next time */ }
    }
    watchTimer = setTimeout(tick, customer?.claim ? 4000 : 12000);
  };
  watchTimer = setTimeout(tick, customer?.claim ? 4000 : 12000);
}

function actions() {
  const panel = el('div', undefined, 'panel');
  panel.append(el('p', t('scanHint'), 'muted small'));
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
  const claim = claimBanner(); if (claim) parts.push(claim);
  const turn = turnBanner(); if (turn) parts.push(turn);
  if (notice) {
    const b = el('div', undefined, `banner ${notice.kind}`);
    b.append(el('span', notice.kind === 'green' ? '🎉' : '⚠️', 'ico'), el('p', notice.text));
    parts.push(b);
  }
  parts.push(bizCard());
  if (customer && shop.booking_enabled && myBooking) parts.push(myBookingPanel());
  if (customer) {
    parts.push(actions());
    if (canWallet()) parts.push(walletButton());
    if (!installed()) {
      const home = el('button', t('addHome'), 'btn ghost'); home.type = 'button';
      home.addEventListener('click', addToHome);
      parts.push(home);
    }
  } else if (pendingCode) {
    parts.push(joinPanel());
  } else {
    if (canWallet()) parts.push(walletButton());
    if (!installed()) {
      const home = el('button', t('saveShop'), 'btn ghost'); home.type = 'button';
      home.addEventListener('click', addToHome);
      parts.push(home);
    }
    if (phoneRule() !== 'none') {
      const back = el('button', t('lostCard'), 'link-btn'); back.type = 'button';
      back.addEventListener('click', () => recoverSheet());
      parts.push(back);
    }
  }
  const info = infoPanel(); if (info) parts.push(info);
  const legal = el('p', undefined, 'legal');
  const pl = el('a', t('privacy')); pl.href = '/privacy#' + lang;
  const tl = el('a', t('terms')); tl.href = '/terms#' + lang;
  legal.append('TapMaroc · ', pl, ' · ', tl);
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
  const save = async () => {
    btn.disabled = true;
    try {
      const r = await wallet('save');
      if (r?.ok && r.url) { storage(walletKey, '1'); location.href = r.url; return; }
      toast(r?.error === 'not_configured' ? t('walletSoon') : t('walletError'));
    } catch { toast(t('walletError')); }
    btn.disabled = false;
  };
  btn.addEventListener('click', () => {
    if (storage(tokenKey)) { save(); return; }
    // Not a member yet: name + phone in one small step, then straight to Wallet.
    const {box, panel} = sheet();
    detailsStep(panel, () => { box.remove(); render(); save(); }, t('wallet'), `${t('walletDetails')} ${t('sameDetails')}`);
  });
  return btn;
}

// "زيارة واحدة من أصل خمس" / "1 visit of 5"
const AR_NUM = ['', 'واحدة', 'اثنتين', 'ثلاث', 'أربع', 'خمس', 'ست', 'سبع', 'ثماني', 'تسع', 'عشر'];
// What one stamp is called, by sector: [one, two, 3-10, feminine?].
const AR_UNIT = {
  cafe: ['كوب', 'كوبان', 'أكواب', false], carwash: ['غسلة', 'غسلتان', 'غسلات', true],
  snack: ['طلب', 'طلبان', 'طلبات', false], gym: ['حصة', 'حصتان', 'حصص', true],
};
const AR_MASC = ['', 'واحد', 'اثنين', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة', 'عشرة'];
function visitsText(n, g) {
  if (shop.loyalty_mode === 'points') return t('pointsOf', {n, g});
  const u = AR_UNIT[shop.industry];
  if (lang !== 'ar') return t(u ? `unitsOf_${shop.industry}` : 'visitsOf', {n, g});
  const [one, two, many, fem] = u ?? ['زيارة', 'زيارتان', 'زيارات', true];
  // Arabic counting: feminine nouns take the masculine number word and vice versa.
  const num = (k) => (fem ? AR_NUM : AR_MASC)[k] ?? k;
  const count = n === 0 ? `لا ${many} بعد` : n === 1 ? `${one} ${fem ? 'واحدة' : 'واحد'}` : n === 2 ? two
    : n <= 10 ? `${num(n)} ${many}` : `${n} ${one}`;
  return `${count} من أصل ${num(g)}`;
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
function detailsStep(panel, done, title = `📅 ${t('bookBtn')}`, note = `${t('yourDetails')} ${t('sameDetails')}`) {
  panel.replaceChildren(el('h2', title), el('p', note, 'muted small'));
  const f = personFields(true);
  const extra = extraFields();
  const go = el('button', t('continue'), 'btn'); go.type = 'button';
  go.addEventListener('click', async () => {
    if (!f.check()) return;
    go.disabled = true;
    try {
      const r = await rpc(config, 'nfc_customer_join', {target_slug: slug, ...f.values(), code: null});
      if (!r?.ok) { joinError(r, panel, f); return; }
      storage(tokenKey, r.token);
      customer = r.customer;
      await extra.save();
      done();
    } catch { toast(t('network'), true); } finally { go.disabled = false; }
  });
  panel.append(...f.nodes, extra.node, go);
}

// Message after a scan: points shops say how many points the bill gave.
function scanText(v) {
  if (shop.loyalty_mode === 'points' && v?.points != null) return t('pointsAdded', {n: v.points, a: v.amount ?? ''});
  if (shop.industry === 'gym') return t('checkedIn');
  return t('stamped');
}

const svcLabel = (name) => name === 'موعد' ? t('appointment') : name;

function bookingSheet() {
  const svcs = shop.book_services ?? shop.services ?? [];
  const svcName = (svc) => svc.id === 'visit' ? t('appointment') : svc.name;
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
    // Only one service (or none listed): go straight to choosing the day.
    if (svcs.length === 1) { dayStep(svcs[0]); return; }
    panel.replaceChildren(el('h2', `📅 ${t('bookBtn')}`), el('p', t('chooseService'), 'muted small'));
    const list = el('div', undefined, 'book-list');
    for (const svc of svcs) {
      const b = el('button', undefined, 'book-svc'); b.type = 'button';
      b.append(el('b', svcName(svc)), el('span', [`${svc.minutes} ${t('min')}`, svc.price].filter(Boolean).join(' · ')));
      b.addEventListener('click', () => dayStep(svc));
      list.append(b);
    }
    panel.append(list);
  }

  function dayStep(svc) {
    panel.replaceChildren(el('h2', `📅 ${svcName(svc)}`), el('p', t('chooseDay'), 'muted small'));
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
    panel.append(days);
    if (svcs.length > 1) panel.append(back);
  }

  async function timeStep(svc, day) {
    panel.replaceChildren(el('h2', svcName(svc)), el('p', fmtDay(day), 'muted'), el('div', undefined, 'spinner'));
    const back = el('button', `← ${t('back')}`, 'btn ghost small'); back.type = 'button';
    back.addEventListener('click', () => dayStep(svc));
    let r;
    try { r = await rpc(config, 'nfc_booking_slots', {target_slug: slug, service_id: svc.id, day}); }
    catch { panel.replaceChildren(el('h2', svcName(svc)), el('p', t('bookErr'), 'banner red'), back); return; }
    const slots = r?.ok ? r.slots ?? [] : [];
    panel.replaceChildren(el('h2', svcName(svc)), el('p', `${fmtDay(day)} · ${t('chooseTime')}`, 'muted small'));
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
          // So "your turn" can ring even when the phone is in the pocket.
          try { if (window.Notification?.permission === 'default') Notification.requestPermission().catch(() => {}); } catch { /* optional */ }
          watchTurn();
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
    ok.append(el('div', '✓', 'book-check'), el('h2', t('booked')), el('p', svcLabel(k.service), 'book-big'),
      el('p', `${fmtDay(k.day)} · ${k.time}`, 'book-big'));
    panel.append(ok);
    // Keep the card like an app: Google Wallet first (Android), or the home screen.
    const keep = [];
    if (canWallet() && !storage(walletKey)) keep.push(walletButton());
    if (!installed()) {
      const home = el('button', t('addHome'), 'btn ghost'); home.type = 'button';
      home.addEventListener('click', addToHome);
      keep.push(home);
    }
    if (keep.length) panel.append(el('p', t('keepCard'), 'keep-note'), ...keep);
    const close = el('button', keep.length ? t('later') : t('ok'), keep.length ? 'btn ghost small' : 'btn'); close.type = 'button';
    close.addEventListener('click', () => { box.remove(); render(); });
    panel.append(close);
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
    return panel;
  }
  const status = k.status === 'booked' && !k.upcoming ? 'now' : k.status;
  const card = el('div', undefined, 'book-card ' + k.status);
  card.append(el('b', svcLabel(k.service)), el('span', `${fmtDay(k.day)} · ${k.time}`, 'bc-ltr-auto'),
    el('span', t('status_' + status), 'chip ' + (k.status === 'booked' ? 'green' : k.status === 'cancelled' ? 'red' : '')));
  if (k.status === 'cancelled' && k.cancelled_by === 'owner') card.append(el('p', t('cancelledByShop'), 'small muted'));
  panel.append(card);
  if (k.status === 'booked' && k.upcoming) {
    const cancel = el('button', t('cancelBooking'), 'btn ghost'); cancel.type = 'button';
    cancel.addEventListener('click', () => {
      const {box, panel: p} = sheet();
      p.append(el('h2', t('cancelBooking')), el('p', `${svcLabel(k.service)} · ${fmtDay(k.day)} · ${k.time}`), el('p', t('cancelConfirm'), 'muted'));
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

const installed = () => matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;

// One tap on Android (the browser's own install window); on iPhone Apple
// allows no button, so we show the two taps with pictures.
async function addToHome() {
  const ios = /iphone|ipad|ipod/i.test(navigator.userAgent);
  const token = storage(tokenKey);
  // The icon opens exactly this address, so it must carry the card.
  if (token) history.replaceState(null, '', `${location.pathname}#k=${token}`);
  if (installEvent) {
    const ev = installEvent; installEvent = null;
    try {
      await ev.prompt();
      const choice = await ev.userChoice;
      if (choice?.outcome === 'accepted') toast(t('installed'));
    } catch { /* fall back to the guide below */ }
    return;
  }
  const {box, panel} = sheet();
  panel.append(el('h2', t('addHome')));
  const steps = el('div', undefined, 'how');
  const step = (n, icon, text) => { const r = el('div', undefined, 'how-step'); r.append(el('span', String(n), 'how-n'), el('span', icon, 'how-ico'), el('p', text)); return r; };
  if (ios) {
    steps.append(step(1, '⬆️', t('iosStep1')), step(2, '➕', t('iosStep2')), step(3, '✅', t('iosStep3')));
  } else {
    steps.append(step(1, '⋮', t('androidStep1')), step(2, '📲', t('androidStep2')), step(3, '✅', t('iosStep3')));
  }
  const ok = el('button', t('ok'), 'btn'); ok.type = 'button';
  ok.addEventListener('click', () => box.remove());
  panel.append(steps, ok);
  if (ios) { const arrow = el('div', '⬇️', 'how-arrow'); box.append(arrow); }
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
          if (r.ok && r.claim) { /* the reward waits for the owner: claimBanner */ }
          else if (r.ok) { notice = {kind: 'green', text: r.free ? t('stampedFree') : scanText(r)}; fresh = r.free ? -1 : customer.stamps - 1; wallet('sync').catch(() => {}); setTimeout(walletPrompt, 1200); }
          else notice = {kind: 'amber', text: ({too_soon: t('tooSoon'), no_amount: t('noAmount'), expired: t('subscriptionExpired')})[r.error] ?? t('codeExpired')};
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
    watchTurn();
    if (!customer && storage(recoverKey)) { const {box, panel} = sheet(); waitRecover(box, panel); }
    // Keep a saved Google Wallet card up to date with the shop's design (every 6 h at most).
    if (customer) {
      const k = `nfc_wsync_${slug}`, last = Number(storage(k) ?? 0);
      if (Date.now() - last > 6 * 3600e3) { storage(k, String(Date.now())); wallet('sync').catch(() => {}); }
    }
    // Links from Google Wallet: #book opens booking, #mybooking shows it.
    if (/(?:^#|&)book(?:&|$)/.test(location.hash) && shop.booking_enabled) bookingSheet();
    if (/(?:^#|&)mybooking(?:&|$)/.test(location.hash)) document.getElementById('my-booking')?.scrollIntoView({behavior: 'smooth'});
  } catch (e) {
    console.error(e);
    status(t('network'), '');
  }
}
start();
