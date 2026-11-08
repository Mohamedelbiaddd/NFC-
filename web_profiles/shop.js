import qrcode from '/qrcode.mjs';
import {t, applyLang, langSwitcher, ago} from '/i18n.mjs';
import {loadConfig, rpc, slugFrom, el, applyColors, toast, storage, stampRow, industry, safeImage} from '/loyalty.mjs';

const root = document.getElementById('app');
const langs = document.getElementById('langs');
const slug = slugFrom('s');
const sessionKey = `nfc_shop_${slug}`;
let config = null, data = null, tab = 'code', qr = null, query = '';
let qrTimer = null, pollTimer = null, tickTimer = null, wakeLock = null;

function session() { return storage(sessionKey); }

function status(title, text) { root.replaceChildren(el('h1', title), el('p', text ?? '')); }

function loginView() {
  stopTimers();
  const pass = el('input'); pass.type = 'password'; pass.className = 'field'; pass.placeholder = t('password'); pass.autocomplete = 'current-password';
  const btn = el('button', t('login'), 'button'); btn.type = 'button';
  const go = async () => {
    btn.disabled = true;
    try {
      const r = await rpc(config, 'nfc_shop_login', {target_slug: slug, password: pass.value});
      if (!r?.ok) { toast(r?.error === 'locked' ? t('locked') : t('wrongPass'), true); return; }
      storage(sessionKey, r.session);
      await refresh();
      startTimers();
    } catch {
      toast(t('network'), true);
    } finally {
      btn.disabled = false;
    }
  };
  btn.addEventListener('click', go);
  pass.addEventListener('keydown', e => { if (e.key === 'Enter') go(); });
  root.replaceChildren(el('div', '🔐', 'avatar'), el('h1', t('shopLogin')), pass, btn);
}

async function refresh() {
  const r = await rpc(config, 'nfc_shop_dashboard', {target_slug: slug, session: session()});
  if (!r?.ok) { storage(sessionKey, null); toast(t('sessionExpired'), true); loginView(); return false; }
  data = r;
  applyColors(data.shop);
  if (tab !== 'settings') render();
  return true;
}

async function refreshQr() {
  clearTimeout(qrTimer);
  try {
    const r = await rpc(config, 'nfc_shop_qr', {target_slug: slug, session: session()});
    if (!r?.ok) return;
    qr = {code: r.code, until: Date.now() + r.expires_in * 1000};
    if (tab === 'code') render();
    qrTimer = setTimeout(refreshQr, Math.max(1, r.expires_in) * 1000 + 300);
  } catch {
    qrTimer = setTimeout(refreshQr, 5000);
  }
}

function startTimers() {
  stopTimers();
  refreshQr();
  pollTimer = setInterval(() => { if (document.visibilityState === 'visible') refresh().catch(() => {}); }, 10000);
  tickTimer = setInterval(() => {
    const c = document.getElementById('countdown');
    if (c && qr) c.textContent = t('refreshIn', {s: Math.max(0, Math.ceil((qr.until - Date.now()) / 1000))});
  }, 1000);
}
function stopTimers() { clearTimeout(qrTimer); clearInterval(pollTimer); clearInterval(tickTimer); }

function qrSvg(text) {
  const q = qrcode(0, 'M');
  q.addData(text);
  q.make();
  const n = q.getModuleCount(), m = 4;
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('viewBox', `0 0 ${n + m * 2} ${n + m * 2}`);
  svg.setAttribute('class', 'qr');
  const bg = document.createElementNS(ns, 'rect');
  bg.setAttribute('width', n + m * 2); bg.setAttribute('height', n + m * 2); bg.setAttribute('fill', '#fff');
  svg.append(bg);
  let d = '';
  for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (q.isDark(r, c)) d += `M${c + m} ${r + m}h1v1h-1z`;
  const path = document.createElementNS(ns, 'path');
  path.setAttribute('d', d); path.setAttribute('fill', '#000');
  svg.append(path);
  return svg;
}

function tabs() {
  const bar = el('div', undefined, 'tabs');
  for (const [key, label] of [['code', t('tabCode')], ['customers', t('tabCustomers')], ['settings', t('tabSettings')]]) {
    const b = el('button', label, 'tab' + (tab === key ? ' active' : ''));
    b.type = 'button';
    b.addEventListener('click', () => { tab = key; render(); });
    bar.append(b);
  }
  return bar;
}

function statsRow() {
  const s = data.stats ?? {};
  const row = el('div', undefined, 'stat-row');
  for (const [v, label] of [[s.customers, t('customers')], [s.visits_today, t('today')], [s.rewards, t('gifts')]]) {
    const box = el('div', undefined, 'stat');
    box.append(el('strong', String(v ?? 0)), el('span', label));
    row.append(box);
  }
  return row;
}

function codeView() {
  const wrap = el('div', undefined, 'qr-wrap');
  wrap.append(el('p', t('scanMe'), 'eyebrow'));
  if (qr) wrap.append(qrSvg(`${location.origin}/c/${slug}?t=${qr.code}`));
  else wrap.append(el('div', undefined, 'spinner'));
  wrap.append(el('p', qr ? t('refreshIn', {s: Math.max(0, Math.ceil((qr.until - Date.now()) / 1000))}) : '', 'muted small'));
  wrap.lastChild.id = 'countdown';
  const full = el('button', '⛶ ' + t('fullscreen'), 'button secondary'); full.type = 'button';
  full.addEventListener('click', async () => {
    try { await document.documentElement.requestFullscreen(); } catch { /* not supported */ }
    try { wakeLock = await navigator.wakeLock?.request('screen'); } catch { /* optional */ }
  });
  wrap.append(full);
  const coming = (data.customers ?? []).filter(c => c.coming);
  const out = [wrap];
  if (coming.length) {
    out.push(el('h2', `🟢 ${t('comingBadge')}`, 'section'));
    for (const c of coming) out.push(customerRow(c));
  }
  return out;
}

function customerRow(c) {
  const row = el('div', undefined, 'cust' + (c.next_free ? ' free' : ''));
  const top = el('div', undefined, 'cust-top');
  const name = el('strong', c.name);
  top.append(name);
  if (c.coming) top.append(el('span', `🟢 ${t('comingBadge')}`, 'badge green'));
  if (c.next_free) top.append(el('span', `🎁 ${t('free')}`, 'badge green'));
  row.append(top);
  const meta = el('div', undefined, 'cust-meta');
  const phone = el('a', c.phone); phone.href = 'tel:' + c.phone; phone.dir = 'ltr';
  meta.append(phone, el('span', `${t('lastVisit')}: ${ago(c.last_visit_at)}`));
  row.append(meta, stampRow(data.shop, c.stamps, c.next_free));
  return row;
}

function customersView() {
  const search = el('input'); search.className = 'field'; search.placeholder = t('search'); search.value = query;
  const list = el('div');
  const draw = () => {
    const q = query.trim().toLowerCase();
    const items = (data.customers ?? []).filter(c => !q || c.name.toLowerCase().includes(q) || c.phone.includes(q.replace(/[^0-9+]/g, '') || '§'));
    list.replaceChildren(...(items.length ? items.map(customerRow) : [el('p', t('noCustomers'), 'muted')]));
  };
  search.addEventListener('input', () => { query = search.value; draw(); });
  draw();
  const visits = el('div');
  for (const v of data.visits ?? []) {
    const row = el('div', undefined, 'visit' + (v.voided ? ' voided' : ''));
    row.append(el('span', `${v.free ? '🎁 ' : ''}${v.customer}`), el('span', ago(v.created_at), 'muted small'));
    if (!v.voided) {
      const b = el('button', t('void'), 'button secondary small danger'); b.type = 'button';
      b.addEventListener('click', async () => {
        if (!confirm(t('voidConfirm'))) return;
        await rpc(config, 'nfc_shop_void_visit', {target_slug: slug, session: session(), visit_id: v.id});
        await refresh();
      });
      row.append(b);
    } else row.append(el('span', t('voided'), 'muted small'));
    visits.append(row);
  }
  return [search, list, el('h2', t('recent'), 'section'), visits];
}

function settingsView() {
  const s = data.shop;
  const field = (label, value, type = 'text') => {
    const wrap = el('label', undefined, 'form-row'); wrap.append(el('span', label));
    const input = el(type === 'textarea' ? 'textarea' : 'input'); input.className = 'field'; input.value = value ?? '';
    if (type !== 'textarea') input.type = type;
    wrap.append(input); return {wrap, input};
  };
  const name = field(t('shopName'), s.name);
  const phone = field(t('phone'), s.phone, 'tel');
  const address = field(t('address'), s.address);
  const hours = field('🕒', s.hours);
  const goal = field(t('goal'), s.goal, 'number'); goal.input.min = 1; goal.input.max = 50;
  const reward = field(t('reward'), s.reward);
  let geo = s.latitude != null ? {lat: s.latitude, lng: s.longitude} : null;
  const geoInfo = el('p', '', 'muted small');
  const drawGeo = () => { geoInfo.textContent = geo ? `📍 ${geo.lat.toFixed(5)}, ${geo.lng.toFixed(5)}` : t('noLocation'); };
  drawGeo();
  const locate = el('button', t('useLocation'), 'button secondary'); locate.type = 'button';
  locate.addEventListener('click', () => {
    if (!navigator.geolocation) { toast(t('noGeo'), true); return; }
    locate.disabled = true;
    navigator.geolocation.getCurrentPosition(p => {
      geo = {lat: p.coords.latitude, lng: p.coords.longitude}; drawGeo(); locate.disabled = false; toast(t('locationSet'));
    }, () => { toast(t('noGeo'), true); locate.disabled = false; }, {enableHighAccuracy: true, timeout: 15000});
  });
  const radius = field(t('radius'), s.radius_m ?? 200, 'number'); radius.input.min = 50; radius.input.max = 1000; radius.input.step = 50;
  const banners = [...(s.banners ?? [])];
  const gallery = el('div', undefined, 'banner-edit');
  const drawGallery = () => {
    gallery.replaceChildren();
    banners.forEach((url, i) => {
      const box = el('div', undefined, 'banner-thumb');
      const img = el('img'); img.src = safeImage(url, config) ?? ''; img.referrerPolicy = 'no-referrer';
      const rm = el('button', '✕', 'remove'); rm.type = 'button'; rm.title = t('remove');
      rm.addEventListener('click', () => { banners.splice(i, 1); drawGallery(); });
      box.append(img, rm); gallery.append(box);
    });
    if (banners.length < 5) {
      const add = el('button', t('addImage'), 'button secondary small'); add.type = 'button';
      const file = el('input'); file.type = 'file'; file.accept = 'image/jpeg,image/png,image/webp'; file.hidden = true;
      add.addEventListener('click', () => file.click());
      file.addEventListener('change', async () => {
        const f = file.files?.[0]; if (!f) return;
        add.disabled = true;
        try {
          const form = new FormData(); form.append('slug', slug); form.append('session', session()); form.append('file', f);
          const res = await fetch(`${config.supabaseUrl}/functions/v1/shop-upload`, {method: 'POST', headers: {apikey: config.publishableKey}, body: form});
          const body = await res.json().catch(() => ({}));
          if (!res.ok || !body.url) throw new Error(body.error);
          banners.push(body.url); drawGallery();
        } catch {
          toast(t('uploadError'), true);
        } finally { add.disabled = false; }
      });
      gallery.append(add, file);
    }
  };
  drawGallery();
  const save = el('button', t('save'), 'button'); save.type = 'button';
  save.addEventListener('click', async () => {
    save.disabled = true;
    try {
      const r = await rpc(config, 'nfc_shop_update', {target_slug: slug, session: session(), settings: {
        name: name.input.value, phone: phone.input.value, address: address.input.value, hours: hours.input.value,
        goal: String(Math.min(50, Math.max(1, parseInt(goal.input.value, 10) || 5))), reward: reward.input.value, banners,
        radius_m: String(Math.min(1000, Math.max(50, parseInt(radius.input.value, 10) || 200))),
        ...(geo ? {latitude: String(geo.lat), longitude: String(geo.lng)} : {}),
      }});
      if (!r?.ok) { toast(t('saveError'), true); return; }
      toast(t('saved'));
      await refresh();
    } catch { toast(t('saveError'), true); } finally { save.disabled = false; }
  });
  const out = el('button', t('logout'), 'button secondary danger'); out.type = 'button';
  out.addEventListener('click', async () => {
    try { await rpc(config, 'nfc_shop_logout', {target_slug: slug, session: session()}); } catch { /* ignore */ }
    storage(sessionKey, null); loginView();
  });
  return [name.wrap, phone.wrap, address.wrap, hours.wrap, goal.wrap, reward.wrap,
    el('h2', t('location'), 'section'), geoInfo, locate, radius.wrap, el('p', t('radiusNote'), 'muted small'),
    el('h2', t('banners'), 'section'), gallery, save, out];
}

function render() {
  if (!data) return;
  document.title = data.shop.name;
  const head = el('div', undefined, 'shop-head');
  head.append(el('div', industry(data.shop).icon, 'avatar'));
  const meta = el('div', undefined, 'shop-meta'); meta.append(el('h1', data.shop.name)); head.append(meta);
  const body = tab === 'code' ? codeView() : tab === 'customers' ? customersView() : settingsView();
  root.replaceChildren(head, statsRow(), tabs(), ...body);
}

async function start() {
  applyLang();
  langSwitcher(langs, () => render());
  if (!slug) { status(t('unavailable'), t('unavailableText')); return; }
  try {
    config = await loadConfig();
    if (!session()) { loginView(); return; }
    if (await refresh()) startTimers();
  } catch {
    status(t('network'));
  }
}
document.addEventListener('visibilitychange', async () => {
  if (document.visibilityState === 'visible' && wakeLock?.released) {
    try { wakeLock = await navigator.wakeLock?.request('screen'); } catch { /* optional */ }
  }
});
start();
