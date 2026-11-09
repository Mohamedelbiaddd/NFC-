import {t, lang, applyLang, langSwitcher} from '/i18n.mjs';
import {applyTheme, ICONS} from '/themes.mjs';
import {loadConfig, rpc, slugFrom, el, applyColors, toast, storage, bannerStrip, industry, unit,
  slotsGrid, safeImage, formatDate, dayName, todayIndex, validWeek, openNow, socialLink, industryLabel} from '/loyalty.mjs';

const root = document.getElementById('app');
const langs = document.getElementById('langs');
const slug = slugFrom('c');
const tokenKey = `nfc_card_${slug}`;
// The rotating code arrives as ?t=…; it is used once and removed from the URL.
let pendingCode = new URLSearchParams(location.search).get('t');
if (pendingCode && !/^[0-9a-f]{8}$/i.test(pendingCode)) pendingCode = null;
if (pendingCode) history.replaceState(null, '', location.pathname);

let config = null, shop = null, customer = null, notice = null, fresh = -1;
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
    txt.append(el('span', t('hours'), 'bc-small'), el('b', today === undefined ? shop.hours : today ? `${today.o} – ${today.c}` : t('dayOff'), 'bc-ltr'));
    h.append(svg('clock', 'bc-ic'), txt);
    tiles.append(h);
  }
  if (tiles.childNodes.length) body.append(tiles);
  // Phone | call
  const tel = socialLink('phone', shop.phone);
  if (tel) {
    const row = el('div', undefined, 'bc-box bc-phone');
    const num = el('div', undefined, 'bc-tile');
    num.append(svg('phone', 'bc-ic'), el('b', shop.phone, 'bc-ltr'));
    const call = ext(el('a', undefined, 'bc-call'), tel.href);
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
  body.append(points());
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
    ? (customer.next_free ? `${t('giftReady')} · ${reward}` : t('pointsOf', {n: stamps, g: goal + 1}) + ` · 🎁 ${reward}`)
    : `${t('programText', {n: goal, r: reward})} — ${t('programHow')}`, 'bc-small'));
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
      row.append(el('span', dayName(i, lang)), el('span', d ? `${d.o} – ${d.c}` : t('dayOff'), d ? 'time' : 'off'));
      box.append(row);
    });
    panel.append(box);
  } else if (shop.hours) add('🕒', `${t('hours')}\n${shop.hours}`);
  return panel.childNodes.length ? panel : null;
}

function render() {
  if (!shop) return;
  document.title = shop.name;
  const parts = [];
  const closed = closedBanner(); if (closed) parts.push(closed);
  if (notice) {
    const b = el('div', undefined, `banner ${notice.kind}`);
    b.append(el('span', notice.kind === 'green' ? '🎉' : '⚠️', 'ico'), el('p', notice.text));
    parts.push(b);
  }
  parts.push(bizCard());
  if (customer) {
    parts.push(actions());
    if (canWallet()) parts.push(walletButton());
    const home = el('button', t('addHome'), 'btn ghost'); home.type = 'button';
    home.addEventListener('click', addToHome);
    parts.push(home);
  } else if (pendingCode) {
    parts.push(joinPanel());
  }
  const pics = gallery(); if (pics) parts.push(pics);
  const info = infoPanel(); if (info) parts.push(info);
  parts.push(el('p', 'NFC Studio', 'legal'));
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
    render();
  } catch (e) {
    console.error(e);
    status(t('network'), '');
  }
}
start();
