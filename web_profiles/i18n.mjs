// Tiny translation helper for the public pages: Arabic, French, English.
// Italian strings are kept for a later European launch; add 'it' to LANGS to enable them.
const DICT = {
  ar: {
    arrived: "📍 وصلت · دوري", arrivedSent: "✅ أخبرنا المحل أنك وصلت", closedDefault: "المحل مغلق اليوم. نعود للعمل قريباً، شكراً لتفهمك 🙏", closedUntil: "مغلق حتى {d}", hours: "أوقات العمل", directions: "الاتجاهات على الخريطة", ownerAccess: "دخول صاحب المحل", forgot: "طلب كلمة مرور جديدة", forgotSent: "تم إرسال طلبك إلى المندوب الذي سجّل محلك، وسيعطيك كلمة مرور جديدة قريباً.", home: "الرئيسية", queue: "قائمة الانتظار المباشرة", queueEmpty: "لا أحد في الطريق الآن.\nعندما يضغط زبون «أنا قادم» أو «وصلت» يظهر هنا فوراً مع تنبيه صوتي.", done: "تم ✓", arrivedBadge: "وصل", week: "هذا الأسبوع", enableAlerts: "🔔 تفعيل التنبيه الصوتي", alertsOn: "🔔 التنبيه مفعّل", closedTitle: "إغلاق المحل وإعلام الزبائن", closedToday: "مغلق اليوم", closedTomorrow: "مغلق غداً", closedCustom: "تاريخ آخر", closedMsgLabel: "رسالة للزبائن (اختياري)", closedActive: "الزبائن يرون الآن: مغلق حتى {d}", reopen: "إلغاء الإغلاق", cardDesign: "تصميم بطاقة الولاء", cardBg: "صورة خلفية البطاقة (تظهر عند كل زبون)", changeBg: "اختيار صورة", removeBg: "إزالة الخلفية", security: "الأمان وكلمة المرور", oldPass: "كلمة المرور الحالية", newPass: "كلمة المرور الجديدة (6 أحرف على الأقل)", changePass: "تغيير كلمة المرور", passChanged: "تم تغيير كلمة المرور ✓", wrongOld: "كلمة المرور الحالية غير صحيحة", weakPass: "كلمة المرور قصيرة جداً", filterAll: "الكل", filterNear: "قريب من الهدية", filterReady: "الهدية جاهزة", filterQueue: "في الطريق", yourCard: "بطاقة الولاء", left: "باقي {n} للهدية", giftReady: "الهدية جاهزة 🎁", shopInfo: "معلومات المحل", loyaltyRules: "قواعد الولاء", newCustomer: "زبون جديد انضم", comingNotif: "{name} في الطريق إليك", arrivedNotif: "{name} وصل", closedBadge: "مغلق اليوم", openBadge: "مفتوح",
    goalNote: 'تغيير عدد الزيارات أو الهدية يُطبَّق على الزبائن الجدد فوراً. الزبائن الحاليون يكملون بالشرط الذي بدأوا به حتى يحصلوا على هديتهم، ثم تبدأ دورتهم الجديدة بالشرط الجديد.', oldRule: 'يكمل بالشرط القديم: {n} زيارات',
    noticeTitle: '⚠️ تنبيه من الإدارة', suspendedTitle: '⛔ الخدمة موقوفة مؤقتاً', suspendedText: 'تم إيقاف بطاقة الولاء ولوحة المحل مؤقتاً لعدم دفع الاشتراك الشهري الذي يغطي تكاليف الخادم. بعد الدفع تعود الخدمة فوراً وتبقى كل بيانات زبائنك محفوظة. تواصل مع المسؤول عنك.',
    location: '📍 موقع المحل', useLocation: '📍 استخدم موقعي الحالي (وأنت داخل المحل)', noLocation: 'لم يُحدَّد الموقع بعد', locationSet: 'تم تحديد الموقع، اضغط حفظ', noGeo: 'تعذّر تحديد الموقع، فعّل GPS واسمح للمتصفح', radius: 'نطاق التذكير بالأمتار (50 - 1000)', radiusNote: 'يستعمل لتذكير الزبائن القريبين من المحل عبر المحفظة. في Google Wallet تحدد جوجل المسافة الفعلية بنفسها.',
    loading: 'جارٍ التحميل…', unavailable: 'هذا المحل غير متاح', unavailableText: 'تأكد من الرابط أو اسأل صاحب المحل.',
    network: 'تعذّر الاتصال، تحقق من الإنترنت.', join: 'انضم لبطاقة الولاء', joinText: 'اكتب اسمك ورقم هاتفك مرة واحدة فقط، وبعدها تُحسب زياراتك تلقائياً.',
    name: 'الاسم', phone: 'رقم الهاتف', joinBtn: 'انضمام', badName: 'اكتب اسمك', badPhone: 'رقم الهاتف غير صحيح',
    welcome: 'مرحباً', visits: 'زيارات', goalText: 'بعد {n} زيارات تحصل على: {reward}', freeNext: '🎉 زيارتك القادمة مجانية!',
    free: 'مجانية', stamped: '✅ تم تسجيل زيارتك', stampedFree: '🎉 هذه الزيارة مجانية! بدأنا عداداً جديداً',
    codeExpired: 'الكود انتهى. امسح الكود من شاشة المحل مرة أخرى.', tooSoon: 'سُجّلت زيارتك مؤخراً، الزيارة التالية تُحسب لاحقاً.',
    scanHint: 'في كل زيارة امسح الكود الظاهر على شاشة المحل.', coming: '🚶 أنا قادم', comingSent: '✅ أخبرنا المحل أنك قادم',
    bizCard: 'بطاقة النشاط', linksApps: 'الروابط والتطبيقات', openLink: 'افتح الرابط', socialTitle: 'مواقع التواصل', pointsTitle: 'نقاط الولاء', freeBadge: 'مجاناً', pointsOf: '{n} من {g} نقاط', social_booking: 'حجز موعد', themeTitle: 'شكل الصفحة (الثيم)', themeNote: 'اختر شكلاً، وسيظهر في المعاينة فوراً. اضغط «حفظ» لاعتماده، ويمكنك تغييره متى شئت.', tagline: 'وصف قصير تحت الاسم (مثال: حلاق رجالي)', preview: 'معاينة صفحتي',
    logo: 'الشعار', cover: 'صورة الغلاف', linksTitle: 'الروابط والتواصل', linksNote: 'أضف إنستغرام، واتساب، تيك توك… تظهر كأزرار في صفحة محلك.', addLink: 'إضافة رابط', galleryNote: 'حتى 6 صور تظهر في صفحة محلك.', badEmail: 'البريد الإلكتروني غير صالح', badLink: 'أحد الروابط غير صالح',
    call: 'اتصال', emailLabel: 'البريد', programTitle: 'برنامج الولاء', programText: 'بعد {n} زيارات تحصل على: {r}', programHow: 'امسح الكود الظاهر عند المحل بكاميرا هاتفك لتبدأ بطاقتك.', social_whatsapp: 'واتساب', social_instagram: 'إنستغرام', social_tiktok: 'تيك توك', social_facebook: 'فيسبوك', social_snapchat: 'سناب', social_youtube: 'يوتيوب', social_website: 'الموقع', social_maps: 'الخريطة', social_phone: 'هاتف', social_email: 'البريد',
    openNow: 'مفتوح الآن', closedNow: 'مغلق الآن', dayOff: 'عطلة', weekNote: 'حدّد أيام العمل وأوقاتها، وأزل العلامة عن يوم العطلة.', copyMonday: 'نسخ أوقات الاثنين لكل الأيام',
    walletTitle: 'أضف بطاقتك إلى Google Wallet', walletText: 'تبقى بطاقة الولاء في محفظة هاتفك، وتتحدّث نقاطك تلقائياً مع كل زيارة.', later: 'لاحقاً',
    wallet: '💳 أضف إلى Google Wallet', walletSoon: 'خدمة Google Wallet ستتوفر قريباً', walletError: 'تعذّر إضافة البطاقة، حاول لاحقاً',
    addHome: '📲 احفظ البطاقة على الشاشة الرئيسية', iosHelp: '1) اضغط زر المشاركة ⬆️ في Safari\n2) اختر «إضافة إلى الشاشة الرئيسية»',
    androidHelp: '1) اضغط قائمة المتصفح ⋮\n2) اختر «إضافة إلى الشاشة الرئيسية» أو «تثبيت التطبيق»', ok: 'حسناً',
    gallery: 'من المحل', call: 'اتصال', totalVisits: 'مجموع الزيارات', rewards: 'هدايا حصلت عليها',
    shopLogin: 'لوحة المحل', password: 'كلمة المرور', login: 'دخول', wrongPass: 'كلمة المرور غير صحيحة', locked: 'تم إيقاف الدخول بعد 3 محاولات خاطئة. تواصل مع الشخص الذي أنشأ لك الحساب ليعطيك كلمة مرور جديدة، أو اضغط «طلب كلمة مرور جديدة».', triesLeft: 'كلمة المرور غير صحيحة. بقيت {n} محاولة قبل إيقاف الدخول.',
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
    arrived: "📍 Je suis arrivé", arrivedSent: "✅ Le magasin sait que vous êtes arrivé", closedDefault: "Le magasin est fermé aujourd’hui. Nous revenons très vite, merci de votre compréhension 🙏", closedUntil: "Fermé jusqu’au {d}", hours: "Horaires", directions: "Itinéraire sur la carte", ownerAccess: "Accès propriétaire", forgot: "Demander un nouveau mot de passe", forgotSent: "Votre demande a été envoyée à l’agent qui a inscrit votre magasin ; il vous donnera bientôt un nouveau mot de passe.", home: "Accueil", queue: "File d’attente en direct", queueEmpty: "Personne en route pour l’instant.\nQuand un client appuie sur « J’arrive » ou « Je suis arrivé », il apparaît ici avec une alerte sonore.", done: "Fait ✓", arrivedBadge: "Arrivé", week: "Cette semaine", enableAlerts: "🔔 Activer l’alerte sonore", alertsOn: "🔔 Alerte activée", closedTitle: "Fermer le magasin et prévenir les clients", closedToday: "Fermé aujourd’hui", closedTomorrow: "Fermé demain", closedCustom: "Autre date", closedMsgLabel: "Message aux clients (facultatif)", closedActive: "Les clients voient : fermé jusqu’au {d}", reopen: "Annuler la fermeture", cardDesign: "Design de la carte", cardBg: "Image de fond de la carte (visible par chaque client)", changeBg: "Choisir une image", removeBg: "Retirer le fond", security: "Sécurité et mot de passe", oldPass: "Mot de passe actuel", newPass: "Nouveau mot de passe (6 caractères min.)", changePass: "Changer le mot de passe", passChanged: "Mot de passe changé ✓", wrongOld: "Mot de passe actuel incorrect", weakPass: "Mot de passe trop court", filterAll: "Tous", filterNear: "Proches du cadeau", filterReady: "Cadeau prêt", filterQueue: "En route", yourCard: "Carte de fidélité", left: "Encore {n} avant le cadeau", giftReady: "Cadeau prêt 🎁", shopInfo: "Infos du magasin", loyaltyRules: "Règles de fidélité", newCustomer: "Nouveau client inscrit", comingNotif: "{name} est en route", arrivedNotif: "{name} est arrivé", closedBadge: "Fermé aujourd’hui", openBadge: "Ouvert",
    goalNote: 'Le nouveau nombre de visites ou cadeau s’applique tout de suite aux nouveaux clients. Les clients actuels terminent avec la règle de départ jusqu’à leur cadeau, puis leur nouveau cycle suit la nouvelle règle.', oldRule: 'Termine avec l’ancienne règle : {n} visites',
    noticeTitle: '⚠️ Message de l’administration', suspendedTitle: '⛔ Service suspendu temporairement', suspendedText: 'Votre carte de fidélité et votre tableau de bord sont suspendus car l’abonnement mensuel (frais du serveur) n’a pas été réglé. Le service reprend dès le paiement et tous vos clients restent enregistrés. Contactez votre responsable.',
    location: '📍 Emplacement du magasin', useLocation: '📍 Utiliser ma position (dans le magasin)', noLocation: 'Emplacement non défini', locationSet: 'Emplacement défini, appuyez sur Enregistrer', noGeo: 'Position introuvable : activez le GPS et autorisez le navigateur', radius: 'Rayon de rappel en mètres (50 - 1000)', radiusNote: 'Sert à rappeler le magasin aux clients proches via le wallet. Dans Google Wallet, Google choisit lui-même la distance réelle.',
    loading: 'Chargement…', unavailable: 'Ce magasin n’est pas disponible', unavailableText: 'Vérifiez le lien ou demandez au magasin.',
    network: 'Connexion impossible, vérifiez internet.', join: 'Rejoindre la carte de fidélité', joinText: 'Saisissez votre nom et votre téléphone une seule fois ; ensuite chaque visite est comptée automatiquement.',
    name: 'Nom', phone: 'Téléphone', joinBtn: 'Rejoindre', badName: 'Saisissez votre nom', badPhone: 'Numéro invalide',
    welcome: 'Bonjour', visits: 'visites', goalText: 'Après {n} visites vous recevez : {reward}', freeNext: '🎉 Votre prochaine visite est gratuite !',
    free: 'Gratuite', stamped: '✅ Visite enregistrée', stampedFree: '🎉 Cette visite est gratuite ! Une nouvelle carte commence',
    codeExpired: 'Le code a expiré. Scannez à nouveau le code sur l’écran du magasin.', tooSoon: 'Une visite a été enregistrée récemment ; la prochaine comptera plus tard.',
    scanHint: 'À chaque visite, scannez le code affiché sur l’écran du magasin.', coming: '🚶 J’arrive', comingSent: '✅ Le magasin sait que vous arrivez',
    bizCard: 'Carte de visite', linksApps: 'Liens et applis', openLink: 'Ouvrir', socialTitle: 'Réseaux sociaux', pointsTitle: 'Points fidélité', freeBadge: 'Offert', pointsOf: '{n} sur {g} points', social_booking: 'Prendre rendez-vous', themeTitle: 'Style de la page (thème)', themeNote: 'Choisissez un style, il s’affiche tout de suite. Touchez « Enregistrer » pour l’adopter ; changeable à tout moment.', tagline: 'Courte description sous le nom (ex. : Barbier homme)', preview: 'Voir ma page',
    logo: 'Logo', cover: 'Photo de couverture', linksTitle: 'Liens et contact', linksNote: 'Ajoutez Instagram, WhatsApp, TikTok… ils s’affichent en boutons sur votre page.', addLink: 'Ajouter un lien', galleryNote: 'Jusqu’à 6 photos affichées sur votre page.', badEmail: 'E-mail invalide', badLink: 'Un des liens est invalide',
    call: 'Appeler', emailLabel: 'E-mail', programTitle: 'Programme fidélité', programText: 'Après {n} visites, vous gagnez : {r}', programHow: 'Scannez le code affiché au magasin avec l’appareil photo pour commencer votre carte.', social_whatsapp: 'WhatsApp', social_instagram: 'Instagram', social_tiktok: 'TikTok', social_facebook: 'Facebook', social_snapchat: 'Snapchat', social_youtube: 'YouTube', social_website: 'Site web', social_maps: 'Plan', social_phone: 'Téléphone', social_email: 'E-mail',
    openNow: 'Ouvert maintenant', closedNow: 'Fermé maintenant', dayOff: 'Fermé', weekNote: 'Choisissez les jours et horaires d’ouverture ; décochez les jours de repos.', copyMonday: 'Copier lundi sur tous les jours',
    walletTitle: 'Ajoutez votre carte à Google Wallet', walletText: 'Votre carte reste dans le portefeuille du téléphone et vos points se mettent à jour à chaque visite.', later: 'Plus tard',
    wallet: '💳 Ajouter à Google Wallet', walletSoon: 'Google Wallet arrive bientôt', walletError: 'Impossible d’ajouter la carte, réessayez plus tard',
    addHome: '📲 Enregistrer la carte sur l’écran d’accueil', iosHelp: '1) Touchez Partager ⬆️ dans Safari\n2) Choisissez « Sur l’écran d’accueil »',
    androidHelp: '1) Ouvrez le menu du navigateur ⋮\n2) Choisissez « Ajouter à l’écran d’accueil » ou « Installer l’application »', ok: 'OK',
    gallery: 'Du magasin', call: 'Appeler', totalVisits: 'Visites au total', rewards: 'Cadeaux obtenus',
    shopLogin: 'Tableau de bord du magasin', password: 'Mot de passe', login: 'Connexion', wrongPass: 'Mot de passe incorrect', locked: 'Accès bloqué après 3 essais. Contactez la personne qui a créé votre compte pour un nouveau mot de passe, ou touchez « Demander un nouveau mot de passe ».', triesLeft: 'Mot de passe incorrect. Encore {n} essai(s) avant le blocage.',
    tabCode: 'Code', tabCustomers: 'Clients', tabSettings: 'Réglages', logout: 'Déconnexion',
    customers: 'clients', today: 'visites aujourd’hui', gifts: 'cadeaux', scanMe: 'Scannez pour enregistrer votre visite', refreshIn: 'Renouvelé dans {s} s',
    fullscreen: 'Plein écran', search: 'Rechercher nom ou téléphone', noCustomers: 'Aucun client pour l’instant. Demandez à un client de scanner le code.',
    comingBadge: 'En route', lastVisit: 'Dernière visite', never: '—', recent: 'Dernières visites', void: 'Annuler', voided: 'Annulée',
    voidConfirm: 'Annuler cette visite ?', shopName: 'Nom du magasin', address: 'Adresse', goal: 'Visites avant le cadeau', reward: 'Cadeau',
    banners: 'Photos publicitaires (5 max)', addImage: '+ Ajouter une photo', save: 'Enregistrer', saved: 'Enregistré ✓', saveError: 'Enregistrement impossible',
    uploadError: 'Échec de l’envoi', remove: 'Supprimer', sessionExpired: 'Session expirée, reconnectez-vous.', justNow: 'à l’instant',
    minutesAgo: 'il y a {n} min', hoursAgo: 'il y a {n} h', daysAgo: 'il y a {n} j', privacy: 'Confidentialité', terms: 'Conditions',
  },
  en: {
    arrived: "📍 I’ve arrived", arrivedSent: "✅ The shop knows you have arrived", closedDefault: "The shop is closed today. We’ll be back soon, thanks for understanding 🙏", closedUntil: "Closed until {d}", hours: "Opening hours", directions: "Directions on the map", ownerAccess: "Owner access", forgot: "Request a new password", forgotSent: "Your request was sent to the agent who registered your shop; they will give you a new password soon.", home: "Home", queue: "Live queue", queueEmpty: "Nobody on the way right now.\nWhen a customer taps “I’m coming” or “I’ve arrived” they appear here with a sound alert.", done: "Done ✓", arrivedBadge: "Arrived", week: "This week", enableAlerts: "🔔 Turn on sound alerts", alertsOn: "🔔 Alerts on", closedTitle: "Close the shop and tell customers", closedToday: "Closed today", closedTomorrow: "Closed tomorrow", closedCustom: "Other date", closedMsgLabel: "Message to customers (optional)", closedActive: "Customers now see: closed until {d}", reopen: "Cancel closing", cardDesign: "Loyalty card design", cardBg: "Card background picture (seen by every customer)", changeBg: "Choose picture", removeBg: "Remove background", security: "Security and password", oldPass: "Current password", newPass: "New password (at least 6 characters)", changePass: "Change password", passChanged: "Password changed ✓", wrongOld: "Current password is wrong", weakPass: "Password too short", filterAll: "All", filterNear: "Close to reward", filterReady: "Reward ready", filterQueue: "On the way", yourCard: "Loyalty card", left: "{n} more to the reward", giftReady: "Reward ready 🎁", shopInfo: "Shop details", loyaltyRules: "Loyalty rules", newCustomer: "New customer joined", comingNotif: "{name} is on the way", arrivedNotif: "{name} has arrived", closedBadge: "Closed today", openBadge: "Open",
    goalNote: 'A new visit count or reward applies to new customers right away. Current customers finish with the rule they started with until they get their reward; their next cycle then follows the new rule.', oldRule: 'Finishing on the old rule: {n} visits',
    noticeTitle: '⚠️ Notice from the management', suspendedTitle: '⛔ Service temporarily suspended', suspendedText: 'Your loyalty card and dashboard are paused because the monthly subscription (server costs) has not been paid. Service returns immediately after payment and all your customers are kept. Please contact your agent.',
    location: '📍 Shop location', useLocation: '📍 Use my current location (inside the shop)', noLocation: 'Location not set yet', locationSet: 'Location set, press Save', noGeo: 'Could not get location; turn on GPS and allow the browser', radius: 'Reminder radius in metres (50 - 1000)', radiusNote: 'Used to remind nearby customers through the wallet. In Google Wallet, Google decides the actual distance itself.',
    loading: 'Loading…', unavailable: 'This shop is not available', unavailableText: 'Check the link or ask the shop.',
    network: 'Connection failed, check your internet.', join: 'Join the loyalty card', joinText: 'Enter your name and phone once; after that every visit is counted automatically.',
    name: 'Name', phone: 'Phone number', joinBtn: 'Join', badName: 'Enter your name', badPhone: 'Invalid phone number',
    welcome: 'Hello', visits: 'visits', goalText: 'After {n} visits you get: {reward}', freeNext: '🎉 Your next visit is free!',
    free: 'Free', stamped: '✅ Visit recorded', stampedFree: '🎉 This visit is free! A new card has started',
    codeExpired: 'The code expired. Scan the code on the shop screen again.', tooSoon: 'A visit was recorded recently; the next one counts later.',
    scanHint: 'At every visit, scan the code shown on the shop screen.', coming: '🚶 I’m coming', comingSent: '✅ The shop knows you are coming',
    bizCard: 'Business card', linksApps: 'Links & apps', openLink: 'Open link', socialTitle: 'Social media', pointsTitle: 'Loyalty points', freeBadge: 'Free', pointsOf: '{n} of {g} points', social_booking: 'Book an appointment', themeTitle: 'Page style (theme)', themeNote: 'Pick a style and it shows straight away. Tap “Save” to keep it; change it whenever you like.', tagline: 'Short line under the name (e.g. Men’s barber)', preview: 'View my page',
    logo: 'Logo', cover: 'Cover picture', linksTitle: 'Links and contact', linksNote: 'Add Instagram, WhatsApp, TikTok… they appear as buttons on your page.', addLink: 'Add a link', galleryNote: 'Up to 6 photos shown on your page.', badEmail: 'Invalid e-mail', badLink: 'One of the links is invalid',
    call: 'Call', emailLabel: 'E-mail', programTitle: 'Loyalty programme', programText: 'After {n} visits you get: {r}', programHow: 'Scan the code shown at the shop with your phone camera to start your card.', social_whatsapp: 'WhatsApp', social_instagram: 'Instagram', social_tiktok: 'TikTok', social_facebook: 'Facebook', social_snapchat: 'Snapchat', social_youtube: 'YouTube', social_website: 'Website', social_maps: 'Map', social_phone: 'Phone', social_email: 'E-mail',
    openNow: 'Open now', closedNow: 'Closed now', dayOff: 'Closed', weekNote: 'Set your opening days and times; untick your days off.', copyMonday: 'Copy Monday to every day',
    walletTitle: 'Add your card to Google Wallet', walletText: 'Your loyalty card stays in your phone wallet and your points update with every visit.', later: 'Later',
    wallet: '💳 Add to Google Wallet', walletSoon: 'Google Wallet is coming soon', walletError: 'Could not add the card, try again later',
    addHome: '📲 Save the card to your home screen', iosHelp: '1) Tap Share ⬆️ in Safari\n2) Choose “Add to Home Screen”',
    androidHelp: '1) Open the browser menu ⋮\n2) Choose “Add to Home screen” or “Install app”', ok: 'OK',
    gallery: 'From the shop', call: 'Call', totalVisits: 'Total visits', rewards: 'Rewards earned',
    shopLogin: 'Shop dashboard', password: 'Password', login: 'Log in', wrongPass: 'Wrong password', locked: 'Access blocked after 3 wrong tries. Contact the person who created your account for a new password, or tap “Request a new password”.', triesLeft: 'Wrong password. {n} try(ies) left before access is blocked.',
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
    goalNote: 'Il nuovo numero di visite o premio vale subito per i nuovi clienti. I clienti attuali completano con la regola iniziale fino al premio, poi il nuovo ciclo segue la nuova regola.', oldRule: 'Completa con la vecchia regola: {n} visite',
    noticeTitle: '⚠️ Avviso dalla gestione', suspendedTitle: '⛔ Servizio sospeso temporaneamente', suspendedText: 'La carta fedeltà e il pannello sono sospesi perché l\'abbonamento mensile (costi del server) non è stato pagato. Dopo il pagamento il servizio torna subito attivo e tutti i tuoi clienti restano salvati. Contatta il tuo referente.',
    location: '📍 Posizione del negozio', useLocation: '📍 Usa la mia posizione (dentro il negozio)', noLocation: 'Posizione non impostata', locationSet: 'Posizione impostata, premi Salva', noGeo: 'Posizione non disponibile; attiva il GPS e consenti al browser', radius: 'Raggio promemoria in metri (50 - 1000)', radiusNote: 'Serve a ricordare il negozio ai clienti vicini tramite il wallet. In Google Wallet la distanza effettiva la decide Google.',
    loading: 'Caricamento…', unavailable: 'Negozio non disponibile', unavailableText: 'Controlla il link o chiedi al negozio.',
    network: 'Connessione non riuscita, controlla internet.', join: 'Iscriviti alla carta fedeltà', joinText: 'Inserisci nome e telefono una sola volta; poi ogni visita viene contata da sola.',
    name: 'Nome', phone: 'Telefono', joinBtn: 'Iscriviti', badName: 'Inserisci il nome', badPhone: 'Numero non valido',
    welcome: 'Ciao', visits: 'visite', goalText: 'Dopo {n} visite ricevi: {reward}', freeNext: '🎉 La prossima visita è gratis!',
    free: 'Gratis', stamped: '✅ Visita registrata', stampedFree: '🎉 Questa visita è gratis! Nuova carta iniziata',
    codeExpired: 'Codice scaduto. Scansiona di nuovo il codice sullo schermo del negozio.', tooSoon: 'Una visita è stata registrata da poco; la prossima conterà più tardi.',
    scanHint: 'A ogni visita scansiona il codice sullo schermo del negozio.', coming: '🚶 Sto arrivando', comingSent: '✅ Il negozio sa che stai arrivando',
    bizCard: 'Biglietto da visita', linksApps: 'Link e app', openLink: 'Apri', socialTitle: 'Social', pointsTitle: 'Punti fedeltà', freeBadge: 'Gratis', pointsOf: '{n} di {g} punti', social_booking: 'Prenota', themeTitle: 'Stile pagina', themeNote: 'Scegli uno stile e salva.', tagline: 'Breve descrizione', preview: 'Vedi la mia pagina',
    logo: 'Logo', cover: 'Copertina', linksTitle: 'Link e contatti', linksNote: 'Aggiungi Instagram, WhatsApp, TikTok…', addLink: 'Aggiungi link', galleryNote: 'Fino a 6 foto.', badEmail: 'E-mail non valida', badLink: 'Un link non è valido',
    call: 'Chiama', emailLabel: 'E-mail', programTitle: 'Programma fedeltà', programText: 'Dopo {n} visite ricevi: {r}', programHow: 'Inquadra il codice mostrato nel negozio per iniziare la tua carta.', social_whatsapp: 'WhatsApp', social_instagram: 'Instagram', social_tiktok: 'TikTok', social_facebook: 'Facebook', social_snapchat: 'Snapchat', social_youtube: 'YouTube', social_website: 'Sito', social_maps: 'Mappa', social_phone: 'Telefono', social_email: 'E-mail',
    openNow: 'Aperto ora', closedNow: 'Chiuso ora', dayOff: 'Chiuso', weekNote: 'Imposta giorni e orari di apertura; togli la spunta ai giorni di riposo.', copyMonday: 'Copia lunedì su tutti i giorni',
    walletTitle: 'Aggiungi la carta a Google Wallet', walletText: 'La carta resta nel portafoglio del telefono e i punti si aggiornano a ogni visita.', later: 'Più tardi',
    wallet: '💳 Aggiungi a Google Wallet', walletSoon: 'Google Wallet arriverà presto', walletError: 'Impossibile aggiungere la carta, riprova più tardi',
    addHome: '📲 Salva la carta nella schermata Home', iosHelp: '1) Tocca Condividi ⬆️ in Safari\n2) Scegli «Aggiungi alla schermata Home»',
    androidHelp: '1) Apri il menu del browser ⋮\n2) Scegli «Aggiungi a schermata Home» o «Installa app»', ok: 'OK',
    gallery: 'Dal negozio', call: 'Chiama', totalVisits: 'Visite totali', rewards: 'Premi ottenuti',
    shopLogin: 'Pannello negozio', password: 'Password', login: 'Entra', wrongPass: 'Password errata', locked: 'Accesso bloccato dopo 3 tentativi. Contatta chi ha creato il tuo account per una nuova password.', triesLeft: 'Password errata. Restano {n} tentativi.',
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
