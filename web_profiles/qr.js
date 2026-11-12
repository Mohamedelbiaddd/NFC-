// tapmaroc.com/qr — free QR code generator for business cards (vCard: scan
// to save the contact) and for links / WhatsApp. Runs fully in the browser:
// nothing typed here leaves the device.
import qrcode from '/qrcode.mjs';

qrcode.stringToBytes = qrcode.stringToBytesFuncs['UTF-8']; // Arabic & accents

const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];

const Q = {
  fr: {eyebrow: 'Gratuit · sans inscription', title: 'Générateur de QR code pour carte de visite', sub: 'Saisissez vos infos : le QR code créé s’ouvre avec l’appareil photo de n’importe quel téléphone et enregistre directement votre nom, numéro et e-mail dans les contacts.',
    tabCard: '👤 Carte de visite', tabLink: '🔗 Lien ou WhatsApp', first: 'Prénom', last: 'Nom', org: 'Entreprise / commerce', job: 'Métier', phone: 'Téléphone', email: 'E-mail', site: 'Site web', addr: 'Adresse',
    url: 'Lien', wa: 'Ou numéro WhatsApp (avec indicatif)', waMsg: 'Message prérempli (facultatif)', style: 'Style', logo: '＋ Votre logo au centre', noLogo: 'Retirer le logo',
    priv: '🔒 Tout est créé sur votre téléphone. Vos infos ne sont envoyées nulle part.', hint: 'Saisissez vos infos pour voir le QR code', ready: '✓ Scannez-le pour tester', png: '⬇️ Télécharger PNG', svg: '⬇️ SVG pour impression',
    upT: 'Envie de plus qu’un QR code ?', upP: 'Une carte digitale complète avec votre photo, vos liens, vos réseaux, un design pro et votre propre lien — gratuitement.', upB: 'La créer gratuitement', home: 'Accueil', free: 'Carte gratuite', privacy: 'Confidentialité',
    docTitle: 'Générateur QR code carte de visite gratuit — TapMaroc'},
  en: {eyebrow: 'Free · no sign-up', title: 'Business card QR code generator', sub: 'Type your details: anyone who scans the QR code with their phone camera saves your name, number and email straight to their contacts.',
    tabCard: '👤 Business card', tabLink: '🔗 Link or WhatsApp', first: 'First name', last: 'Last name', org: 'Company / shop', job: 'Job title', phone: 'Phone', email: 'Email', site: 'Website', addr: 'Address',
    url: 'Link', wa: 'Or WhatsApp number (with country code)', waMsg: 'Pre-filled message (optional)', style: 'Style', logo: '＋ Your logo in the middle', noLogo: 'Remove logo',
    priv: '🔒 Everything is made on your phone. Your details are not sent anywhere.', hint: 'Type your details to see the QR code', ready: '✓ Scan it to test', png: '⬇️ Download PNG', svg: '⬇️ SVG for print',
    upT: 'Want more than a QR code?', upP: 'A full digital card with your photo, links, socials, a pro design and your own link — for free.', upB: 'Create it free', home: 'Home', free: 'Free card', privacy: 'Privacy',
    docTitle: 'Free business card QR code generator — TapMaroc'},
  it: {eyebrow: 'Gratis · senza registrazione', title: 'Generatore di QR code per biglietti da visita', sub: 'Scrivi i tuoi dati: chi scansiona il QR code con la fotocamera salva subito nome, numero ed e-mail nei contatti.',
    tabCard: '👤 Biglietto da visita', tabLink: '🔗 Link o WhatsApp', first: 'Nome', last: 'Cognome', org: 'Azienda / negozio', job: 'Professione', phone: 'Telefono', email: 'E-mail', site: 'Sito web', addr: 'Indirizzo',
    url: 'Link', wa: 'Oppure numero WhatsApp (con prefisso)', waMsg: 'Messaggio precompilato (facoltativo)', style: 'Stile', logo: '＋ Il tuo logo al centro', noLogo: 'Rimuovi logo',
    priv: '🔒 Tutto viene creato sul tuo telefono. I tuoi dati non vengono inviati da nessuna parte.', hint: 'Scrivi i tuoi dati per vedere il QR code', ready: '✓ Scansionalo per provarlo', png: '⬇️ Scarica PNG', svg: '⬇️ SVG per la stampa',
    upT: 'Vuoi più di un QR code?', upP: 'Un biglietto digitale completo con foto, link, social, design professionale e un link tutto tuo — gratis.', upB: 'Crealo gratis', home: 'Home', free: 'Biglietto gratis', privacy: 'Privacy',
    docTitle: 'Generatore QR code biglietto da visita gratis — TapMaroc'},
};
const AR = {};
$$('[data-q]').forEach((e) => { AR[e.dataset.q] = e.textContent; });
AR.ready = '✓ امسحه بهاتفك لتجربته';
AR.docTitle = document.title;
let lang = 'ar';
const q = (k) => (lang === 'ar' ? AR[k] : Q[lang][k]) ?? AR[k];

const COLORS = ['#0a0d16', '#c81e2c', '#138a45', '#1e3a8a', '#6d28d9', '#b7791f'];
let color = COLORS[0];
let mode = 'vcard';
let logo = null; // HTMLImageElement
let lastText = '';

const esc = (s) => String(s).replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');
const val = (id) => $(`#${id}`).value.trim();

function payload() {
  if (mode === 'link') {
    const wa = val('wa').replace(/[^0-9]/g, '');
    if (wa.length >= 8) return `https://wa.me/${wa}${val('waMsg') ? `?text=${encodeURIComponent(val('waMsg'))}` : ''}`;
    const u = val('url');
    if (!u) return '';
    return /^[a-z][a-z0-9+.-]*:/i.test(u) ? u : `https://${u}`;
  }
  const first = val('first'), last = val('last');
  if (!first && !last && !val('org') && !val('phone')) return '';
  const lines = ['BEGIN:VCARD', 'VERSION:3.0', `N:${esc(last)};${esc(first)};;;`, `FN:${esc([first, last].filter(Boolean).join(' ') || val('org'))}`];
  if (val('org')) lines.push(`ORG:${esc(val('org'))}`);
  if (val('job')) lines.push(`TITLE:${esc(val('job'))}`);
  if (val('phone')) lines.push(`TEL;TYPE=CELL:${val('phone').replace(/[^0-9+]/g, '')}`);
  if (val('email')) lines.push(`EMAIL:${esc(val('email'))}`);
  if (val('site')) lines.push(`URL:${esc(/^https?:/i.test(val('site')) ? val('site') : `https://${val('site')}`)}`);
  if (val('addr')) lines.push(`ADR:;;${esc(val('addr'))};;;;`);
  lines.push('END:VCARD');
  return lines.join('\n');
}

function matrix(text) {
  const qr = qrcode(0, logo ? 'H' : 'M');
  qr.addData(text);
  qr.make();
  return qr;
}

function draw() {
  const text = payload();
  lastText = text;
  const c = $('#qr'), x = c.getContext('2d');
  x.clearRect(0, 0, c.width, c.height);
  x.fillStyle = '#fff'; x.fillRect(0, 0, c.width, c.height);
  $('#png').disabled = $('#svg').disabled = !text;
  $('#hint').textContent = text ? q('ready') : q('hint');
  c.classList.toggle('empty', !text);
  if (!text) return;
  let qr;
  try { qr = matrix(text); } catch { return; }
  const n = qr.getModuleCount(), quiet = 3, cell = c.width / (n + quiet * 2);
  x.fillStyle = color;
  for (let r = 0; r < n; r++) for (let k = 0; k < n; k++) {
    if (qr.isDark(r, k)) x.fillRect(Math.floor((k + quiet) * cell), Math.floor((r + quiet) * cell), Math.ceil(cell), Math.ceil(cell));
  }
  if (logo) {
    const s = c.width * 0.22, p = (c.width - s) / 2;
    x.fillStyle = '#fff';
    x.beginPath(); x.roundRect(p - 10, p - 10, s + 20, s + 20, 18); x.fill();
    const ratio = Math.min(s / logo.width, s / logo.height), w = logo.width * ratio, hh = logo.height * ratio;
    x.drawImage(logo, (c.width - w) / 2, (c.height - hh) / 2, w, hh);
  }
}

function fileName(ext) {
  const base = (mode === 'vcard' ? [val('first'), val('last')].join('-') || val('org') : 'link') || 'qr';
  return `qr-${base.toLowerCase().replace(/[^a-z0-9\u0600-\u06ff]+/gi, '-').replace(/^-|-$/g, '') || 'tapmaroc'}.${ext}`;
}
function download(blob, name) {
  const u = URL.createObjectURL(blob); const a = document.createElement('a'); a.href = u; a.download = name; document.body.append(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(u), 2000);
}

function svg() {
  const qr = matrix(lastText), n = qr.getModuleCount(), quiet = 3, size = n + quiet * 2;
  let path = '';
  for (let r = 0; r < n; r++) for (let k = 0; k < n; k++) if (qr.isDark(r, k)) path += `M${k + quiet} ${r + quiet}h1v1h-1z`;
  let logoTag = '';
  if (logo) {
    const tmp = document.createElement('canvas'); tmp.width = logo.width; tmp.height = logo.height; tmp.getContext('2d').drawImage(logo, 0, 0);
    const s = size * 0.22, p = (size - s) / 2;
    logoTag = `<rect x="${p - 0.4}" y="${p - 0.4}" width="${s + 0.8}" height="${s + 0.8}" rx="0.7" fill="#fff"/><image x="${p}" y="${p}" width="${s}" height="${s}" preserveAspectRatio="xMidYMid meet" href="${tmp.toDataURL('image/png')}"/>`;
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size} ${size}" shape-rendering="crispEdges"><rect width="100%" height="100%" fill="#fff"/><path fill="${color}" d="${path}"/>${logoTag}</svg>`;
}

function setLang(l) {
  lang = Q[l] || l === 'ar' ? l : 'ar';
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
  $$('[data-q]').forEach((e) => { e.textContent = q(e.dataset.q); });
  $$('.langs button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.lang === lang)));
  document.title = q('docTitle');
  try { localStorage.setItem('tm_lang', lang); } catch { /* ignore */ }
  draw();
}

function start() {
  const box = $('#colors');
  for (const c of COLORS) {
    const b = document.createElement('button'); b.type = 'button'; b.style.background = c; b.setAttribute('aria-label', c);
    b.setAttribute('aria-pressed', String(c === color));
    b.addEventListener('click', () => { color = c; $$('#colors button').forEach((o) => o.setAttribute('aria-pressed', String(o === b))); draw(); });
    box.append(b);
  }
  $$('.seg button').forEach((b) => b.addEventListener('click', () => {
    mode = b.dataset.mode;
    $$('.seg button').forEach((o) => o.setAttribute('aria-selected', String(o === b)));
    $('#fCard').hidden = mode !== 'vcard'; $('#fLink').hidden = mode !== 'link';
    draw();
  }));
  $$('input:not([type=file])').forEach((i) => i.addEventListener('input', draw));
  $('#logo').addEventListener('change', (e) => {
    const f = e.target.files?.[0]; if (!f) return;
    const img = new Image();
    img.onload = () => { logo = img; $('#noLogo').hidden = false; draw(); };
    img.src = URL.createObjectURL(f);
  });
  $('#noLogo').addEventListener('click', () => { logo = null; $('#noLogo').hidden = true; $('#logo').value = ''; draw(); });
  $('#png').addEventListener('click', () => $('#qr').toBlob((b) => download(b, fileName('png')), 'image/png'));
  $('#svg').addEventListener('click', () => download(new Blob([svg()], {type: 'image/svg+xml'}), fileName('svg')));
  $$('.langs button').forEach((b) => b.addEventListener('click', () => setLang(b.dataset.lang)));
  let saved = null;
  try { saved = localStorage.getItem('tm_lang'); } catch { /* ignore */ }
  setLang(saved && (Q[saved] || saved === 'ar') ? saved : ((navigator.language || '').slice(0, 2) === 'fr' ? 'fr' : 'ar'));
}
start();
