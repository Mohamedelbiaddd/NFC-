// tapmaroc.com/start — free account: sign up / sign in, create one free
// digital business card, then get its link and QR code, edit it, share it,
// or order a printed NFC card. Everything sensitive is checked server-side
// (Supabase Auth + security-definer functions); this page only shows it.
import qrcode from '/qrcode.mjs';

const WHATSAPP = '393295586046';
const SITE = 'https://tapmaroc.com';
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const h = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };

// ---------------------------------------------------------------- words
const W = {
  ar: {
    title: 'أنشئ بطاقتك الرقمية مجاناً', sub: 'رابط خاص بك ورمز QR في دقيقة. بدون بطاقة بنكية.',
    signup: 'حساب جديد', login: 'دخول', email: 'البريد الإلكتروني', pass: 'كلمة المرور (8 أحرف على الأقل)', passLogin: 'كلمة المرور',
    create: 'إنشاء الحساب', enter: 'دخول', forgot: 'نسيت كلمة المرور؟', sendReset: 'أرسل رابط التغيير', back: 'رجوع',
    checkTitle: 'تحقق من بريدك 📩', checkText: 'أرسلنا رسالة إلى {e}. اضغط على الرابط داخلها لتفعيل حسابك، ثم ارجع هنا.', resend: 'إعادة إرسال الرسالة', resent: 'تم الإرسال مرة أخرى.',
    resetSent: 'إذا كان البريد مسجلاً، ستصلك رسالة لتغيير كلمة المرور.', newPass: 'كلمة مرور جديدة', savePass: 'حفظ كلمة المرور', passSaved: 'تم تغيير كلمة المرور ✓',
    notConfirmed: 'فعّل حسابك أولاً من الرسالة التي وصلتك في البريد.', badLogin: 'البريد أو كلمة المرور غير صحيحة.', weak: 'كلمة المرور قصيرة (8 أحرف على الأقل).', badEmail: 'البريد الإلكتروني غير صحيح.', net: 'تعذّر الاتصال، حاول مجدداً.', busy: 'ضغط كبير الآن، حاول بعد قليل.',
    mkTitle: 'لنصنع بطاقتك', mkSub: 'ثلاث معلومات فقط، والباقي تضيفه متى شئت: الصور، الروابط، الشبكات، التصميم.', name: 'الاسم الكامل', job: 'المهنة أو النشاط', phone: 'الهاتف / واتساب', mkBtn: 'أنشئ بطاقتي', needName: 'اكتب اسمك',
    dashTitle: 'بطاقتك جاهزة 🎉', yourLink: 'رابطك', copy: 'نسخ', copied: 'تم النسخ ✓', open: 'فتح البطاقة', edit: '✏️ تعديل البطاقة', share: 'مشاركة على واتساب', qrTitle: 'رمز QR الخاص بك', dlQr: 'تحميل QR', qrNote: 'اطبعه على بطاقة أو واجهة أو كوب… من يمسحه يفتح بطاقتك.',
    nfcTitle: 'اجعلها بطاقة NFC حقيقية', nfcText: 'نطبع لك بطاقة أنيقة ونبرمجها برابطك: يلمس الزبون هاتفه بها فتظهر بطاقتك.', nfcBtn: 'اطلب بطاقة NFC',
    shopTitle: 'عندك محل؟', shopText: 'بطاقة ولاء رقمية لزبائنك مع Google Wallet والدور والحجز.', shopBtn: 'اكتشف باقة المحل',
    logout: 'خروج', hello: 'مرحباً', shareText: 'هذه بطاقتي الرقمية:', orderMsg: 'مرحباً TapMaroc 👋\nأريد بطاقة NFC لبطاقتي:\n{u}', legal: 'بإنشاء الحساب أنت توافق على الشروط وسياسة الخصوصية.',
  },
  fr: {
    title: 'Créez votre carte digitale gratuitement', sub: 'Votre lien et votre QR code en une minute. Sans carte bancaire.',
    signup: 'Créer un compte', login: 'Connexion', email: 'E-mail', pass: 'Mot de passe (8 caractères min.)', passLogin: 'Mot de passe',
    create: 'Créer le compte', enter: 'Se connecter', forgot: 'Mot de passe oublié ?', sendReset: 'Envoyer le lien', back: 'Retour',
    checkTitle: 'Vérifiez votre e-mail 📩', checkText: 'Nous avons envoyé un message à {e}. Cliquez sur le lien pour activer votre compte, puis revenez ici.', resend: 'Renvoyer le message', resent: 'Message renvoyé.',
    resetSent: 'Si l’e-mail est inscrit, vous recevrez un lien pour changer le mot de passe.', newPass: 'Nouveau mot de passe', savePass: 'Enregistrer', passSaved: 'Mot de passe changé ✓',
    notConfirmed: 'Activez d’abord votre compte via l’e-mail reçu.', badLogin: 'E-mail ou mot de passe incorrect.', weak: 'Mot de passe trop court (8 caractères min.).', badEmail: 'E-mail invalide.', net: 'Connexion impossible, réessayez.', busy: 'Beaucoup de demandes, réessayez bientôt.',
    mkTitle: 'Créons votre carte', mkSub: 'Trois infos seulement ; le reste quand vous voulez : photos, liens, réseaux, design.', name: 'Nom complet', job: 'Métier ou activité', phone: 'Téléphone / WhatsApp', mkBtn: 'Créer ma carte', needName: 'Écrivez votre nom',
    dashTitle: 'Votre carte est prête 🎉', yourLink: 'Votre lien', copy: 'Copier', copied: 'Copié ✓', open: 'Ouvrir la carte', edit: '✏️ Modifier la carte', share: 'Partager sur WhatsApp', qrTitle: 'Votre QR code', dlQr: 'Télécharger le QR', qrNote: 'Imprimez-le sur une carte, une vitrine, un gobelet… qui le scanne ouvre votre carte.',
    nfcTitle: 'Passez à la vraie carte NFC', nfcText: 'Nous imprimons une carte élégante programmée avec votre lien : un simple contact avec le téléphone affiche votre carte.', nfcBtn: 'Commander une carte NFC',
    shopTitle: 'Vous avez un commerce ?', shopText: 'Carte de fidélité digitale avec Google Wallet, file d’attente et réservations.', shopBtn: 'Voir la formule commerce',
    logout: 'Déconnexion', hello: 'Bonjour', shareText: 'Voici ma carte digitale :', orderMsg: 'Bonjour TapMaroc 👋\nJe veux une carte NFC pour ma carte :\n{u}', legal: 'En créant un compte, vous acceptez les conditions et la politique de confidentialité.',
  },
  en: {
    title: 'Create your digital card for free', sub: 'Your own link and QR code in a minute. No bank card needed.',
    signup: 'Sign up', login: 'Sign in', email: 'Email', pass: 'Password (8+ characters)', passLogin: 'Password',
    create: 'Create account', enter: 'Sign in', forgot: 'Forgot password?', sendReset: 'Send reset link', back: 'Back',
    checkTitle: 'Check your email 📩', checkText: 'We sent a message to {e}. Tap the link inside to activate your account, then come back here.', resend: 'Resend the email', resent: 'Sent again.',
    resetSent: 'If the email is registered, you will receive a link to change your password.', newPass: 'New password', savePass: 'Save password', passSaved: 'Password changed ✓',
    notConfirmed: 'Activate your account first from the email you received.', badLogin: 'Wrong email or password.', weak: 'Password too short (8+ characters).', badEmail: 'Invalid email.', net: 'Connection failed, try again.', busy: 'Very busy right now, try again soon.',
    mkTitle: 'Let’s make your card', mkSub: 'Just three details; add the rest whenever you like: photos, links, socials, design.', name: 'Full name', job: 'Profession or business', phone: 'Phone / WhatsApp', mkBtn: 'Create my card', needName: 'Write your name',
    dashTitle: 'Your card is ready 🎉', yourLink: 'Your link', copy: 'Copy', copied: 'Copied ✓', open: 'Open card', edit: '✏️ Edit card', share: 'Share on WhatsApp', qrTitle: 'Your QR code', dlQr: 'Download QR', qrNote: 'Print it on a card, a window, a cup… whoever scans it opens your card.',
    nfcTitle: 'Make it a real NFC card', nfcText: 'We print an elegant card programmed with your link: one tap on a phone shows your card.', nfcBtn: 'Order an NFC card',
    shopTitle: 'Own a shop?', shopText: 'Digital loyalty card with Google Wallet, queue and booking.', shopBtn: 'See the shop plan',
    logout: 'Sign out', hello: 'Hello', shareText: 'Here is my digital card:', orderMsg: 'Hello TapMaroc 👋\nI’d like an NFC card for my card:\n{u}', legal: 'By creating an account you accept the terms and the privacy policy.',
  },
  it: {
    title: 'Crea gratis il tuo biglietto digitale', sub: 'Il tuo link e il tuo QR code in un minuto. Nessuna carta di credito.',
    signup: 'Registrati', login: 'Accedi', email: 'E-mail', pass: 'Password (min. 8 caratteri)', passLogin: 'Password',
    create: 'Crea account', enter: 'Accedi', forgot: 'Password dimenticata?', sendReset: 'Invia il link', back: 'Indietro',
    checkTitle: 'Controlla la tua e-mail 📩', checkText: 'Abbiamo inviato un messaggio a {e}. Tocca il link per attivare l’account, poi torna qui.', resend: 'Invia di nuovo', resent: 'Inviato di nuovo.',
    resetSent: 'Se l’e-mail è registrata, riceverai un link per cambiare la password.', newPass: 'Nuova password', savePass: 'Salva password', passSaved: 'Password cambiata ✓',
    notConfirmed: 'Attiva prima l’account dall’e-mail ricevuta.', badLogin: 'E-mail o password errata.', weak: 'Password troppo corta (min. 8 caratteri).', badEmail: 'E-mail non valida.', net: 'Connessione non riuscita, riprova.', busy: 'Molte richieste, riprova tra poco.',
    mkTitle: 'Creiamo il tuo biglietto', mkSub: 'Solo tre dati; il resto quando vuoi: foto, link, social, design.', name: 'Nome completo', job: 'Professione o attività', phone: 'Telefono / WhatsApp', mkBtn: 'Crea il mio biglietto', needName: 'Scrivi il tuo nome',
    dashTitle: 'Il tuo biglietto è pronto 🎉', yourLink: 'Il tuo link', copy: 'Copia', copied: 'Copiato ✓', open: 'Apri il biglietto', edit: '✏️ Modifica il biglietto', share: 'Condividi su WhatsApp', qrTitle: 'Il tuo QR code', dlQr: 'Scarica il QR', qrNote: 'Stampalo su un biglietto, una vetrina, una tazza… chi lo scansiona apre il tuo biglietto.',
    nfcTitle: 'Trasformalo in una vera tessera NFC', nfcText: 'Stampiamo una tessera elegante programmata con il tuo link: basta avvicinarla al telefono.', nfcBtn: 'Ordina una tessera NFC',
    shopTitle: 'Hai un negozio?', shopText: 'Tessera fedeltà digitale con Google Wallet, coda e prenotazioni.', shopBtn: 'Scopri il pacchetto negozio',
    logout: 'Esci', hello: 'Ciao', shareText: 'Ecco il mio biglietto digitale:', orderMsg: 'Ciao TapMaroc 👋\nVorrei una tessera NFC per il mio biglietto:\n{u}', legal: 'Creando l’account accetti i termini e l’informativa privacy.',
  },
};
let lang = (() => { try { const s = localStorage.getItem('tm_lang'); if (W[s]) return s; } catch { /* ignore */ } const n = (navigator.language || '').slice(0, 2); return W[n] && n !== 'en' ? n : 'ar'; })();
const w = (k, vars = {}) => Object.entries(vars).reduce((t, [a, b]) => t.replaceAll(`{${a}}`, b), W[lang][k] ?? W.ar[k] ?? k);

// ---------------------------------------------------------------- api
let CONFIG = null;
const SESSION = 'tm_auth';
const loadSession = () => { try { return JSON.parse(localStorage.getItem(SESSION) || 'null'); } catch { return null; } };
const saveSession = (s) => { try { s ? localStorage.setItem(SESSION, JSON.stringify(s)) : localStorage.removeItem(SESSION); } catch { /* ignore */ } };
const fromAuth = (d) => ({access_token: d.access_token, refresh_token: d.refresh_token, expires_at: Math.floor(Date.now() / 1000) + (Number(d.expires_in) || 3600), email: d.user?.email ?? ''});

async function call(path, {method = 'POST', body, token} = {}) {
  const r = await fetch(`${CONFIG.supabaseUrl}${path}`, {
    method,
    headers: {'Content-Type': 'application/json', apikey: CONFIG.publishableKey, ...(token ? {Authorization: `Bearer ${token}`} : {})},
    body: body === undefined ? undefined : JSON.stringify(body), cache: 'no-store',
  });
  const data = await r.json().catch(() => null);
  return {ok: r.ok, status: r.status, data};
}
async function token() {
  let s = loadSession();
  if (!s) return null;
  if (s.expires_at - 60 > Date.now() / 1000) return s.access_token;
  const r = await call('/auth/v1/token?grant_type=refresh_token', {body: {refresh_token: s.refresh_token}});
  if (!r.ok || !r.data?.access_token) { saveSession(null); return null; }
  s = fromAuth(r.data); saveSession(s);
  return s.access_token;
}
async function rpc(name, body = {}) {
  const tk = await token();
  if (!tk) throw new Error('auth');
  const r = await call(`/rest/v1/rpc/${name}`, {body, token: tk});
  if (r.status === 401) { saveSession(null); throw new Error('auth'); }
  if (!r.ok) throw new Error(r.data?.message || 'error');
  return r.data;
}
const redirect = encodeURIComponent(`${SITE}/start`);

// ---------------------------------------------------------------- ui helpers
const view = () => $('#view');
function card(...kids) { const c = h('div', 'acct-card'); c.append(...kids); view().replaceChildren(c); return c; }
function field(label, type = 'text', attrs = {}) {
  const l = h('label', 'acct-field'); const i = h('input'); i.type = type; Object.assign(i, attrs); l.append(h('span', '', label), i); return {l, i};
}
const msg = () => h('p', 'acct-msg');
function busy(btn, on) { btn.disabled = on; btn.classList.toggle('loading', on); }

// ---------------------------------------------------------------- views
function authView(mode = 'signup', note = '') {
  const tabs = h('div', 'seg');
  for (const m of ['signup', 'login']) {
    const b = h('button', '', w(m)); b.type = 'button'; b.setAttribute('aria-selected', String(m === mode));
    b.addEventListener('click', () => authView(m)); tabs.append(b);
  }
  const email = field(w('email'), 'email', {autocomplete: 'email', dir: 'ltr', required: true});
  const pass = field(mode === 'signup' ? w('pass') : w('passLogin'), 'password', {autocomplete: mode === 'signup' ? 'new-password' : 'current-password', dir: 'ltr', minLength: 8});
  const m = msg(); m.textContent = note;
  const go = h('button', 'btn btn-red', mode === 'signup' ? w('create') : w('enter')); go.type = 'button';
  const forgot = h('button', 'link-btn', w('forgot')); forgot.type = 'button';
  forgot.addEventListener('click', () => forgotView(email.i.value));
  const legal = h('p', 'acct-legal', w('legal'));
  const head = h('div', 'acct-head'); head.append(h('h1', '', w('title')), h('p', '', w('sub')));
  const c = card(head, tabs, email.l, pass.l, m, go, ...(mode === 'login' ? [forgot] : [legal]));
  c.classList.add('auth');
  const submit = async () => {
    const e = email.i.value.trim().toLowerCase(), p = pass.i.value;
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) { m.textContent = w('badEmail'); return; }
    if (p.length < 8) { m.textContent = w('weak'); return; }
    busy(go, true); m.textContent = '';
    try {
      if (mode === 'signup') {
        const r = await call(`/auth/v1/signup?redirect_to=${redirect}`, {body: {email: e, password: p, data: {lang, source: 'tapmaroc.com'}}});
        if (!r.ok) { m.textContent = r.status === 429 ? w('busy') : (r.data?.msg || r.data?.message || w('net')); return; }
        if (r.data?.access_token) { saveSession(fromAuth(r.data)); return home(); }
        return checkView(e);
      }
      const r = await call('/auth/v1/token?grant_type=password', {body: {email: e, password: p}});
      if (!r.ok) {
        const code = r.data?.error_code || r.data?.code || '';
        m.textContent = /not_confirmed/.test(code) || /confirm/i.test(r.data?.msg || '') ? w('notConfirmed') : r.status === 429 ? w('busy') : w('badLogin');
        return;
      }
      saveSession(fromAuth(r.data));
      home();
    } catch { m.textContent = w('net'); } finally { busy(go, false); }
  };
  go.addEventListener('click', submit);
  pass.i.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') submit(); });
}

function checkView(email) {
  const m = msg();
  const again = h('button', 'btn btn-ghost', w('resend')); again.type = 'button';
  again.addEventListener('click', async () => {
    busy(again, true);
    try { const r = await call(`/auth/v1/resend?redirect_to=${redirect}`, {body: {type: 'signup', email}}); m.textContent = r.ok ? w('resent') : w('busy'); } catch { m.textContent = w('net'); } finally { busy(again, false); }
  });
  const back = h('button', 'link-btn', w('login')); back.type = 'button'; back.addEventListener('click', () => authView('login'));
  card(h('div', 'acct-icon', '📩'), h('h2', '', w('checkTitle')), h('p', 'acct-text', w('checkText', {e: email})), again, m, back);
}

function forgotView(prefill = '') {
  const email = field(w('email'), 'email', {value: prefill, dir: 'ltr', autocomplete: 'email'});
  const m = msg();
  const go = h('button', 'btn btn-red', w('sendReset')); go.type = 'button';
  const back = h('button', 'link-btn', w('back')); back.type = 'button'; back.addEventListener('click', () => authView('login'));
  go.addEventListener('click', async () => {
    busy(go, true);
    try { await call(`/auth/v1/recover?redirect_to=${redirect}`, {body: {email: email.i.value.trim().toLowerCase()}}); m.textContent = w('resetSent'); } catch { m.textContent = w('net'); } finally { busy(go, false); }
  });
  card(h('h2', '', w('forgot')), email.l, m, go, back);
}

function newPassView() {
  const pass = field(w('newPass'), 'password', {autocomplete: 'new-password', dir: 'ltr', minLength: 8});
  const m = msg();
  const go = h('button', 'btn btn-red', w('savePass')); go.type = 'button';
  go.addEventListener('click', async () => {
    if (pass.i.value.length < 8) { m.textContent = w('weak'); return; }
    busy(go, true);
    try {
      const r = await call('/auth/v1/user', {method: 'PUT', body: {password: pass.i.value}, token: await token()});
      if (!r.ok) { m.textContent = r.data?.msg || w('net'); return; }
      m.textContent = w('passSaved');
      setTimeout(home, 900);
    } catch { m.textContent = w('net'); } finally { busy(go, false); }
  });
  card(h('h2', '', w('newPass')), pass.l, m, go);
}

function createView() {
  const name = field(w('name'), 'text', {maxLength: 80, autocomplete: 'name'});
  const job = field(w('job'), 'text', {maxLength: 80, autocomplete: 'organization-title'});
  const phone = field(w('phone'), 'tel', {maxLength: 20, dir: 'ltr', autocomplete: 'tel', inputMode: 'tel'});
  const m = msg();
  const go = h('button', 'btn btn-red', w('mkBtn')); go.type = 'button';
  go.addEventListener('click', async () => {
    if (name.i.value.trim().length < 2) { m.textContent = w('needName'); return; }
    busy(go, true); m.textContent = '';
    try {
      await rpc('nfc_free_card_create', {full_name: name.i.value, job_title: job.i.value, phone: phone.i.value});
      home();
    } catch (e) {
      if (e.message === 'auth') return authView('login');
      m.textContent = /Busy/.test(e.message) ? w('busy') : /confirm/i.test(e.message) ? w('notConfirmed') : w('net');
    } finally { busy(go, false); }
  });
  card(topBar(), h('h2', '', w('mkTitle')), h('p', 'acct-text', w('mkSub')), name.l, job.l, phone.l, m, go);
}

function topBar() {
  const s = loadSession();
  const bar = h('div', 'acct-bar');
  const out = h('button', 'link-btn', w('logout')); out.type = 'button';
  out.addEventListener('click', async () => { try { await call('/auth/v1/logout', {token: s?.access_token}); } catch { /* ignore */ } saveSession(null); authView('login'); });
  bar.append(h('span', '', `${w('hello')} ${s?.email ?? ''}`), out);
  return bar;
}

function qrCanvas(text, size) {
  const q = qrcode(0, 'M'); q.addData(text); q.make();
  const n = q.getModuleCount(), quiet = 4, cell = Math.floor(size / (n + quiet * 2)), dim = cell * (n + quiet * 2);
  const c = document.createElement('canvas'); c.width = c.height = dim;
  const x = c.getContext('2d'); x.fillStyle = '#fff'; x.fillRect(0, 0, dim, dim); x.fillStyle = '#0a0d16';
  for (let r = 0; r < n; r++) for (let col = 0; col < n; col++) if (q.isDark(r, col)) x.fillRect((col + quiet) * cell, (r + quiet) * cell, cell, cell);
  return c;
}

function dashView(cardData) {
  const url = `${SITE}/p/${cardData.slug}`;
  const linkBox = h('div', 'acct-link');
  const a = h('a', '', url.replace('https://', '')); a.href = url; a.target = '_blank'; a.rel = 'noopener'; a.dir = 'ltr';
  const copy = h('button', 'btn btn-ghost btn-sm', w('copy')); copy.type = 'button';
  copy.addEventListener('click', async () => { try { await navigator.clipboard.writeText(url); copy.textContent = w('copied'); setTimeout(() => { copy.textContent = w('copy'); }, 1500); } catch { /* ignore */ } });
  linkBox.append(a, copy);

  const edit = h('button', 'btn btn-red', w('edit')); edit.type = 'button';
  edit.addEventListener('click', async () => {
    busy(edit, true);
    try {
      const r = await rpc('nfc_my_card_edit_code');
      try { sessionStorage.setItem(`tm_edit_${r.slug}`, r.code); } catch { /* ignore */ }
      location.href = `/p/${r.slug}`;
    } catch (e) { if (e.message === 'auth') authView('login'); busy(edit, false); }
  });
  const open = h('a', 'btn btn-ghost', w('open')); open.href = url; open.target = '_blank'; open.rel = 'noopener';
  const share = h('a', 'btn btn-green', w('share')); share.href = `https://wa.me/?text=${encodeURIComponent(`${w('shareText')} ${url}`)}`; share.target = '_blank'; share.rel = 'noopener';
  const actions = h('div', 'acct-actions'); actions.append(edit, open, share);

  const qrBox = h('div', 'acct-qr');
  const shown = qrCanvas(`${url}?src=qr`, 520); shown.className = 'qr-img';
  const dl = h('button', 'btn btn-ghost btn-sm', `⬇️ ${w('dlQr')}`); dl.type = 'button';
  dl.addEventListener('click', () => {
    qrCanvas(`${url}?src=qr`, 1200).toBlob((b) => { const u = URL.createObjectURL(b); const l = h('a'); l.href = u; l.download = `tapmaroc-${cardData.slug}-qr.png`; document.body.append(l); l.click(); l.remove(); setTimeout(() => URL.revokeObjectURL(u), 2000); }, 'image/png');
  });
  const qrTxt = h('div'); qrTxt.append(h('h3', '', w('qrTitle')), h('p', 'acct-text', w('qrNote')), dl);
  qrBox.append(shown, qrTxt);

  const up1 = h('div', 'acct-up red');
  const nfc = h('a', 'btn btn-red btn-sm', w('nfcBtn')); nfc.href = `https://wa.me/${WHATSAPP}?text=${encodeURIComponent(w('orderMsg', {u: url}))}`; nfc.target = '_blank'; nfc.rel = 'noopener';
  up1.append(h('span', 'acct-up-ic', '📡'), (() => { const d = h('div'); d.append(h('b', '', w('nfcTitle')), h('p', '', w('nfcText'))); return d; })(), nfc);
  const up2 = h('div', 'acct-up green');
  const shop = h('a', 'btn btn-ghost btn-sm', w('shopBtn')); shop.href = lang === 'ar' ? '/#pricing' : `/${lang}#pricing`;
  up2.append(h('span', 'acct-up-ic', '🎁'), (() => { const d = h('div'); d.append(h('b', '', w('shopTitle')), h('p', '', w('shopText'))); return d; })(), shop);

  const who = h('div', 'acct-who'); who.append(h('b', '', cardData.title), h('small', '', cardData.data?.job_title || ''));
  card(topBar(), h('h2', '', w('dashTitle')), who, h('p', 'acct-label', w('yourLink')), linkBox, actions, qrBox, up1, up2);
}

async function home() {
  if (!(await token())) return authView(new URLSearchParams(location.search).get('m') === 'login' ? 'login' : 'signup');
  card(h('p', 'acct-text', '…'));
  try {
    const mine = await rpc('nfc_my_card');
    if (mine && mine.slug) dashView(mine); else createView();
  } catch (e) { if (e.message === 'auth') authView('login'); else card(h('p', 'acct-msg', w('net'))); }
}

// ---------------------------------------------------------------- boot
function setLang(l) {
  lang = W[l] ? l : 'ar';
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
  document.title = `TapMaroc — ${W[lang].title}`;
  $$('.langs button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.lang === lang)));
  try { localStorage.setItem('tm_lang', lang); } catch { /* ignore */ }
}

async function start() {
  setLang(lang);
  $$('.langs button').forEach((b) => b.addEventListener('click', () => { setLang(b.dataset.lang); home(); }));
  try { CONFIG = await (await fetch('/config.json', {cache: 'no-store'})).json(); } catch { card(h('p', 'acct-msg', 'config')); return; }
  // Coming back from an e-mail link: #access_token=…&type=signup|recovery
  const hp = new URLSearchParams(location.hash.slice(1));
  if (hp.get('access_token')) {
    saveSession(fromAuth({access_token: hp.get('access_token'), refresh_token: hp.get('refresh_token'), expires_in: hp.get('expires_in')}));
    const type = hp.get('type');
    history.replaceState(null, '', location.pathname);
    if (type === 'recovery') return newPassView();
  } else if (hp.get('error_description')) {
    history.replaceState(null, '', location.pathname);
    return authView('login', hp.get('error_description').replace(/\+/g, ' '));
  }
  home();
}
start();
