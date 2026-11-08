import {t, applyLang, langSwitcher} from '/i18n.mjs';
import {loadConfig, rpc, slugFrom, el, applyColors, toast, storage, stampRow, bannerStrip, industry, unit} from '/loyalty.mjs';

const root = document.getElementById('app');
const langs = document.getElementById('langs');
const slug = slugFrom('c');
const tokenKey = `nfc_card_${slug}`;
// The rotating code arrives as ?t=…; it is used once and removed from the URL.
let pendingCode = new URLSearchParams(location.search).get('t');
if (pendingCode && !/^[0-9a-f]{8}$/i.test(pendingCode)) pendingCode = null;
if (pendingCode) history.replaceState(null, '', location.pathname);

let config = null, shop = null, customer = null, notice = null;
let installEvent = null;
window.addEventListener('beforeinstallprompt', e => { e.preventDefault(); installEvent = e; });

function status(title, text) {
  root.replaceChildren(el('h1', title), el('p', text));
}

function header() {
  const head = el('div', undefined, 'shop-head');
  head.append(el('div', industry(shop).icon, 'avatar'), el('div', undefined, 'shop-meta'));
  head.lastChild.append(el('h1', shop.name));
  if (shop.address) head.lastChild.append(el('p', shop.address, 'muted small'));
  if (shop.hours) head.lastChild.append(el('p', '🕒 ' + shop.hours, 'muted small'));
  return head;
}

function render() {
  if (!shop) return;
  document.title = shop.name;
  const parts = [header()];
  if (notice) parts.push(el('div', notice.text, 'notice-box ' + (notice.good ? 'good' : 'bad')));
  if (!customer) parts.push(...joinForm());
  else parts.push(...cardView());
  const strip = bannerStrip(shop, config);
  if (strip) parts.push(el('h2', t('gallery'), 'section'), strip);
  if (shop.phone && /^[+0-9 ()-]{3,40}$/.test(shop.phone)) {
    const a = el('a', `📞 ${t('call')}`, 'button secondary');
    a.href = 'tel:' + shop.phone.replace(/[^+0-9]/g, '');
    parts.push(a);
  }
  root.replaceChildren(...parts);
}

function joinForm() {
  const title = el('h2', t('join'));
  const text = el('p', t('joinText'), 'muted');
  const name = el('input'); name.className = 'field'; name.placeholder = t('name'); name.autocomplete = 'name'; name.maxLength = 80;
  const phone = el('input'); phone.className = 'field'; phone.placeholder = t('phone'); phone.type = 'tel'; phone.autocomplete = 'tel'; phone.inputMode = 'tel'; phone.dir = 'ltr';
  const btn = el('button', t('joinBtn'), 'button'); btn.type = 'button';
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
      notice = r.visit ? {good: true, text: r.visit.free ? t('stampedFree') : t('stamped')} : null;
      pendingCode = null;
      render();
    } catch {
      toast(t('network'), true);
    } finally {
      btn.disabled = false;
    }
  });
  return [title, text, name, phone, btn];
}

function cardView() {
  const out = [];
  out.push(el('p', `${t('welcome')} ${customer.name} 👋`, 'eyebrow'));
  const card = el('div', undefined, 'loyalty-card' + (customer.next_free ? ' free' : ''));
  const goal = customer.goal ?? shop.goal, reward = customer.reward ?? shop.reward;
  card.append(el('div', `${customer.stamps} / ${goal} ${unit(shop)}`, 'count'));
  card.append(stampRow(shop, customer.stamps, customer.next_free, goal));
  card.append(el('p', customer.next_free ? `${t('freeNext')} ${reward}` : t('goalText', {n: goal, reward}), 'goal-text'));
  out.push(card);
  const stats = el('div', undefined, 'mini-stats');
  stats.append(el('span', `${t('totalVisits')}: ${customer.total_visits}`), el('span', `${t('rewards')}: ${customer.rewards}`));
  out.push(stats);
  out.push(el('p', t('scanHint'), 'muted small'));
  const coming = el('button', customer.coming ? t('comingSent') : t('coming'), 'button' + (customer.coming ? ' success' : ''));
  coming.type = 'button';
  coming.addEventListener('click', async () => {
    coming.disabled = true;
    try {
      const r = await rpc(config, 'nfc_customer_coming', {target_slug: slug, token: storage(tokenKey)});
      if (r?.ok) { customer = r.customer; customer.coming = true; toast(t('comingSent')); render(); }
    } catch {
      toast(t('network'), true);
    } finally {
      coming.disabled = false;
    }
  });
  out.push(coming);
  const home = el('button', t('addHome'), 'button secondary');
  home.type = 'button';
  home.addEventListener('click', addToHome);
  out.push(home);
  return out;
}

async function addToHome() {
  if (installEvent) { installEvent.prompt(); installEvent = null; return; }
  const box = el('div', undefined, 'sheet');
  const panel = el('div', undefined, 'sheet-panel glass');
  const ios = /iphone|ipad|ipod/i.test(navigator.userAgent);
  const ok = el('button', t('ok'), 'button'); ok.type = 'button';
  ok.addEventListener('click', () => box.remove());
  panel.append(el('h2', t('addHome')), el('p', ios ? t('iosHelp') : t('androidHelp')), ok);
  box.append(panel);
  box.addEventListener('click', e => { if (e.target === box) box.remove(); });
  document.body.append(box);
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
          notice = r.ok
            ? {good: true, text: r.free ? t('stampedFree') : t('stamped')}
            : {good: false, text: r.error === 'too_soon' ? t('tooSoon') : t('codeExpired')};
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
