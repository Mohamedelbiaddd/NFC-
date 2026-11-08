// Tiny translation helper for the public pages: Arabic, English, Italian.
const DICT = {
  ar: {
    loading: 'جارٍ التحميل…', unavailable: 'هذا المحل غير متاح', unavailableText: 'تأكد من الرابط أو اسأل صاحب المحل.',
    network: 'تعذّر الاتصال، تحقق من الإنترنت.', join: 'انضم لبطاقة الولاء', joinText: 'اكتب اسمك ورقم هاتفك مرة واحدة فقط، وبعدها تُحسب زياراتك تلقائياً.',
    name: 'الاسم', phone: 'رقم الهاتف', joinBtn: 'انضمام', badName: 'اكتب اسمك', badPhone: 'رقم الهاتف غير صحيح',
    welcome: 'مرحباً', visits: 'زيارات', goalText: 'بعد {n} زيارات تحصل على: {reward}', freeNext: '🎉 زيارتك القادمة مجانية!',
    free: 'مجانية', stamped: '✅ تم تسجيل زيارتك', stampedFree: '🎉 هذه الزيارة مجانية! بدأنا عداداً جديداً',
    codeExpired: 'الكود انتهى. امسح الكود من شاشة المحل مرة أخرى.', tooSoon: 'سُجّلت زيارتك مؤخراً، الزيارة التالية تُحسب لاحقاً.',
    scanHint: 'في كل زيارة امسح الكود الظاهر على شاشة المحل.', coming: '🚶 أنا قادم', comingSent: '✅ أخبرنا المحل أنك قادم',
    addHome: '📲 احفظ البطاقة على الشاشة الرئيسية', iosHelp: '1) اضغط زر المشاركة ⬆️ في Safari\n2) اختر «إضافة إلى الشاشة الرئيسية»',
    androidHelp: '1) اضغط قائمة المتصفح ⋮\n2) اختر «إضافة إلى الشاشة الرئيسية» أو «تثبيت التطبيق»', ok: 'حسناً',
    gallery: 'من المحل', call: 'اتصال', totalVisits: 'مجموع الزيارات', rewards: 'هدايا حصلت عليها',
    shopLogin: 'لوحة المحل', password: 'كلمة المرور', login: 'دخول', wrongPass: 'كلمة المرور غير صحيحة', locked: 'محاولات كثيرة، حاول بعد 15 دقيقة.',
    tabCode: 'الكود', tabCustomers: 'الزبائن', tabSettings: 'الإعدادات', logout: 'خروج',
    customers: 'زبائن', today: 'زيارات اليوم', gifts: 'هدايا', scanMe: 'امسح الكود لتسجيل زيارتك', refreshIn: 'يتجدد خلال {s} ث',
    fullscreen: 'ملء الشاشة', search: 'بحث بالاسم أو الهاتف', noCustomers: 'لا يوجد زبائن بعد. اطلب من زبونك مسح الكود.',
    comingBadge: 'قادم', lastVisit: 'آخر زيارة', never: '—', recent: 'آخر الزيارات', void: 'إلغاء', voided: 'ملغاة',
    voidConfirm: 'إلغاء هذه الزيارة؟', shopName: 'اسم المحل', address: 'العنوان', goal: 'عدد الزيارات قبل الهدية', reward: 'الهدية',
    banners: 'صور إعلانية (حتى 5)', addImage: '+ إضافة صورة', save: 'حفظ', saved: 'تم الحفظ ✓', saveError: 'تعذّر الحفظ',
    uploadError: 'تعذّر رفع الصورة', remove: 'حذف', sessionExpired: 'انتهت الجلسة، ادخل من جديد.', justNow: 'الآن',
    minutesAgo: 'قبل {n} د', hoursAgo: 'قبل {n} س', daysAgo: 'قبل {n} يوم', privacy: 'الخصوصية', terms: 'الشروط',
  },
  en: {
    loading: 'Loading…', unavailable: 'This shop is not available', unavailableText: 'Check the link or ask the shop.',
    network: 'Connection failed, check your internet.', join: 'Join the loyalty card', joinText: 'Enter your name and phone once; after that every visit is counted automatically.',
    name: 'Name', phone: 'Phone number', joinBtn: 'Join', badName: 'Enter your name', badPhone: 'Invalid phone number',
    welcome: 'Hello', visits: 'visits', goalText: 'After {n} visits you get: {reward}', freeNext: '🎉 Your next visit is free!',
    free: 'Free', stamped: '✅ Visit recorded', stampedFree: '🎉 This visit is free! A new card has started',
    codeExpired: 'The code expired. Scan the code on the shop screen again.', tooSoon: 'A visit was recorded recently; the next one counts later.',
    scanHint: 'At every visit, scan the code shown on the shop screen.', coming: '🚶 I’m coming', comingSent: '✅ The shop knows you are coming',
    addHome: '📲 Save the card to your home screen', iosHelp: '1) Tap Share ⬆️ in Safari\n2) Choose “Add to Home Screen”',
    androidHelp: '1) Open the browser menu ⋮\n2) Choose “Add to Home screen” or “Install app”', ok: 'OK',
    gallery: 'From the shop', call: 'Call', totalVisits: 'Total visits', rewards: 'Rewards earned',
    shopLogin: 'Shop dashboard', password: 'Password', login: 'Log in', wrongPass: 'Wrong password', locked: 'Too many attempts, try again in 15 minutes.',
    tabCode: 'Code', tabCustomers: 'Customers', tabSettings: 'Settings', logout: 'Log out',
    customers: 'customers', today: 'visits today', gifts: 'rewards', scanMe: 'Scan to record your visit', refreshIn: 'Refreshes in {s}s',
    fullscreen: 'Full screen', search: 'Search name or phone', noCustomers: 'No customers yet. Ask a customer to scan the code.',
    comingBadge: 'Coming', lastVisit: 'Last visit', never: '—', recent: 'Recent visits', void: 'Cancel', voided: 'Cancelled',
    voidConfirm: 'Cancel this visit?', shopName: 'Shop name', address: 'Address', goal: 'Visits before the reward', reward: 'Reward',
    banners: 'Promo pictures (up to 5)', addImage: '+ Add picture', save: 'Save', saved: 'Saved ✓', saveError: 'Could not save',
    uploadError: 'Upload failed', remove: 'Remove', sessionExpired: 'Session expired, please log in again.', justNow: 'just now',
    minutesAgo: '{n} min ago', hoursAgo: '{n} h ago', daysAgo: '{n} d ago', privacy: 'Privacy', terms: 'Terms',
  },
  it: {
    loading: 'Caricamento…', unavailable: 'Negozio non disponibile', unavailableText: 'Controlla il link o chiedi al negozio.',
    network: 'Connessione non riuscita, controlla internet.', join: 'Iscriviti alla carta fedeltà', joinText: 'Inserisci nome e telefono una sola volta; poi ogni visita viene contata da sola.',
    name: 'Nome', phone: 'Telefono', joinBtn: 'Iscriviti', badName: 'Inserisci il nome', badPhone: 'Numero non valido',
    welcome: 'Ciao', visits: 'visite', goalText: 'Dopo {n} visite ricevi: {reward}', freeNext: '🎉 La prossima visita è gratis!',
    free: 'Gratis', stamped: '✅ Visita registrata', stampedFree: '🎉 Questa visita è gratis! Nuova carta iniziata',
    codeExpired: 'Codice scaduto. Scansiona di nuovo il codice sullo schermo del negozio.', tooSoon: 'Una visita è stata registrata da poco; la prossima conterà più tardi.',
    scanHint: 'A ogni visita scansiona il codice sullo schermo del negozio.', coming: '🚶 Sto arrivando', comingSent: '✅ Il negozio sa che stai arrivando',
    addHome: '📲 Salva la carta nella schermata Home', iosHelp: '1) Tocca Condividi ⬆️ in Safari\n2) Scegli «Aggiungi alla schermata Home»',
    androidHelp: '1) Apri il menu del browser ⋮\n2) Scegli «Aggiungi a schermata Home» o «Installa app»', ok: 'OK',
    gallery: 'Dal negozio', call: 'Chiama', totalVisits: 'Visite totali', rewards: 'Premi ottenuti',
    shopLogin: 'Pannello negozio', password: 'Password', login: 'Entra', wrongPass: 'Password errata', locked: 'Troppi tentativi, riprova tra 15 minuti.',
    tabCode: 'Codice', tabCustomers: 'Clienti', tabSettings: 'Impostazioni', logout: 'Esci',
    customers: 'clienti', today: 'visite oggi', gifts: 'premi', scanMe: 'Scansiona per registrare la visita', refreshIn: 'Si rinnova tra {s}s',
    fullscreen: 'Schermo intero', search: 'Cerca nome o telefono', noCustomers: 'Nessun cliente. Chiedi a un cliente di scansionare il codice.',
    comingBadge: 'In arrivo', lastVisit: 'Ultima visita', never: '—', recent: 'Ultime visite', void: 'Annulla', voided: 'Annullata',
    voidConfirm: 'Annullare questa visita?', shopName: 'Nome negozio', address: 'Indirizzo', goal: 'Visite prima del premio', reward: 'Premio',
    banners: 'Foto promozionali (max 5)', addImage: '+ Aggiungi foto', save: 'Salva', saved: 'Salvato ✓', saveError: 'Salvataggio non riuscito',
    uploadError: 'Caricamento non riuscito', remove: 'Rimuovi', sessionExpired: 'Sessione scaduta, accedi di nuovo.', justNow: 'adesso',
    minutesAgo: '{n} min fa', hoursAgo: '{n} h fa', daysAgo: '{n} g fa', privacy: 'Privacy', terms: 'Termini',
  },
};

const LANGS = ['ar', 'en', 'it'];
function store(key, value) {
  try { if (value === undefined) return localStorage.getItem(key); localStorage.setItem(key, value); } catch { return null; }
  return null;
}

export let lang = (() => {
  const saved = store('nfc_lang');
  if (LANGS.includes(saved)) return saved;
  const nav = (navigator.language || 'ar').slice(0, 2).toLowerCase();
  return LANGS.includes(nav) ? nav : 'ar';
})();

export function t(key, vars = {}) {
  let text = DICT[lang]?.[key] ?? DICT.ar[key] ?? key;
  for (const [k, v] of Object.entries(vars)) text = text.replaceAll(`{${k}}`, String(v));
  return text;
}

export function applyLang() {
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
}

// Renders the AR · EN · IT switcher into `host`; `onChange` re-renders the page.
export function langSwitcher(host, onChange) {
  host.replaceChildren();
  for (const code of LANGS) {
    const b = document.createElement('button');
    b.type = 'button';
    b.textContent = code.toUpperCase();
    b.className = 'lang' + (code === lang ? ' active' : '');
    b.addEventListener('click', () => {
      lang = code;
      store('nfc_lang', code);
      applyLang();
      langSwitcher(host, onChange);
      onChange();
    });
    host.append(b);
  }
}

export function ago(iso) {
  if (!iso) return t('never');
  const diff = (Date.now() - new Date(iso).getTime()) / 60000;
  if (diff < 1) return t('justNow');
  if (diff < 60) return t('minutesAgo', {n: Math.floor(diff)});
  if (diff < 1440) return t('hoursAgo', {n: Math.floor(diff / 60)});
  return t('daysAgo', {n: Math.floor(diff / 1440)});
}
