// tapmaroc.com/k/<CODE> — programmable TapMaroc cards / stickers.
// Active code: jump straight to what it opens (business card, Google review,
// Instagram…). Blank code: the buyer activates it with their own password and
// picks what it opens. ?edit: the owner changes it later (code + password).
// All checks (one activation, password, lockout) happen in the database.

const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
const h = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };

const TYPES = [
  {id: 'card', e: '💳', n: {ar: 'بطاقة أعمال', fr: 'Carte de visite', en: 'Business card', it: 'Biglietto da visita'}},
  {id: 'google_review', e: '⭐', n: {ar: 'تقييم Google', fr: 'Avis Google', en: 'Google review', it: 'Recensione Google'}},
  {id: 'instagram', e: '📸', n: {ar: 'Instagram', fr: 'Instagram', en: 'Instagram', it: 'Instagram'}},
  {id: 'whatsapp', e: '💬', n: {ar: 'WhatsApp', fr: 'WhatsApp', en: 'WhatsApp', it: 'WhatsApp'}},
  {id: 'tiktok', e: '🎵', n: {ar: 'TikTok', fr: 'TikTok', en: 'TikTok', it: 'TikTok'}},
  {id: 'facebook', e: '📘', n: {ar: 'Facebook', fr: 'Facebook', en: 'Facebook', it: 'Facebook'}},
  {id: 'website', e: '🌐', n: {ar: 'موقع أو رابط آخر', fr: 'Site ou autre lien', en: 'Website or other link', it: 'Sito o altro link'}},
];

const W = {
  ar: {
    newTitle: 'فعّل بطاقتك ✨', newSub: 'هذه البطاقة جديدة. اختر ماذا تفتح عندما يلمسها أحد أو يمسح رمزها. يمكنك تغيير ذلك لاحقاً في أي وقت.',
    pick: 'ماذا تفتح البطاقة؟', next: 'التالي', back: 'رجوع', name: 'الاسم الكامل', job: 'المهنة أو النشاط', phone: 'الهاتف / واتساب',
    v_google_review: 'رابط التقييم في Google', h_google_review: 'من Google Business Profile اضغط «اطلب تقييمات» (Ask for reviews) وانسخ الرابط.',
    v_instagram: 'اسم المستخدم في Instagram', v_whatsapp: 'رقم واتساب مع رمز الدولة', v_tiktok: 'اسم المستخدم في TikTok', v_facebook: 'رابط صفحتك أو اسمها', v_website: 'الرابط',
    passTitle: 'كلمة المرور الخاصة بك', passSub: 'بها فقط تستطيع تغيير ما تفتحه البطاقة لاحقاً. احفظها جيداً.', pass: 'كلمة المرور (6 أحرف على الأقل)', pass2: 'أعد كتابة كلمة المرور', contact: 'هاتفك أو بريدك (اختياري، لمساعدتك إذا نسيت كلمة المرور)',
    activate: 'تفعيل البطاقة', mismatch: 'كلمتا المرور غير متطابقتين.', weak: 'كلمة المرور قصيرة.', needName: 'اكتب اسمك.', needValue: 'اكتب الرابط أو الاسم.', badLink: 'الرابط غير صحيح.', taken: 'هذه البطاقة مفعّلة مسبقاً.', net: 'تعذّر الاتصال، حاول مجدداً.',
    doneTitle: 'تم تفعيل بطاقتك 🎉', doneSub: 'احفظ هذه المعلومات لتعديل بطاقتك لاحقاً:', yourCode: 'رمز بطاقتك', editAt: 'رابط التعديل', finishCard: '✏️ أكمل بطاقتك (صورة، روابط، تصميم)', test: 'جرّب البطاقة',
    editTitle: 'تعديل البطاقة', editSub: 'اكتب كلمة المرور التي اخترتها عند التفعيل.', enter: 'دخول', wrong: 'كلمة المرور غير صحيحة.', locked: 'محاولات كثيرة. حاول بعد 15 دقيقة.',
    now: 'تفتح الآن:', save: 'حفظ', saved: 'تم الحفظ ✓', newPass: 'كلمة مرور جديدة (اختياري)', openEditor: '✏️ تعديل بطاقة الأعمال', scans: 'عدد المسحات: {n}', forgot: 'نسيت كلمة المرور؟ تواصل معنا عبر واتساب.',
    disabled: 'هذه البطاقة موقوفة حالياً.', unknown: 'هذا الرمز غير موجود.', notSet: 'هذه البطاقة لم تُبرمج بعد.', home: 'الصفحة الرئيسية', ownerEdit: 'أنا صاحب البطاقة — تعديل',
  },
  fr: {
    newTitle: 'Activez votre carte ✨', newSub: 'Cette carte est neuve. Choisissez ce qu’elle ouvre quand on la touche ou qu’on scanne son code. Modifiable à tout moment.',
    pick: 'Que doit ouvrir la carte ?', next: 'Suivant', back: 'Retour', name: 'Nom complet', job: 'Métier ou activité', phone: 'Téléphone / WhatsApp',
    v_google_review: 'Lien d’avis Google', h_google_review: 'Dans Google Business Profile, touchez « Demander des avis » et copiez le lien.',
    v_instagram: 'Nom d’utilisateur Instagram', v_whatsapp: 'Numéro WhatsApp avec indicatif', v_tiktok: 'Nom d’utilisateur TikTok', v_facebook: 'Lien ou nom de votre page', v_website: 'Lien',
    passTitle: 'Votre mot de passe', passSub: 'Lui seul permet de changer plus tard ce qu’ouvre la carte. Gardez-le bien.', pass: 'Mot de passe (6 caractères min.)', pass2: 'Répétez le mot de passe', contact: 'Votre téléphone ou e-mail (facultatif, en cas d’oubli)',
    activate: 'Activer la carte', mismatch: 'Les mots de passe ne correspondent pas.', weak: 'Mot de passe trop court.', needName: 'Écrivez votre nom.', needValue: 'Écrivez le lien ou le nom.', badLink: 'Lien invalide.', taken: 'Cette carte est déjà activée.', net: 'Connexion impossible, réessayez.',
    doneTitle: 'Votre carte est activée 🎉', doneSub: 'Gardez ces infos pour la modifier plus tard :', yourCode: 'Code de la carte', editAt: 'Lien de modification', finishCard: '✏️ Compléter ma carte (photo, liens, design)', test: 'Tester la carte',
    editTitle: 'Modifier la carte', editSub: 'Saisissez le mot de passe choisi à l’activation.', enter: 'Entrer', wrong: 'Mot de passe incorrect.', locked: 'Trop d’essais. Réessayez dans 15 minutes.',
    now: 'Ouvre actuellement :', save: 'Enregistrer', saved: 'Enregistré ✓', newPass: 'Nouveau mot de passe (facultatif)', openEditor: '✏️ Modifier la carte de visite', scans: 'Scans : {n}', forgot: 'Mot de passe oublié ? Contactez-nous sur WhatsApp.',
    disabled: 'Cette carte est suspendue.', unknown: 'Ce code n’existe pas.', notSet: 'Cette carte n’est pas encore programmée.', home: 'Accueil', ownerEdit: 'Je suis le propriétaire — modifier',
  },
  en: {
    newTitle: 'Activate your card ✨', newSub: 'This card is new. Choose what it opens when someone taps it or scans its code. You can change it anytime.',
    pick: 'What should the card open?', next: 'Next', back: 'Back', name: 'Full name', job: 'Profession or business', phone: 'Phone / WhatsApp',
    v_google_review: 'Google review link', h_google_review: 'In Google Business Profile tap “Ask for reviews” and copy the link.',
    v_instagram: 'Instagram username', v_whatsapp: 'WhatsApp number with country code', v_tiktok: 'TikTok username', v_facebook: 'Your page link or name', v_website: 'Link',
    passTitle: 'Your password', passSub: 'Only with it can you change what the card opens later. Keep it safe.', pass: 'Password (6+ characters)', pass2: 'Repeat the password', contact: 'Your phone or email (optional, if you forget the password)',
    activate: 'Activate card', mismatch: 'Passwords don’t match.', weak: 'Password too short.', needName: 'Write your name.', needValue: 'Write the link or name.', badLink: 'Invalid link.', taken: 'This card is already activated.', net: 'Connection failed, try again.',
    doneTitle: 'Your card is active 🎉', doneSub: 'Keep these details to edit it later:', yourCode: 'Card code', editAt: 'Edit link', finishCard: '✏️ Finish my card (photo, links, design)', test: 'Test the card',
    editTitle: 'Edit card', editSub: 'Type the password you chose when activating.', enter: 'Sign in', wrong: 'Wrong password.', locked: 'Too many tries. Try again in 15 minutes.',
    now: 'Currently opens:', save: 'Save', saved: 'Saved ✓', newPass: 'New password (optional)', openEditor: '✏️ Edit business card', scans: 'Scans: {n}', forgot: 'Forgot the password? Contact us on WhatsApp.',
    disabled: 'This card is paused.', unknown: 'This code doesn’t exist.', notSet: 'This card isn’t programmed yet.', home: 'Home', ownerEdit: 'I’m the owner — edit',
  },
  it: {
    newTitle: 'Attiva la tua tessera ✨', newSub: 'Questa tessera è nuova. Scegli cosa apre quando qualcuno la tocca o ne scansiona il codice. Puoi cambiarlo quando vuoi.',
    pick: 'Cosa deve aprire la tessera?', next: 'Avanti', back: 'Indietro', name: 'Nome completo', job: 'Professione o attività', phone: 'Telefono / WhatsApp',
    v_google_review: 'Link recensione Google', h_google_review: 'In Google Business Profile tocca «Chiedi recensioni» e copia il link.',
    v_instagram: 'Nome utente Instagram', v_whatsapp: 'Numero WhatsApp con prefisso', v_tiktok: 'Nome utente TikTok', v_facebook: 'Link o nome della pagina', v_website: 'Link',
    passTitle: 'La tua password', passSub: 'Solo con questa potrai cambiare cosa apre la tessera. Conservala bene.', pass: 'Password (min. 6 caratteri)', pass2: 'Ripeti la password', contact: 'Telefono o e-mail (facoltativo, se dimentichi la password)',
    activate: 'Attiva tessera', mismatch: 'Le password non coincidono.', weak: 'Password troppo corta.', needName: 'Scrivi il tuo nome.', needValue: 'Scrivi il link o il nome.', badLink: 'Link non valido.', taken: 'Questa tessera è già attiva.', net: 'Connessione non riuscita, riprova.',
    doneTitle: 'Tessera attivata 🎉', doneSub: 'Conserva questi dati per modificarla in seguito:', yourCode: 'Codice tessera', editAt: 'Link di modifica', finishCard: '✏️ Completa il biglietto (foto, link, design)', test: 'Prova la tessera',
    editTitle: 'Modifica tessera', editSub: 'Scrivi la password scelta all’attivazione.', enter: 'Entra', wrong: 'Password errata.', locked: 'Troppi tentativi. Riprova tra 15 minuti.',
    now: 'Ora apre:', save: 'Salva', saved: 'Salvato ✓', newPass: 'Nuova password (facoltativa)', openEditor: '✏️ Modifica biglietto da visita', scans: 'Scansioni: {n}', forgot: 'Password dimenticata? Scrivici su WhatsApp.',
    disabled: 'Questa tessera è sospesa.', unknown: 'Questo codice non esiste.', notSet: 'Questa tessera non è ancora programmata.', home: 'Home', ownerEdit: 'Sono il proprietario — modifica',
  },
};
let lang = (() => { try { const s = localStorage.getItem('tm_lang'); if (W[s]) return s; } catch { /* ignore */ } const n = (navigator.language || '').slice(0, 2); return W[n] && n !== 'en' ? n : 'ar'; })();
const w = (k, v = {}) => Object.entries(v).reduce((t, [a, b]) => t.replaceAll(`{${a}}`, b), W[lang][k] ?? W.ar[k] ?? k);
const tname = (id) => { const t = TYPES.find((x) => x.id === id); return t ? `${t.e} ${t.n[lang]}` : id; };

const CODE = (location.pathname.match(/^\/k\/([A-Za-z0-9]{8})\/?$/)?.[1] ?? new URLSearchParams(location.search).get('c') ?? '').toUpperCase();
const EDIT = new URLSearchParams(location.search).has('edit');
const WA = '393295586046';
let CONFIG = null;

async function rpc(name, body) {
  const r = await fetch(`${CONFIG.supabaseUrl}/rest/v1/rpc/${name}`, {
    method: 'POST', headers: {'Content-Type': 'application/json', apikey: CONFIG.publishableKey}, body: JSON.stringify(body), cache: 'no-store',
  });
  const data = await r.json().catch(() => null);
  if (!r.ok) throw new Error(data?.message || 'error');
  return data;
}
const errText = (m) => /Weak/.test(m) ? w('weak') : /Name/.test(m) ? w('needName') : /Link required/.test(m) ? w('needValue') : /Invalid link/.test(m) ? w('badLink')
  : /Already/.test(m) ? w('taken') : /Too many/.test(m) ? w('locked') : /Wrong|Invalid code/.test(m) ? w('wrong') : w('net');

function card(...kids) { const c = h('div', 'acct-card'); c.append(...kids); $('#view').replaceChildren(c); return c; }
function field(label, type = 'text', attrs = {}) { const l = h('label', 'acct-field'); const i = h('input'); i.type = type; Object.assign(i, attrs); l.append(h('span', '', label), i); return {l, i}; }
const btn = (cls, text) => { const b = h('button', cls, text); b.type = 'button'; return b; };
function codeBadge() { const b = h('div', 'tag-code'); b.append(h('small', '', w('yourCode')), h('b', '', CODE.replace(/(.{4})/, '$1-'))); return b; }

// What the user wants the card to open: type picker + its fields.
function typeForm(state) {
  const box = h('div', 'tag-form');
  const grid = h('div', 'tag-types');
  for (const t of TYPES) {
    const b = btn('tag-type', ''); b.append(h('span', '', t.e), h('b', '', t.n[lang]));
    b.setAttribute('aria-pressed', String(state.type === t.id));
    b.addEventListener('click', () => { state.type = t.id; draw(); });
    grid.append(b);
  }
  const fields = h('div', 'tag-fields');
  const draw = () => {
    $$('.tag-type', grid).forEach((b, i) => b.setAttribute('aria-pressed', String(TYPES[i].id === state.type)));
    fields.replaceChildren();
    if (!state.type) return;
    if (state.type === 'card') {
      if (state.hasCard) return;
      const n = field(w('name'), 'text', {value: state.name ?? '', maxLength: 80, autocomplete: 'name'}); n.i.addEventListener('input', () => { state.name = n.i.value; });
      const j = field(w('job'), 'text', {value: state.job ?? '', maxLength: 80}); j.i.addEventListener('input', () => { state.job = j.i.value; });
      const p = field(w('phone'), 'tel', {value: state.phone ?? '', maxLength: 20, dir: 'ltr'}); p.i.addEventListener('input', () => { state.phone = p.i.value; });
      fields.append(n.l, j.l, p.l);
    } else {
      const v = field(w(`v_${state.type}`), state.type === 'whatsapp' ? 'tel' : 'text', {value: state.value ?? '', maxLength: 400, dir: 'ltr', placeholder: state.type === 'instagram' || state.type === 'tiktok' ? '@' : state.type === 'whatsapp' ? '+212 6…' : 'https://'});
      v.i.addEventListener('input', () => { state.value = v.i.value; });
      fields.append(v.l);
      if (state.type === 'google_review') fields.append(h('p', 'acct-text tag-help', w('h_google_review')));
    }
  };
  draw();
  box.append(h('p', 'lbl', w('pick')), grid, fields);
  return box;
}
const payload = (s) => (s.type === 'card' ? {kind: 'card', full_name: s.name ?? '', job_title: s.job ?? '', phone: s.phone ?? ''} : {kind: 'link', link_type: s.type, value: s.value ?? ''});

function activateView() {
  const state = {type: null};
  const pass = field(w('pass'), 'password', {autocomplete: 'new-password', dir: 'ltr', minLength: 6});
  const pass2 = field(w('pass2'), 'password', {autocomplete: 'new-password', dir: 'ltr'});
  const contact = field(w('contact'), 'text', {maxLength: 120, dir: 'ltr'});
  const m = h('p', 'acct-msg');
  const go = btn('btn btn-red', w('activate'));
  go.addEventListener('click', async () => {
    if (!state.type) { m.textContent = w('pick'); return; }
    if (state.type === 'card' && (state.name ?? '').trim().length < 2) { m.textContent = w('needName'); return; }
    if (state.type !== 'card' && !(state.value ?? '').trim()) { m.textContent = w('needValue'); return; }
    if (pass.i.value.length < 6) { m.textContent = w('weak'); return; }
    if (pass.i.value !== pass2.i.value) { m.textContent = w('mismatch'); return; }
    go.disabled = true; m.textContent = '';
    try {
      const r = await rpc('nfc_tag_activate', {code: CODE, password: pass.i.value, contact: contact.i.value, ...payload(state)});
      doneView(r, pass.i.value);
    } catch (e) { m.textContent = errText(e.message); go.disabled = false; }
  });
  const head = h('div', 'acct-head'); head.append(h('h1', '', w('newTitle')), h('p', '', w('newSub')));
  card(head, codeBadge(), typeForm(state), h('h3', 'tag-sec', w('passTitle')), h('p', 'acct-text', w('passSub')), pass.l, pass2.l, contact.l, m, go);
}

function openEditor(slug, password) {
  try { sessionStorage.setItem(`tm_edit_${slug}`, password); } catch { /* ignore */ }
  location.href = `/p/${slug}`;
}

function doneView(r, password) {
  const editLink = `${location.origin}/k/${CODE}?edit`;
  const info = h('div', 'tag-done');
  info.append(codeBadge());
  const l = h('div', 'acct-link'); const a = h('a', '', editLink.replace('https://', '')); a.href = editLink; a.dir = 'ltr'; l.append(a);
  info.append(h('p', 'acct-label', w('editAt')), l);
  const acts = h('div', 'acct-actions');
  if (r.kind === 'card' && r.slug) { const f = btn('btn btn-red', w('finishCard')); f.addEventListener('click', () => openEditor(r.slug, password)); acts.append(f); }
  const t = h('a', 'btn btn-ghost', w('test')); t.href = r.kind === 'card' ? `/p/${r.slug}` : r.url; t.target = '_blank'; t.rel = 'noopener'; acts.append(t);
  card(h('div', 'acct-icon', '🎉'), h('h2', '', w('doneTitle')), h('p', 'acct-text', w('doneSub')), info, acts);
}

function loginView() {
  const pass = field(w('pass'), 'password', {autocomplete: 'current-password', dir: 'ltr'});
  const m = h('p', 'acct-msg');
  const go = btn('btn btn-red', w('enter'));
  const submit = async () => {
    go.disabled = true; m.textContent = '';
    try {
      const r = await rpc('nfc_tag_login', {code: CODE, password: pass.i.value});
      if (!r?.ok) { m.textContent = errText(r?.error || ''); return; }
      editView(r, pass.i.value);
    } catch (e) { m.textContent = errText(e.message); } finally { go.disabled = false; }
  };
  go.addEventListener('click', submit);
  pass.i.addEventListener('keydown', (e) => { if (e.key === 'Enter') submit(); });
  const forgot = h('a', 'link-btn', w('forgot')); forgot.href = `https://wa.me/${WA}?text=${encodeURIComponent(`TapMaroc — ${CODE}: ${w('forgot')}`)}`; forgot.target = '_blank'; forgot.rel = 'noopener';
  card(h('h2', '', w('editTitle')), codeBadge(), h('p', 'acct-text', w('editSub')), pass.l, m, go, forgot);
}

function editView(cur, password) {
  const state = {type: cur.kind === 'card' ? 'card' : cur.link_type || 'website', value: cur.kind === 'link' ? cur.url : '', hasCard: Boolean(cur.slug)};
  const nowBox = h('div', 'tag-now');
  nowBox.append(h('small', '', w('now')), h('b', '', `${tname(cur.kind === 'card' ? 'card' : cur.link_type || 'website')}`));
  if (cur.kind === 'link' && cur.url) { const u = h('span', '', cur.url); u.dir = 'ltr'; nowBox.append(u); }
  nowBox.append(h('small', '', w('scans', {n: cur.scans ?? 0})));
  const np = field(w('newPass'), 'password', {autocomplete: 'new-password', dir: 'ltr'});
  const m = h('p', 'acct-msg');
  const save = btn('btn btn-red', w('save'));
  save.addEventListener('click', async () => {
    if (np.i.value && np.i.value.length < 6) { m.textContent = w('weak'); return; }
    save.disabled = true; m.textContent = '';
    try {
      const r = await rpc('nfc_tag_update', {code: CODE, password, new_password: np.i.value || null, ...payload(state)});
      if (!r?.ok) { m.textContent = errText(r?.error || ''); return; }
      const pw = np.i.value || password;
      m.textContent = w('saved');
      const again = await rpc('nfc_tag_login', {code: CODE, password: pw});
      if (again?.ok) editView(again, pw);
    } catch (e) { m.textContent = errText(e.message); } finally { save.disabled = false; }
  });
  const extra = [];
  if (cur.slug) { const ed = btn('btn btn-ghost', w('openEditor')); ed.addEventListener('click', () => openEditor(cur.slug, password)); extra.push(ed); }
  card(h('h2', '', w('editTitle')), codeBadge(), nowBox, ...extra, typeForm(state), np.l, m, save);
}

function messageView(text) {
  const home = h('a', 'btn btn-ghost', w('home')); home.href = '/';
  card(h('div', 'acct-icon', 'ℹ️'), h('p', 'acct-text', text), home);
}

async function route() {
  if (!/^[A-Z0-9]{8}$/.test(CODE)) return messageView(w('unknown'));
  if (EDIT) return loginView();
  let r;
  try { r = await rpc('nfc_tag_resolve', {code: CODE}); } catch { return messageView(w('net')); }
  if (r.status === 'blank') return activateView();
  if (r.status === 'disabled') return messageView(w('disabled'));
  if (r.status !== 'active') return messageView(w('unknown'));
  if (r.kind === 'card' && r.slug) { location.replace(`/p/${r.slug}`); return; }
  if (r.kind === 'link' && r.url && /^https:\/\//.test(r.url)) { location.replace(r.url); return; }
  const own = h('a', 'btn btn-ghost', w('ownerEdit')); own.href = `/k/${CODE}?edit`;
  card(h('p', 'acct-text', w('notSet')), own);
}

function setLang(l) {
  lang = W[l] ? l : 'ar';
  document.documentElement.lang = lang; document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
  $$('.langs button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.lang === lang)));
  try { localStorage.setItem('tm_lang', lang); } catch { /* ignore */ }
}

async function start() {
  setLang(lang);
  $$('.langs button').forEach((b) => b.addEventListener('click', () => { setLang(b.dataset.lang); route(); }));
  try { CONFIG = await (await fetch('/config.json', {cache: 'no-store'})).json(); } catch { return messageView('config'); }
  route();
}
start();
