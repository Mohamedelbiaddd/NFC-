import {t, lang, applyLang, langSwitcher} from '/i18n.mjs';
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

// Professional header: cover picture, logo (hidden owner entry), name and status.
function hero() {
  const box = el('header', undefined, 'hero');
  const coverUrl = safeImage(shop.cover_url, config) ?? safeImage(shop.banners?.[0], config) ?? safeImage(shop.card_background, config);
  const cover = el('div', undefined, 'cover' + (coverUrl ? '' : ' plain'));
  if (coverUrl) cover.style.backgroundImage = `url("${coverUrl}")`;
  cover.append(langs);
  const logoUrl = safeImage(shop.logo_url, config);
  const logo = el('div', logoUrl ? undefined : industry(shop).icon, 'hero-logo');
  if (logoUrl) { const img = el('img'); img.src = logoUrl; img.alt = ''; img.referrerPolicy = 'no-referrer'; logo.append(img); }
  // Hidden owner entry: four quick taps on the logo.
  let taps = [];
  logo.addEventListener('click', () => {
    const now = Date.now();
    taps = taps.filter(x => now - x < 1500);
    taps.push(now);
    if (taps.length >= 4) { taps = []; ownerLogin(); }
  });
  const body = el('div', undefined, 'hero-body');
  body.append(el('h1', shop.name));
  const sub = el('div', undefined, 'hero-sub');
  sub.append(el('span', `${industry(shop).icon} ${industryLabel(shop)}`, 'chip'));
  const open = shop.closed ? false : openNow(shop.week_hours);
  if (shop.closed || open === false) sub.append(el('span', `● ${shop.closed ? t('closedBadge') : t('closedNow')}`, 'chip red'));
  else if (open === true) sub.append(el('span', `● ${t('openNow')}`, 'chip green'));
  body.append(sub);
  if (shop.address) body.append(el('p', `📍 ${shop.address}`, 'hero-addr'));
  box.append(cover, logo, body);
  return box;
}

// Round contact buttons: call, WhatsApp, directions, social networks.
function quickLinks() {
  const items = [];
  if (shop.phone) items.push(['phone', shop.phone, t('call')]);
  for (const s of Array.isArray(shop.socials) ? shop.socials : []) items.push([s.type, s.value, t('social_' + s.type)]);
  if (shop.latitude != null) items.push(['maps', `https://www.google.com/maps/search/?api=1&query=${shop.latitude},${shop.longitude}`, t('directions')]);
  if (shop.email) items.push(['email', shop.email, t('emailLabel')]);
  const row = el('nav', undefined, 'quick');
  const seen = new Set();
  for (const [type, value, label] of items) {
    const link = socialLink(type, value);
    if (!link || seen.has(link.href)) continue;
    seen.add(link.href);
    const a = el('a', undefined, 'q');
    a.href = link.href; a.target = '_blank'; a.rel = 'noopener';
    const ico = el('span', link.icon, 'q-ico');
    ico.style.background = link.color;
    a.append(ico, el('span', label, 'q-label'));
    row.append(a);
  }
  return row.childNodes.length ? row : null;
}

// Up to six photos; tap one to see it full screen.
function gallery() {
  const urls = (Array.isArray(shop.banners) ? shop.banners : []).map(u => safeImage(u, config)).filter(Boolean);
  if (!urls.length) return null;
  const panel = el('section', undefined, 'panel');
  panel.append(el('h2', `📸 ${t('gallery')}`));
  const grid = el('div', undefined, 'gallery g' + Math.min(urls.length, 3));
  urls.forEach((url, i) => {
    const img = el('img'); img.src = url; img.loading = 'lazy'; img.alt = ''; img.referrerPolicy = 'no-referrer';
    img.addEventListener('click', () => {
      const box = el('div', undefined, 'lightbox');
      const big = el('img'); big.src = urls[i]; big.alt = '';
      box.append(big);
      box.addEventListener('click', () => box.remove());
      document.body.append(box);
    });
    grid.append(img);
  });
  panel.append(grid);
  return panel;
}

// Visitors without a card see what the programme offers; the join form only
// appears when they scanned the shop's code.
function teaser() {
  const panel = el('section', undefined, 'panel teaser');
  panel.append(el('h2', `🎁 ${t('programTitle')}`));
  panel.append(el('p', t('programText', {n: shop.goal, r: shop.reward}), 'muted'));
  panel.append(slotsGrid(shop.goal, 0, false, -1));
  panel.append(el('p', `📷 ${t('programHow')}`, 'small'));
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
  const parts = [hero()];
  const links = quickLinks(); if (links) parts.push(links);
  const closed = closedBanner(); if (closed) parts.push(closed);
  if (notice) {
    const b = el('div', undefined, `banner ${notice.kind}`);
    b.append(el('span', notice.kind === 'green' ? '🎉' : '⚠️', 'ico'), el('p', notice.text));
    parts.push(b);
  }
  if (customer) {
    parts.push(loyaltyCard(), actions());
    if (canWallet()) parts.push(walletButton());
    const home = el('button', t('addHome'), 'btn ghost'); home.type = 'button';
    home.addEventListener('click', addToHome);
    parts.push(home);
  } else if (pendingCode) {
    parts.push(loyaltyCard(), joinPanel());
  } else {
    parts.push(teaser());
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
  } catch {
    status(t('network'), '');
  }
}
start();
