import qrcode from '/qrcode.mjs';
import {t, lang, applyLang, langSwitcher, ago} from '/i18n.mjs';
import {THEMES, applyTheme} from '/themes.mjs';
import {loadConfig, rpc, slugFrom, el, applyColors, toast, storage, industry, safeImage,
  numbersRow, initials, formatDate, unit, dayName, validWeek, SOCIAL_TYPES} from '/loyalty.mjs';

const root = document.getElementById('app');
const langs = document.getElementById('langs');
const slug = slugFrom('s');
const sessionKey = `nfc_shop_${slug}`;
let config = null, data = null, tab = 'home', qr = null, query = '', filter = 'all';
let qrTimer = null, pollTimer = null, tickTimer = null, wakeLock = null, editing = false;
let knownQueue = null, soundOn = storage('nfc_sound') === '1', audio = null;

const session = () => storage(sessionKey);

/* ---------- alerts ---------- */
function beep() {
  if (!soundOn) return;
  try {
    audio ??= new (window.AudioContext || window.webkitAudioContext)();
    const now = audio.currentTime;
    for (const [i, f] of [[0, 880], [0.18, 1175]]) {
      const o = audio.createOscillator(), g = audio.createGain();
      o.frequency.value = f; o.type = 'sine';
      g.gain.setValueAtTime(0.0001, now + i);
      g.gain.exponentialRampToValueAtTime(0.35, now + i + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, now + i + 0.25);
      o.connect(g).connect(audio.destination); o.start(now + i); o.stop(now + i + 0.3);
    }
  } catch { /* audio not available */ }
  try { navigator.vibrate?.([120, 60, 120]); } catch { /* optional */ }
}

function notifyQueue(customers) {
  const queue = customers.filter(c => c.coming || c.arrived);
  const keys = new Set(queue.map(c => `${c.id}:${c.arrived ? 'a' : 'c'}`));
  if (knownQueue) {
    for (const c of queue) {
      const key = `${c.id}:${c.arrived ? 'a' : 'c'}`;
      if (!knownQueue.has(key)) {
        beep();
        toast(c.arrived ? t('arrivedNotif', {name: c.name}) : t('comingNotif', {name: c.name}));
        try {
          if (document.visibilityState !== 'visible' && window.Notification?.permission === 'granted') {
            new Notification(data.shop.name, {body: c.arrived ? t('arrivedNotif', {name: c.name}) : t('comingNotif', {name: c.name})});
          }
        } catch { /* optional */ }
      }
    }
  }
  knownQueue = keys;
}

/* ---------- data ---------- */
async function refresh() {
  const r = await rpc(config, 'nfc_shop_dashboard', {target_slug: slug, session: session()});
  if (!r?.ok) { storage(sessionKey, null); toast(t('sessionExpired'), true); loginView(); return false; }
  data = r;
  applyColors(data.shop);
  if (!editing) applyTheme(r.shop?.theme);
  notifyQueue(data.customers ?? []);
  try {
    const rb = await rpc(config, 'nfc_shop_bookings', {target_slug: slug, session: session()});
    data.bookings = rb?.ok ? rb.bookings ?? [] : [];
  } catch { data.bookings = data.bookings ?? []; }
  notifyBookings(data.bookings);
  if (!editing) render();
  return true;
}

// New appointments: sound + message, like the arrivals queue.
let knownBookings = null;
function notifyBookings(list) {
  const ids = new Set(list.filter(k => k.status === 'booked').map(k => k.id));
  if (knownBookings) {
    for (const k of list) {
      if (k.status === 'booked' && !knownBookings.has(k.id)) {
        beep();
        const msg = t('newBooking', {name: k.customer, service: k.service, day: k.day, time: k.time});
        toast(msg);
        try {
          if (document.visibilityState !== 'visible' && window.Notification?.permission === 'granted') new Notification(data.shop.name, {body: msg});
        } catch { /* optional */ }
      }
    }
  }
  knownBookings = ids;
}

function bookingsPanel() {
  const list = (data.bookings ?? []);
  const panel = el('div', undefined, 'panel');
  panel.append(el('h2', `📅 ${t('appointments')}`));
  const active = list.filter(k => k.status === 'booked');
  if (!active.length) { panel.append(el('p', t('noAppointments'), 'muted small')); return panel; }
  const today = new Date().toISOString().slice(0, 10);
  let lastDay = '';
  for (const k of active) {
    if (k.day !== lastDay) {
      lastDay = k.day;
      let label = k.day;
      try { label = new Intl.DateTimeFormat(lang === 'ar' ? 'ar-MA' : lang, {weekday: 'long', day: 'numeric', month: 'long', timeZone: 'UTC'}).format(new Date(k.day + 'T12:00:00Z')); } catch { /* keep iso */ }
      panel.append(el('h3', (k.day === today ? `${t('todayLabel')} · ` : '') + label, 'appt-day'));
    }
    const row = el('div', undefined, 'appt');
    const info = el('div');
    const who = el('b', `${k.time} · ${k.customer}`);
    const tel = el('a', k.phone, 'small'); tel.href = 'tel:' + String(k.phone).replace(/[^+0-9]/g, ''); tel.dir = 'ltr';
    info.append(who, el('span', `${k.service} · ${k.minutes} ${t('min')}`, 'small muted'), tel);
    const btns = el('div', undefined, 'appt-btns');
    for (const [st, label, cls] of [['done', '✓', 'green'], ['no_show', t('noShowShort'), 'ghost'], ['cancelled', '✕', 'red']]) {
      const b = el('button', label, 'btn small ' + cls); b.type = 'button';
      b.title = t('status_' + st);
      b.addEventListener('click', async () => {
        if (st === 'cancelled' && !confirm(t('ownerCancelConfirm', {name: k.customer, time: k.time}))) return;
        b.disabled = true;
        try {
          const r = await rpc(config, 'nfc_shop_booking_set', {target_slug: slug, session: session(), booking: k.id, new_status: st});
          if (r?.ok) { toast(t('saved')); await refresh(); } else toast(t('saveError'), true);
        } catch { toast(t('network'), true); } finally { b.disabled = false; }
      });
      btns.append(b);
    }
    row.append(info, btns);
    panel.append(row);
  }
  return panel;
}

async function refreshQr() {
  clearTimeout(qrTimer);
  try {
    const r = await rpc(config, 'nfc_shop_qr', {target_slug: slug, session: session()});
    if (!r?.ok) { if (r?.error !== 'suspended') qrTimer = setTimeout(refreshQr, 10000); return; }
    qr = {code: r.code, until: Date.now() + r.expires_in * 1000};
    drawQr();
    qrTimer = setTimeout(refreshQr, Math.max(1, r.expires_in) * 1000 + 300);
  } catch {
    qrTimer = setTimeout(refreshQr, 5000);
  }
}

function startTimers() {
  stopTimers();
  refreshQr();
  pollTimer = setInterval(() => { if (document.visibilityState === 'visible') refresh().catch(() => {}); }, 8000);
  tickTimer = setInterval(updateRing, 500);
}
function stopTimers() { clearTimeout(qrTimer); clearInterval(pollTimer); clearInterval(tickTimer); }

/* ---------- QR ---------- */
function qrSvg(text) {
  const q = qrcode(0, 'M');
  q.addData(text);
  q.make();
  const n = q.getModuleCount();
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('viewBox', `0 0 ${n} ${n}`);
  svg.setAttribute('shape-rendering', 'crispEdges');
  let d = '';
  for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (q.isDark(r, c)) d += `M${c} ${r}h1v1h-1z`;
  const path = document.createElementNS(ns, 'path');
  path.setAttribute('d', d); path.setAttribute('fill', '#0b1020');
  svg.append(path);
  return svg;
}
function drawQr() {
  for (const frame of document.querySelectorAll('[data-qr]')) {
    const ring = frame.querySelector('.ring');
    frame.replaceChildren(ring ?? el('div', undefined, 'ring'));
    if (qr) frame.append(qrSvg(`${location.origin}/c/${slug}?t=${qr.code}`));
  }
  updateRing();
}
function updateRing() {
  if (!qr) return;
  const left = Math.max(0, (qr.until - Date.now()) / 1000);
  for (const ring of document.querySelectorAll('.ring')) ring.style.setProperty('--p', `${(left / 5) * 100}%`);
  for (const c of document.querySelectorAll('[data-countdown]')) c.textContent = t('refreshIn', {s: Math.ceil(left)});
}

/* ---------- views ---------- */
function loginView() {
  stopTimers();
  const wrap = el('div', undefined, 'panel');
  const pass = el('input'); pass.type = 'password'; pass.className = 'field'; pass.placeholder = t('password'); pass.autocomplete = 'current-password';
  const btn = el('button', t('login'), 'btn'); btn.type = 'button';
  const forgot = el('button', t('forgot'), 'btn ghost'); forgot.type = 'button';
  const go = async () => {
    btn.disabled = true;
    try {
      const r = await rpc(config, 'nfc_shop_login', {target_slug: slug, password: pass.value});
      if (!r?.ok) { toast(r?.error === 'locked' ? t('locked') : r?.left ? t('triesLeft', {n: r.left}) : t('wrongPass'), true); return; }
      storage(sessionKey, r.session);
      if (await refresh()) startTimers();
    } catch {
      toast(t('network'), true);
    } finally {
      btn.disabled = false;
    }
  };
  btn.addEventListener('click', go);
  pass.addEventListener('keydown', e => { if (e.key === 'Enter') go(); });
  forgot.addEventListener('click', async () => {
    try { await rpc(config, 'nfc_shop_forgot', {target_slug: slug}); } catch { /* same message */ }
    toast(t('forgotSent'));
  });
  const head = el('div', undefined, 'topbar');
  const brand = el('div', undefined, 'brand');
  brand.append(el('div', '🔐', 'logo'), el('h1', t('shopLogin')));
  head.append(brand, langs);
  wrap.append(pass, btn, forgot);
  root.replaceChildren(head, wrap);
  setTimeout(() => pass.focus(), 60);
}

function header() {
  const bar = el('div', undefined, 'topbar');
  const brand = el('div', undefined, 'brand');
  brand.append(el('div', industry(data.shop).icon, 'logo'));
  const txt = el('div');
  txt.append(el('h1', data.shop.name));
  const sub = el('div', undefined, 'sub');
  if (data.shop.closed) sub.append(el('span', `● ${t('closedUntil', {d: formatDate(data.shop.closed_until, lang)})}`, 'chip red'));
  else { const c = el('span', undefined, 'chip green'); c.append(el('i', undefined, 'dot live'), document.createTextNode(t('openBadge'))); sub.append(c); }
  txt.append(sub);
  brand.append(txt);
  bar.append(brand, langs);
  return bar;
}

function statsRow() {
  const s = data.stats ?? {};
  const row = el('div', undefined, 'stats');
  for (const [ico, v, label] of [['👥', s.customers, t('customers')], ['✂️', s.visits_today, t('today')],
    ['📈', s.visits_week, t('week')], ['🎁', s.rewards, t('gifts')]]) {
    const box = el('div', undefined, 'stat');
    box.append(el('span', ico === '✂️' ? industry(data.shop).icon : ico, 'ico'), el('b', String(v ?? 0)), el('span', label));
    row.append(box);
  }
  return row;
}

function tabsBar() {
  const queue = (data.customers ?? []).filter(c => c.coming || c.arrived).length;
  const bar = el('div', undefined, 'tabs');
  for (const [key, label] of [['home', t('home')], ['customers', t('tabCustomers')], ['settings', t('tabSettings')]]) {
    const b = el('button', label, 'tab' + (tab === key ? ' active' : ''));
    b.type = 'button';
    if (key === 'home' && queue) b.append(el('span', String(queue), 'badge'));
    b.addEventListener('click', () => { tab = key; editing = false; render(); });
    bar.append(b);
  }
  return bar;
}

function queueRow(c) {
  const row = el('div', undefined, 'queue-item ' + (c.arrived ? 'arrived' : 'coming'));
  row.append(el('div', initials(c.name), 'avatar'));
  const who = el('div', undefined, 'who');
  who.append(el('b', c.name));
  who.append(el('span', `${c.arrived ? '📍 ' + t('arrivedBadge') : '🚶 ' + t('comingBadge')} · ${ago(c.arrived ? c.arrived_at : c.coming_at)} · ${c.stamps}/${c.goal}`, 'muted small'));
  row.append(who);
  if (c.next_free) row.append(el('span', '🎁', 'chip green'));
  const done = el('button', t('done'), 'btn small ghost'); done.type = 'button';
  done.addEventListener('click', async () => {
    done.disabled = true;
    try { await rpc(config, 'nfc_shop_clear_queue', {target_slug: slug, session: session(), customer: c.id}); await refresh(); }
    catch { toast(t('network'), true); }
  });
  row.append(done);
  return row;
}

function homeView() {
  const grid = el('div', undefined, 'home-grid');
  // QR
  const qrPanel = el('div', undefined, 'panel qr-card');
  qrPanel.append(el('h2', `📲 ${t('scanMe')}`));
  const frame = el('div', undefined, 'qr-frame'); frame.dataset.qr = '1'; frame.append(el('div', undefined, 'ring'));
  qrPanel.append(frame);
  const cd = el('p', '', 'muted small'); cd.dataset.countdown = '1';
  qrPanel.append(cd);
  const full = el('button', `⛶ ${t('fullscreen')}`, 'btn'); full.type = 'button';
  full.addEventListener('click', fullscreenQr);
  qrPanel.append(full);
  // Queue
  const qPanel = el('div', undefined, 'panel');
  const head = el('h2', `🟢 ${t('queue')}`);
  qPanel.append(head);
  const sound = el('button', soundOn ? t('alertsOn') : t('enableAlerts'), 'btn small ghost' + (soundOn ? ' sound-on' : ''));
  sound.type = 'button';
  sound.addEventListener('click', async () => {
    soundOn = !soundOn; storage('nfc_sound', soundOn ? '1' : '0');
    if (soundOn) { beep(); try { await window.Notification?.requestPermission?.(); } catch { /* optional */ } }
    render();
  });
  qPanel.append(sound);
  const queue = (data.customers ?? []).filter(c => c.coming || c.arrived);
  if (!queue.length) qPanel.append(el('p', t('queueEmpty'), 'empty'));
  for (const c of queue) qPanel.append(queueRow(c));
  grid.append(qrPanel, qPanel);
  return [grid, bookingsPanel(), closedPanel()];
}

function closedPanel() {
  const p = el('div', undefined, 'panel closed-box');
  p.append(el('h2', `🚪 ${t('closedTitle')}`));
  if (data.shop.closed) {
    const b = el('div', undefined, 'banner red');
    b.append(el('span', '🚫', 'ico'), el('p', `${t('closedActive', {d: formatDate(data.shop.closed_until, lang)})}\n${data.shop.closed_message || t('closedDefault')}`));
    const reopen = el('button', t('reopen'), 'btn green'); reopen.type = 'button';
    reopen.addEventListener('click', () => setClosed(null, ''));
    p.append(b, reopen);
    return p;
  }
  const msg = el('textarea'); msg.className = 'field'; msg.placeholder = t('closedDefault'); msg.maxLength = 300;
  const label = el('label', undefined, 'row'); label.append(el('span', t('closedMsgLabel')), msg);
  const today = new Date(), tomorrow = new Date(Date.now() + 86400000);
  const iso = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  const row = el('div', undefined, 'btn-row');
  const b1 = el('button', t('closedToday'), 'btn red'); b1.type = 'button'; b1.addEventListener('click', () => setClosed(iso(today), msg.value));
  const b2 = el('button', t('closedTomorrow'), 'btn amber'); b2.type = 'button'; b2.addEventListener('click', () => setClosed(iso(tomorrow), msg.value));
  const date = el('input'); date.type = 'date'; date.className = 'field'; date.min = iso(today);
  const b3 = el('button', t('closedCustom'), 'btn ghost'); b3.type = 'button';
  b3.addEventListener('click', () => { if (date.value) setClosed(date.value, msg.value); else date.focus(); });
  row.append(b1, b2, b3);
  p.append(label, date, row);
  return p;
}

async function setClosed(until, message) {
  try {
    const r = await rpc(config, 'nfc_shop_set_closed', {target_slug: slug, session: session(), until_date: until, message});
    if (!r?.ok) { applyTheme(s.theme); toast(r?.error === 'email' ? t('badEmail') : r?.error === 'socials' ? t('badLink') : t('saveError'), true); return; }
    toast(t('saved'));
    await refresh();
  } catch { toast(t('network'), true); }
}

function fullscreenQr() {
  const box = el('div', undefined, 'full');
  const inner = el('div');
  inner.append(el('div', industry(data.shop).icon, 'logo'), el('h1', data.shop.name), el('p', t('scanMe'), 'muted'));
  inner.firstChild.style.margin = '0 auto 10px';
  const frame = el('div', undefined, 'qr-frame'); frame.dataset.qr = '1'; frame.append(el('div', undefined, 'ring'));
  const cd = el('p', '', 'muted'); cd.dataset.countdown = '1';
  const close = el('button', '✕', 'btn small ghost'); close.type = 'button';
  close.addEventListener('click', async () => { box.remove(); try { await document.exitFullscreen?.(); } catch { /* */ } });
  inner.append(frame, cd, close);
  box.append(inner);
  document.body.append(box);
  drawQr();
  document.documentElement.requestFullscreen?.().catch(() => {});
  navigator.wakeLock?.request('screen').then(l => { wakeLock = l; }).catch(() => {});
}

function customerCard(c) {
  const card = el('div', undefined, 'cust' + (c.next_free ? ' free' : ''));
  const top = el('div', undefined, 'cust-top');
  top.append(el('div', initials(c.name), 'avatar'));
  const who = el('div', undefined, 'who');
  const nameLine = el('div'); nameLine.append(el('b', c.name));
  if (c.arrived) nameLine.append(document.createTextNode(' '), el('span', `📍 ${t('arrivedBadge')}`, 'chip amber'));
  else if (c.coming) nameLine.append(document.createTextNode(' '), el('span', `🚶 ${t('comingBadge')}`, 'chip green'));
  const phone = el('a', c.phone); phone.href = 'tel:' + c.phone;
  who.append(nameLine, phone);
  const score = el('div', undefined, 'score');
  score.append(el('b', `${c.stamps}/${c.goal}`), el('span', unit(data.shop)));
  top.append(who, score);
  card.append(top, numbersRow(c.goal, c.stamps, c.next_free));
  const meta = el('div', undefined, 'cust-meta');
  meta.append(el('span', `${t('lastVisit')}: ${ago(c.last_visit_at)}`), el('span', `${t('totalVisits')}: ${c.total_visits} · 🎁 ${c.rewards}`));
  if (c.next_free) meta.append(el('span', `${t('giftReady')} · ${c.reward ?? data.shop.reward}`, 'chip green'));
  if (c.old_rule) meta.append(el('span', t('oldRule', {n: c.goal}), 'chip gold'));
  card.append(meta);
  return card;
}

function customersView() {
  const panel = el('div', undefined, 'panel');
  const bar = el('div', undefined, 'toolbar');
  const search = el('input'); search.className = 'field'; search.placeholder = t('search'); search.value = query;
  bar.append(search);
  const filters = el('div', undefined, 'toolbar');
  const list = el('div');
  const match = c => {
    const q = query.trim().toLowerCase();
    if (q && !c.name.toLowerCase().includes(q) && !c.phone.includes(q.replace(/[^0-9+]/g, '') || '§')) return false;
    if (filter === 'ready') return c.next_free;
    if (filter === 'near') return !c.next_free && c.goal - c.stamps <= 2;
    if (filter === 'queue') return c.coming || c.arrived;
    return true;
  };
  const draw = () => {
    const items = (data.customers ?? []).filter(match);
    list.replaceChildren(...(items.length ? items.map(customerCard) : [el('p', t('noCustomers'), 'empty')]));
  };
  for (const [key, label] of [['all', t('filterAll')], ['ready', t('filterReady')], ['near', t('filterNear')], ['queue', t('filterQueue')]]) {
    const b = el('button', label, 'filter' + (filter === key ? ' active' : '')); b.type = 'button';
    b.addEventListener('click', () => { filter = key; for (const x of filters.children) x.classList.toggle('active', x === b); draw(); });
    filters.append(b);
  }
  search.addEventListener('input', () => { query = search.value; draw(); });
  search.addEventListener('focus', () => { editing = true; });
  search.addEventListener('blur', () => { editing = false; });
  draw();
  panel.append(bar, filters, list);

  const visits = el('div', undefined, 'panel');
  visits.append(el('h2', `🕘 ${t('recent')}`));
  for (const v of data.visits ?? []) {
    const row = el('div', undefined, 'visit' + (v.voided ? ' voided' : ''));
    const left = el('div'); left.append(el('span', `${v.free ? '🎁 ' : ''}${v.customer}`, 'name'), el('div', ago(v.created_at), 'muted small'));
    row.append(left);
    if (!v.voided) {
      const b = el('button', t('void'), 'btn small ghost'); b.type = 'button';
      b.addEventListener('click', async () => {
        if (!confirm(t('voidConfirm'))) return;
        await rpc(config, 'nfc_shop_void_visit', {target_slug: slug, session: session(), visit_id: v.id});
        await refresh();
      });
      row.append(b);
    } else row.append(el('span', t('voided'), 'chip'));
    visits.append(row);
  }
  if (!(data.visits ?? []).length) visits.append(el('p', '—', 'empty'));
  return [panel, visits];
}

async function upload(file) {
  const form = new FormData(); form.append('slug', slug); form.append('session', session()); form.append('file', file);
  const res = await fetch(`${config.supabaseUrl}/functions/v1/shop-upload`, {method: 'POST', headers: {apikey: config.publishableKey}, body: form});
  const body = await res.json().catch(() => ({}));
  if (!res.ok || !body.url) throw new Error(body.error);
  return body.url;
}

function settingsView() {
  editing = true;
  const s = data.shop;
  const field = (label, value, type = 'text') => {
    const wrap = el('label', undefined, 'row'); wrap.append(el('span', label));
    const input = el(type === 'textarea' ? 'textarea' : 'input'); input.className = 'field'; input.value = value ?? '';
    if (type !== 'textarea') input.type = type;
    wrap.append(input); return {wrap, input};
  };
  // Shop info
  const info = el('div', undefined, 'panel');
  info.append(el('h2', `🏪 ${t('shopInfo')}`));
  const name = field(t('shopName'), s.name), phone = field(t('phone'), s.phone, 'tel'), address = field(t('address'), s.address);
  const email = field(t('emailLabel'), s.email, 'email');
  // Logo and cover picture of the public page.
  let logoUrl = s.logo_url ?? '', coverUrl = s.cover_url ?? '';
  const imagePicker = (label, get, set, round) => {
    const wrap = el('div', undefined, 'pick');
    const thumb = el('div', undefined, 'pick-thumb' + (round ? ' round' : ''));
    const draw = () => { const u = safeImage(get(), config); thumb.style.backgroundImage = u ? `url("${u}")` : ''; thumb.textContent = u ? '' : '＋'; };
    const file = el('input'); file.type = 'file'; file.accept = 'image/jpeg,image/png,image/webp'; file.hidden = true;
    const btns = el('div', undefined, 'pick-btns');
    const pick = el('button', label, 'btn ghost small'); pick.type = 'button';
    const clear = el('button', '✕', 'btn ghost small'); clear.type = 'button';
    pick.addEventListener('click', () => file.click()); thumb.addEventListener('click', () => file.click());
    clear.addEventListener('click', () => { set(''); draw(); });
    file.addEventListener('change', async () => {
      const f = file.files?.[0]; if (!f) return;
      pick.disabled = true;
      try { set(await upload(f)); draw(); } catch { toast(t('uploadError'), true); } finally { pick.disabled = false; }
    });
    btns.append(pick, clear);
    wrap.append(thumb, btns, file); draw();
    return wrap;
  };
  const pics = el('div', undefined, 'pick-row');
  pics.append(imagePicker(t('logo'), () => logoUrl, v => { logoUrl = v; }, true), imagePicker(t('cover'), () => coverUrl, v => { coverUrl = v; }, false));
  const tagline = field(t('tagline'), s.tagline);
  tagline.input.maxLength = 80;
  info.append(pics, name.wrap, tagline.wrap, phone.wrap, email.wrap, address.wrap);
  // Theme: ten looks for the public page; the dashboard previews it live.
  let theme = THEMES[s.theme] ? s.theme : 'navy';
  const themePanel = el('div', undefined, 'panel');
  themePanel.append(el('h2', `🎨 ${t('themeTitle')}`), el('p', t('themeNote'), 'muted small'));
  const themeGrid = el('div', undefined, 'themes');
  const drawThemes = () => {
    themeGrid.replaceChildren();
    for (const [key, th] of Object.entries(THEMES)) {
      const b = el('button', undefined, 'theme-opt' + (key === theme ? ' on' : '')); b.type = 'button';
      const sw = el('div', undefined, 'theme-sw');
      sw.style.background = `linear-gradient(160deg, ${th.card2}, ${th.bg})`;
      for (const c of [th.gold, th.text, th.line]) { const i = el('i'); i.style.background = c; sw.append(i); }
      b.append(sw, el('span', th.name[lang] ?? th.name.en));
      b.addEventListener('click', () => { theme = key; applyTheme(key); drawThemes(); });
      themeGrid.append(b);
    }
  };
  drawThemes();
  const view = el('a', `👁 ${t('preview')}`, 'btn ghost small'); view.href = `/c/${slug}`; view.target = '_blank';
  themePanel.append(themeGrid, view);
  // Social links (Instagram, WhatsApp, TikTok…)
  const socials = (Array.isArray(s.socials) ? s.socials : []).map(x => ({...x}));
  const linksPanel = el('div', undefined, 'panel');
  linksPanel.append(el('h2', `🔗 ${t('linksTitle')}`), el('p', t('linksNote'), 'muted small'));
  const linkRows = el('div');
  const drawLinks = () => {
    linkRows.replaceChildren();
    socials.forEach((item, i) => {
      const row = el('div', undefined, 'link-edit');
      const type = el('select'); type.className = 'field';
      for (const k of SOCIAL_TYPES) { const o = el('option', t('social_' + k)); o.value = k; o.selected = k === item.type; type.append(o); }
      type.addEventListener('change', () => { item.type = type.value; });
      const value = el('input'); value.className = 'field'; value.value = item.value ?? ''; value.dir = 'ltr';
      value.placeholder = '@name / https://… / 06…';
      value.addEventListener('input', () => { item.value = value.value; });
      const rm = el('button', '✕', 'btn ghost small'); rm.type = 'button';
      rm.addEventListener('click', () => { socials.splice(i, 1); drawLinks(); });
      row.append(type, value, rm);
      linkRows.append(row);
    });
  };
  drawLinks();
  const addLink = el('button', `＋ ${t('addLink')}`, 'btn ghost small'); addLink.type = 'button';
  addLink.addEventListener('click', () => { if (socials.length < 12) { socials.push({type: 'instagram', value: ''}); drawLinks(); } });
  linksPanel.append(linkRows, addLink);
  // Weekly hours: one row per day, Monday first.
  const weekPanel = el('div', undefined, 'panel');
  weekPanel.append(el('h2', `🕒 ${t('hours')}`), el('p', t('weekNote'), 'muted small'));
  const week = validWeek(s.week_hours) ? s.week_hours.map(d => d ? {...d} : null) : Array.from({length: 7}, () => ({o: '09:00', c: '21:00'}));
  const weekRows = [];
  const timeInput = v => { const i = el('input'); i.type = 'time'; i.className = 'field time'; i.value = v; return i; };
  week.forEach((d, i) => {
    const row = el('div', undefined, 'week-day');
    const top = el('div', undefined, 'week-edit');
    const toggle = el('input'); toggle.type = 'checkbox'; toggle.checked = !!d;
    const lbl = el('label', undefined, 'day'); lbl.append(toggle, el('span', dayName(i, lang)));
    const o = timeInput(d?.o ?? '09:00'), c = timeInput(d?.c ?? (d?.o2 ? '13:00' : '21:00'));
    const off = el('span', t('dayOff'), 'off');
    top.append(lbl, o, c, off);
    // Second period after the lunch break.
    const second = el('div', undefined, 'week-edit second');
    const o2 = timeInput(d?.o2 ?? '15:00'), c2 = timeInput(d?.c2 ?? '21:00');
    second.append(el('span', `☕ ${t('afterLunch')}`, 'small muted'), o2, c2);
    const split = el('label', undefined, 'split'); const splitBox = el('input'); splitBox.type = 'checkbox'; splitBox.checked = !!d?.o2;
    split.append(splitBox, el('span', t('lunchBreak')));
    const sync = () => {
      o.hidden = c.hidden = split.hidden = !toggle.checked; off.hidden = toggle.checked;
      second.hidden = !(toggle.checked && splitBox.checked);
    };
    toggle.addEventListener('change', sync); splitBox.addEventListener('change', sync); sync();
    row.append(top, split, second);
    weekRows.push({toggle, o, c, splitBox, o2, c2});
    weekPanel.append(row);
  });
  const copy = el('button', t('copyMonday'), 'btn ghost small'); copy.type = 'button';
  copy.addEventListener('click', () => {
    const m = weekRows[0];
    for (const r of weekRows.slice(1)) {
      r.toggle.checked = m.toggle.checked; r.o.value = m.o.value; r.c.value = m.c.value;
      r.splitBox.checked = m.splitBox.checked; r.o2.value = m.o2.value; r.c2.value = m.c2.value;
      r.toggle.dispatchEvent(new Event('change'));
    }
  });
  weekPanel.append(copy);
  const weekValue = () => weekRows.map(r => {
    if (!r.toggle.checked || !r.o.value || !r.c.value) return null;
    const d = {o: r.o.value.slice(0, 5), c: r.c.value.slice(0, 5)};
    if (r.splitBox.checked && r.o2.value && r.c2.value && r.o2.value > r.c.value) { d.o2 = r.o2.value.slice(0, 5); d.c2 = r.c2.value.slice(0, 5); }
    return d;
  });
  // Appointments: switch, services, slot length and chairs.
  const bookPanel = el('div', undefined, 'panel');
  bookPanel.append(el('h2', `📅 ${t('bookingTitle')}`), el('p', t('bookingNote'), 'muted small'));
  const bookOn = el('input'); bookOn.type = 'checkbox'; bookOn.checked = !!s.booking_enabled;
  const bookOnLbl = el('label', undefined, 'split big'); bookOnLbl.append(bookOn, el('span', t('bookingOn')));
  const services = (Array.isArray(s.services) ? s.services : []).map(x => ({...x}));
  const svcRows = el('div');
  const newId = () => Math.random().toString(36).slice(2, 8);
  const drawSvcs = () => {
    svcRows.replaceChildren();
    services.forEach((svc, i) => {
      const row = el('div', undefined, 'svc-edit');
      const n = el('input'); n.className = 'field'; n.placeholder = t('serviceName'); n.value = svc.name ?? ''; n.maxLength = 60;
      n.addEventListener('input', () => { svc.name = n.value; });
      const m = el('select'); m.className = 'field';
      for (const v of [10, 15, 20, 30, 45, 60, 90, 120]) { const op = el('option', `${v} ${t('min')}`); op.value = String(v); op.selected = Number(svc.minutes) === v; m.append(op); }
      m.addEventListener('change', () => { svc.minutes = Number(m.value); });
      const pr = el('input'); pr.className = 'field'; pr.placeholder = t('price'); pr.value = svc.price ?? ''; pr.maxLength = 30;
      pr.addEventListener('input', () => { svc.price = pr.value; });
      const rm = el('button', '✕', 'btn ghost small'); rm.type = 'button';
      rm.addEventListener('click', () => { services.splice(i, 1); drawSvcs(); });
      row.append(n, m, pr, rm);
      svcRows.append(row);
    });
  };
  drawSvcs();
  const addSvc = el('button', `＋ ${t('addService')}`, 'btn ghost small'); addSvc.type = 'button';
  addSvc.addEventListener('click', () => { if (services.length < 30) { services.push({id: newId(), name: '', minutes: 30, price: ''}); drawSvcs(); } });
  const step = el('select'); step.className = 'field';
  for (const v of [10, 15, 20, 30, 45, 60]) { const op = el('option', `${t('every')} ${v} ${t('min')}`); op.value = String(v); op.selected = (s.slot_minutes ?? 30) === v; step.append(op); }
  const chairs = field(t('chairs'), s.booking_capacity ?? 1, 'number'); chairs.input.min = 1; chairs.input.max = 20;
  const stepWrap = el('label', undefined, 'fieldwrap'); stepWrap.append(el('span', t('slotStep'), 'small muted'), step);
  bookPanel.append(bookOnLbl, el('h3', t('servicesTitle')), svcRows, addSvc, stepWrap, chairs.wrap);
  const bookingValue = () => ({
    enabled: bookOn.checked,
    services: services.map(x => ({id: x.id || newId(), name: String(x.name ?? '').trim(), minutes: Number(x.minutes) || 30, ...(String(x.price ?? '').trim() ? {price: String(x.price).trim()} : {})})).filter(x => x.name),
    slot_minutes: Number(step.value),
    capacity: Math.min(20, Math.max(1, parseInt(chairs.input.value, 10) || 1)),
  });
  // Loyalty rules
  const rules = el('div', undefined, 'panel');
  rules.append(el('h2', `🎁 ${t('loyaltyRules')}`));
  const goal = field(t('goal'), s.goal, 'number'); goal.input.min = 1; goal.input.max = 50;
  const reward = field(t('reward'), s.reward);
  rules.append(goal.wrap, reward.wrap, el('p', t('goalNote'), 'muted small'));
  // Card design
  let background = s.card_background ?? '';
  const design = el('div', undefined, 'panel');
  design.append(el('h2', `🎨 ${t('cardDesign')}`), el('p', t('cardBg'), 'muted small'));
  const preview = el('div', undefined, 'lcard preview-card');
  const drawPreview = () => {
    preview.replaceChildren();
    const url = safeImage(background, config);
    if (url) { const bg = el('div', undefined, 'bg'); bg.style.backgroundImage = `url("${url}")`; preview.append(bg, el('div', undefined, 'shade')); }
    const head = el('div', undefined, 'head');
    const l = el('div'); l.append(el('div', `${industry(s).icon} ${t('yourCard')}`, 'title'), el('div', s.name, 'holder'));
    const cnt = el('div', undefined, 'count'); cnt.append(document.createTextNode(`2/${s.goal}`), el('small', unit(s)));
    head.append(l, cnt);
    const slots = el('div', undefined, 'slots');
    for (let i = 0; i < Math.min(s.goal, 8); i++) { const x = el('div', i < 2 ? '✓' : String(i + 1), 'slot' + (i < 2 ? ' on' : '')); x.dataset.n = String(i + 1); slots.append(x); }
    slots.append(el('div', '🎁', 'slot gift'));
    preview.append(head, slots);
  };
  drawPreview();
  const bgFile = el('input'); bgFile.type = 'file'; bgFile.accept = 'image/jpeg,image/png,image/webp'; bgFile.hidden = true;
  const bgRow = el('div', undefined, 'btn-row');
  const pickBg = el('button', t('changeBg'), 'btn ghost'); pickBg.type = 'button'; pickBg.addEventListener('click', () => bgFile.click());
  const clearBg = el('button', t('removeBg'), 'btn ghost'); clearBg.type = 'button'; clearBg.addEventListener('click', () => { background = ''; drawPreview(); });
  bgFile.addEventListener('change', async () => {
    const f = bgFile.files?.[0]; if (!f) return;
    pickBg.disabled = true;
    try { background = await upload(f); drawPreview(); } catch { toast(t('uploadError'), true); } finally { pickBg.disabled = false; }
  });
  bgRow.append(pickBg, clearBg);
  design.append(preview, bgRow, bgFile);
  // Promo pictures
  const banners = [...(s.banners ?? [])];
  const promo = el('div', undefined, 'panel');
  promo.append(el('h2', `📸 ${t('gallery')}`), el('p', t('galleryNote'), 'muted small'));
  const thumbs = el('div', undefined, 'thumbs');
  const drawThumbs = () => {
    thumbs.replaceChildren();
    banners.forEach((url, i) => {
      const box = el('div', undefined, 'thumb');
      const img = el('img'); img.src = safeImage(url, config) ?? ''; img.referrerPolicy = 'no-referrer';
      const rm = el('button', '✕'); rm.type = 'button'; rm.addEventListener('click', () => { banners.splice(i, 1); drawThumbs(); });
      box.append(img, rm); thumbs.append(box);
    });
    if (banners.length < 6) {
      const add = el('button', t('addImage'), 'btn small ghost'); add.type = 'button';
      const file = el('input'); file.type = 'file'; file.accept = 'image/jpeg,image/png,image/webp'; file.hidden = true;
      add.addEventListener('click', () => file.click());
      file.addEventListener('change', async () => {
        const f = file.files?.[0]; if (!f) return;
        add.disabled = true;
        try { banners.push(await upload(f)); drawThumbs(); } catch { toast(t('uploadError'), true); } finally { add.disabled = false; }
      });
      thumbs.append(add, file);
    }
  };
  drawThumbs();
  promo.append(thumbs);
  // Location
  let geo = s.latitude != null ? {lat: s.latitude, lng: s.longitude} : null;
  const loc = el('div', undefined, 'panel');
  loc.append(el('h2', t('location')));
  const geoInfo = el('p', '', 'muted small');
  const drawGeo = () => { geoInfo.textContent = geo ? `📍 ${geo.lat.toFixed(5)}, ${geo.lng.toFixed(5)}` : t('noLocation'); };
  drawGeo();
  const locate = el('button', t('useLocation'), 'btn ghost'); locate.type = 'button';
  locate.addEventListener('click', () => {
    if (!navigator.geolocation) { toast(t('noGeo'), true); return; }
    locate.disabled = true;
    navigator.geolocation.getCurrentPosition(p => {
      geo = {lat: p.coords.latitude, lng: p.coords.longitude}; drawGeo(); locate.disabled = false; toast(t('locationSet'));
    }, () => { toast(t('noGeo'), true); locate.disabled = false; }, {enableHighAccuracy: true, timeout: 15000});
  });
  const radius = field(t('radius'), s.radius_m ?? 200, 'number'); radius.input.min = 50; radius.input.max = 1000; radius.input.step = 50;
  loc.append(geoInfo, locate, radius.wrap, el('p', t('radiusNote'), 'muted small'));
  // Save
  const save = el('button', `💾 ${t('save')}`, 'btn'); save.type = 'button';
  save.addEventListener('click', async () => {
    save.disabled = true;
    try {
      const r = await rpc(config, 'nfc_shop_update', {target_slug: slug, session: session(), settings: {
        name: name.input.value, phone: phone.input.value, address: address.input.value, week_hours: weekValue(),
        goal: String(Math.min(50, Math.max(1, parseInt(goal.input.value, 10) || 5))), reward: reward.input.value,
        banners, card_background: background, logo_url: logoUrl, cover_url: coverUrl, email: email.input.value, theme, tagline: tagline.input.value,
        socials: socials.map(x => ({type: x.type, value: String(x.value ?? '').trim()})).filter(x => x.value),
        radius_m: String(Math.min(1000, Math.max(50, parseInt(radius.input.value, 10) || 200))),
        ...(geo ? {latitude: String(geo.lat), longitude: String(geo.lng)} : {}),
      }});
      if (!r?.ok) { applyTheme(s.theme); toast(r?.error === 'email' ? t('badEmail') : r?.error === 'socials' ? t('badLink') : r?.error === 'hours' ? t('badHours') : t('saveError'), true); return; }
      const bv = bookingValue();
      const rb = await rpc(config, 'nfc_shop_booking_settings', {target_slug: slug, session: session(), settings: bv});
      if (!rb?.ok) { toast(rb?.error === 'services' ? t('badServices') : t('saveError'), true); return; }
      if (bv.enabled && !bv.services.length) toast(t('needServices'), true);
      else toast(t('saved'));
      editing = false;
      await refresh();
    } catch { toast(t('saveError'), true); } finally { save.disabled = false; }
  });
  // Security
  const sec = el('div', undefined, 'panel');
  sec.append(el('h2', `🔐 ${t('security')}`));
  const oldP = field(t('oldPass'), '', 'password'), newP = field(t('newPass'), '', 'password');
  const change = el('button', t('changePass'), 'btn ghost'); change.type = 'button';
  change.addEventListener('click', async () => {
    change.disabled = true;
    try {
      const r = await rpc(config, 'nfc_shop_change_password', {target_slug: slug, session: session(), old_password: oldP.input.value, new_password: newP.input.value});
      if (r?.ok) { toast(t('passChanged')); oldP.input.value = ''; newP.input.value = ''; }
      else toast(r?.error === 'old' ? t('wrongOld') : r?.error === 'weak' ? t('weakPass') : t('saveError'), true);
    } catch { toast(t('network'), true); } finally { change.disabled = false; }
  });
  const out = el('button', t('logout'), 'btn red'); out.type = 'button';
  out.addEventListener('click', async () => {
    try { await rpc(config, 'nfc_shop_logout', {target_slug: slug, session: session()}); } catch { /* ignore */ }
    storage(sessionKey, null); loginView();
  });
  sec.append(oldP.wrap, newP.wrap, change, out);
  return [themePanel, info, linksPanel, weekPanel, bookPanel, promo, rules, loc, save, sec];
}

function suspendedView() {
  stopTimers();
  const b = el('div', undefined, 'banner red');
  const body = el('div'); body.append(el('strong', t('suspendedTitle')), el('p', data.notice || t('suspendedText')));
  b.append(el('span', '⛔', 'ico'), body);
  const out = el('button', t('logout'), 'btn ghost'); out.type = 'button';
  out.addEventListener('click', () => { storage(sessionKey, null); loginView(); });
  root.replaceChildren(header(), b, out);
}

function render() {
  if (!data) return;
  document.title = data.shop.name;
  if (data.suspended) { suspendedView(); return; }
  const parts = [header()];
  if (data.notice) {
    const b = el('div', undefined, 'banner amber');
    const body = el('div'); body.append(el('strong', t('noticeTitle')), el('p', data.notice));
    b.append(el('span', '⚠️', 'ico'), body);
    parts.push(b);
  }
  parts.push(statsRow(), tabsBar());
  editing = false;
  if (tab === 'home') parts.push(...homeView());
  else if (tab === 'customers') parts.push(...customersView());
  else parts.push(...settingsView());
  root.replaceChildren(...parts);
  if (tab === 'home') drawQr();
}

async function start() {
  applyLang();
  langSwitcher(langs, () => { editing = false; render(); });
  if (!slug) { root.replaceChildren(el('h1', t('unavailable'))); return; }
  try {
    config = await loadConfig();
    if (!session()) { loginView(); return; }
    if (await refresh()) startTimers();
  } catch {
    root.replaceChildren(el('div', t('network'), 'panel'));
  }
}
document.addEventListener('visibilitychange', async () => {
  if (document.visibilityState === 'visible' && wakeLock?.released) {
    try { wakeLock = await navigator.wakeLock?.request('screen'); } catch { /* optional */ }
  }
});
start();
