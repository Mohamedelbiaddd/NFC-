// Tiny translation helper for the public pages: Arabic, French, English.
// Italian strings are kept for a later European launch; add 'it' to LANGS to enable them.
const DICT = {
  ar: {
    noticeTitle: '⚠️ تنبيه من الإدارة', suspendedTitle: '⛔ الخدمة موقوفة مؤقتاً', suspendedText: 'تم إيقاف بطاقة الولاء ولوحة المحل مؤقتاً لعدم دفع الاشتراك الشهري الذي يغطي تكاليف الخادم. بعد الدفع تعود الخدمة فوراً وتبقى كل بيانات زبائنك محفوظة. تواصل مع المسؤول عنك.',
    location: '📍 موقع المحل', useLocation: '📍 استخدم موقعي الحالي (وأنت داخل المحل)', noLocation: 'لم يُحدَّد الموقع بعد', locationSet: 'تم تحديد الموقع، اضغط حفظ', noGeo: 'تعذّر تحديد الموقع، فعّل GPS واسمح للمتصفح', radius: 'نطاق التذكير بالأمتار (50 - 1000)', radiusNote: 'يستعمل لتذكير الزبائن القريبين من المحل عبر المحفظة. في Google Wallet تحدد جوجل المسافة الفعلية بنفسها.',
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
  fr: {
    noticeTitle: '⚠️ Message de l’administration', suspendedTitle: '⛔ Service suspendu temporairement', suspendedText: 'Votre carte de fidélité et votre tableau de bord sont suspendus car l’abonnement mensuel (frais du serveur) n’a pas été réglé. Le service reprend dès le paiement et tous vos clients restent enregistrés. Contactez votre responsable.',
    location: '📍 Emplacement du magasin', useLocation: '📍 Utiliser ma position (dans le magasin)', noLocation: 'Emplacement non défini', locationSet: 'Emplacement défini, appuyez sur Enregistrer', noGeo: 'Position introuvable : activez le GPS et autorisez le navigateur', radius: 'Rayon de rappel en mètres (50 - 1000)', radiusNote: 'Sert à rappeler le magasin aux clients proches via le wallet. Dans Google Wallet, Google choisit lui-même la distance réelle.',
    loading: 'Chargement…', unavailable: 'Ce magasin n’est pas disponible', unavailableText: 'Vérifiez le lien ou demandez au magasin.',
    network: 'Connexion impossible, vérifiez internet.', join: 'Rejoindre la carte de fidélité', joinText: 'Saisissez votre nom et votre téléphone une seule fois ; ensuite chaque visite est comptée automatiquement.',
    name: 'Nom', phone: 'Téléphone', joinBtn: 'Rejoindre', badName: 'Saisissez votre nom', badPhone: 'Numéro invalide',
    welcome: 'Bonjour', visits: 'visites', goalText: 'Après {n} visites vous recevez : {reward}', freeNext: '🎉 Votre prochaine visite est gratuite !',
    free: 'Gratuite', stamped: '✅ Visite enregistrée', stampedFree: '🎉 Cette visite est gratuite ! Une nouvelle carte commence',
    codeExpired: 'Le code a expiré. Scannez à nouveau le code sur l’écran du magasin.', tooSoon: 'Une visite a été enregistrée récemment ; la prochaine comptera plus tard.',
    scanHint: 'À chaque visite, scannez le code affiché sur l’écran du magasin.', coming: '🚶 J’arrive', comingSent: '✅ Le magasin sait que vous arrivez',
    addHome: '📲 Enregistrer la carte sur l’écran d’accueil', iosHelp: '1) Touchez Partager ⬆️ dans Safari\n2) Choisissez « Sur l’écran d’accueil »',
    androidHelp: '1) Ouvrez le menu du navigateur ⋮\n2) Choisissez « Ajouter à l’écran d’accueil » ou « Installer l’application »', ok: 'OK',
    gallery: 'Du magasin', call: 'Appeler', totalVisits: 'Visites au total', rewards: 'Cadeaux obtenus',
    shopLogin: 'Tableau de bord du magasin', password: 'Mot de passe', login: 'Connexion', wrongPass: 'Mot de passe incorrect', locked: 'Trop de tentatives, réessayez dans 15 minutes.',
    tabCode: 'Code', tabCustomers: 'Clients', tabSettings: 'Réglages', logout: 'Déconnexion',
    customers: 'clients', today: 'visites aujourd’hui', gifts: 'cadeaux', scanMe: 'Scannez pour enregistrer votre visite', refreshIn: 'Renouvelé dans {s} s',
    fullscreen: 'Plein écran', search: 'Rechercher nom ou téléphone', noCustomers: 'Aucun client pour l’instant. Demandez à un client de scanner le code.',
    comingBadge: 'Arrive', lastVisit: 'Dernière visite', never: '—', recent: 'Dernières visites', void: 'Annuler', voided: 'Annulée',
    voidConfirm: 'Annuler cette visite ?', shopName: 'Nom du magasin', address: 'Adresse', goal: 'Visites avant le cadeau', reward: 'Cadeau',
    banners: 'Photos publicitaires (5 max)', addImage: '+ Ajouter une photo', save: 'Enregistrer', saved: 'Enregistré ✓', saveError: 'Enregistrement impossible',
    uploadError: 'Échec de l’envoi', remove: 'Supprimer', sessionExpired: 'Session expirée, reconnectez-vous.', justNow: 'à l’instant',
    minutesAgo: 'il y a {n} min', hoursAgo: 'il y a {n} h', daysAgo: 'il y a {n} j', privacy: 'Confidentialité', terms: 'Conditions',
  },
  en: {
    noticeTitle: '⚠️ Notice from the management', suspendedTitle: '⛔ Service temporarily suspended', suspendedText: 'Your loyalty card and dashboard are paused because the monthly subscription (server costs) has not been paid. Service returns immediately after payment and all your customers are kept. Please contact your agent.',
    location: '📍 Shop location', useLocation: '📍 Use my current location (inside the shop)', noLocation: 'Location not set yet', locationSet: 'Location set, press Save', noGeo: 'Could not get location; turn on GPS and allow the browser', radius: 'Reminder radius in metres (50 - 1000)', radiusNote: 'Used to remind nearby customers through the wallet. In Google Wallet, Google decides the actual distance itself.',
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
    noticeTitle: '⚠️ Avviso dalla gestione', suspendedTitle: '⛔ Servizio sospeso temporaneamente', suspendedText: 'La carta fedeltà e il pannello sono sospesi perché l\'abbonamento mensile (costi del server) non è stato pagato. Dopo il pagamento il servizio torna subito attivo e tutti i tuoi clienti restano salvati. Contatta il tuo referente.',
    location: '📍 Posizione del negozio', useLocation: '📍 Usa la mia posizione (dentro il negozio)', noLocation: 'Posizione non impostata', locationSet: 'Posizione impostata, premi Salva', noGeo: 'Posizione non disponibile; attiva il GPS e consenti al browser', radius: 'Raggio promemoria in metri (50 - 1000)', radiusNote: 'Serve a ricordare il negozio ai clienti vicini tramite il wallet. In Google Wallet la distanza effettiva la decide Google.',
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

const LANGS = ['ar', 'fr', 'en'];
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
