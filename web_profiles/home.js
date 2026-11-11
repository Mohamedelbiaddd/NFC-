// TapMaroc landing page: language switch (ar / fr / en), live card designer
// with made-up Moroccan sample data, WhatsApp ordering and small UI touches.
// Static only: it talks to no database.

// Orders and questions arrive on this WhatsApp number (digits only).
const WHATSAPP = '393295586046';

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const h = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };

// ---------------------------------------------------------------- i18n
// Arabic lives in the HTML; French and English here, keyed by data-i.
const T = {
  fr: {
    skip: 'Aller au contenu',
    'nav.services': 'Services', 'nav.builder': 'Créer ma carte', 'nav.sectors': 'Secteurs', 'nav.soon': 'Bientôt', 'nav.pricing': 'Tarifs', 'nav.faq': 'FAQ',
    'cta.order': 'Commander',
    'hero.tag': 'Fait au Maroc, pour les commerces du Maroc',
    'hero.t1': 'Une seule touche…', 'hero.t2': 'et votre client vous reste fidèle.',
    'hero.lead': 'Cartes de visite intelligentes, cartes de fidélité digitales pour les commerces et file d’attente pour les barbiers — en NFC et QR code, enregistrées dans Google Wallet. Sans application pour le client, sans papier.',
    'hero.try': 'Créer ma carte maintenant', 'hero.more': 'Découvrir nos services',
    'hero.k1': 'Android et iPhone', 'hero.k2': 'Aucune appli pour le client', 'hero.k3': 'Modifiable à tout moment',
    'hero.f1': 'Nouveau tampon +1', 'hero.f2': 'Votre tour dans 2',
    's1.t': 'Choisissez le design', 's1.p': 'Parmi nos modèles ou aux couleurs et logo de votre commerce.',
    's2.t': 'On prépare et on programme', 's2.p': 'Nous créons votre page et programmons la carte ou l’autocollant, prêts à l’emploi.',
    's3.t': 'Une touche… c’est parti', 's3.p': 'Votre client approche son téléphone : votre page s’ouvre aussitôt.',
    'sv.eyebrow': 'Nos services', 'sv.title': 'Tout ce qu’il faut pour rester proche de vos clients', 'sv.sub': 'Simple pour le commerçant, encore plus simple pour son client.',
    'sv1.t': 'Carte de visite intelligente', 'sv1.p': 'Approchez la carte d’un téléphone et votre page s’affiche : appel, WhatsApp, localisation, réseaux sociaux et enregistrement du contact en un geste.',
    'sv2.t': 'Carte de fidélité digitale', 'sv2.p': 'Des tampons digitaux au lieu du carton : chaque visite = un tampon, la carte complète = un cadeau. Impossible de l’oublier à la maison.',
    'sv3.t': 'Dans Google Wallet', 'sv3.p': 'Le client garde sa carte dans le portefeuille de son téléphone et reçoit vos alertes et offres directement à l’écran.',
    'sv4.t': 'File d’attente et réservation', 'sv4.p': 'Pour barbiers et salons de beauté : le client prend son tour depuis son téléphone et on le prévient quand son tour approche.',
    'sv5.t': 'Autocollants NFC et QR code', 'sv5.p': 'Pour tables, vitrines, comptoirs et voitures — avec un QR code prêt à imprimer pour les téléphones sans NFC.',
    'sv6.t': 'Tableau de bord commerçant', 'sv6.p': 'Suivez vos clients et leurs visites, validez les cadeaux et modifiez votre page et vos photos vous-même.',
    'tr1.t': '🔒 Anti-fraude', 'tr1.p': 'Chaque cadeau est validé par le commerçant.',
    'tr2.t': '⚡ Rapide et léger', 'tr2.p': 'Des pages qui s’ouvrent en une seconde, même avec une connexion faible.',
    'tr3.t': '🌍 En trois langues', 'tr3.p': 'Arabe, français et anglais.',
    'b.eyebrow': 'Essayez vous-même', 'b.title': 'Créez votre carte et voyez-la en direct', 'b.sub': 'Changez le design, le nom et les couleurs et voyez le résultat sur le téléphone. Les noms et numéros sont fictifs.',
    'b.vcard': '💳 Carte de visite', 'b.loyalty': '🎁 Carte de fidélité', 'b.design': 'Choisissez le design',
    'b.name': 'Nom complet', 'b.job': 'Métier', 'b.phone': 'Téléphone', 'b.city': 'Ville',
    'b.sector': 'Type de commerce', 'b.shop': 'Nom du commerce', 'b.reward': 'Cadeau', 'b.stamps': 'Nombre de tampons', 'b.color': 'Couleur de la carte',
    'b.shuffle': '🎲 Autres noms', 'b.order': 'Commander ce design', 'b.note': '* Aperçu de démonstration — la vraie page s’ouvre d’une touche sur la carte.',
    'sc.eyebrow': 'Pour qui ?', 'sc.title': 'Pour chaque commerce et chaque métier',
    'so.eyebrow': 'Bientôt', 'so.title': 'Ce que nous préparons', 'so.badge': 'Bientôt',
    'so1.t': 'Menus et catalogues digitaux pour restaurants', 'so1.p': 'Un menu avec photos et prix qui s’ouvre d’une touche sur la table ou par QR code. Modifiez plats et prix en quelques secondes, sans réimprimer.',
    'so1.m1': 'Tajine de viande aux pruneaux', 'so1.m2': 'Couscous aux légumes', 'so1.m3': 'Thé à la menthe',
    'so2.t': 'Apple Wallet', 'so2.p': 'Les cartes de fidélité aussi dans le portefeuille de l’iPhone.',
    'so3.t': 'Paiement en ligne', 'so3.p': 'Commandez et payez directement sur le site.',
    'so4.t': 'Catalogues pour commerces', 'so4.p': 'Présentez vos produits et vos prix sur la page de votre commerce.',
    'pr.eyebrow': 'Commander', 'pr.title': 'Choisissez la formule qui vous convient', 'pr.sub': 'Contactez-nous et nous vous proposerons la meilleure solution pour votre commerce ou votre métier.',
    'pr.ask': 'Prix sur demande', 'pr.order': 'Commander', 'pr.best': 'La plus demandée',
    'p1.t': 'Carte de visite', 'p1.who': 'Pour professionnels, artisans et indépendants',
    'p1.f1': 'Carte NFC à votre design', 'p1.f2': 'Page digitale à votre nom', 'p1.f3': 'QR code à imprimer', 'p1.f4': 'Vous modifiez vos infos vous-même',
    'p2.t': 'Formule commerce', 'p2.who': 'Barbiers, cafés, boulangeries et tous les commerces',
    'p2.f1': 'Carte de fidélité digitale', 'p2.f2': 'Google Wallet et notifications', 'p2.f3': 'File d’attente et réservation', 'p2.f4': 'Autocollants NFC et QR', 'p2.f5': 'Tableau de bord complet',
    'p3.t': 'Formule entreprise', 'p3.who': 'Pour toute une équipe, avec une identité commune',
    'p3.f1': 'Cartes pour tous les employés', 'p3.f2': 'Design aux couleurs de l’entreprise', 'p3.f3': 'Gestion centralisée', 'p3.f4': 'Accompagnement et support',
    'pay.t': 'Moyens de paiement', 'pay.p': 'Les moyens de paiement seront bientôt ajoutés au site. Pour l’instant, commandez via WhatsApp et nous vous contactons pour confirmer la commande et le paiement.',
    'pay.m1': '💵 Paiement à la livraison', 'pay.m2': '🏦 Virement bancaire', 'pay.m3': '💳 Carte bancaire',
    'fq.eyebrow': 'Questions fréquentes', 'fq.title': 'Une question ?',
    q1: 'Le client doit-il installer une application ?', a1: 'Non. Il approche son téléphone de la carte ou scanne le QR code, et la page s’ouvre directement dans le navigateur.',
    q2: 'Ça marche avec tous les téléphones ?', a2: 'Avec la plupart des Android et iPhone récents via NFC, et avec tous les téléphones via le QR code.',
    q3: 'Puis-je modifier mes infos après l’impression ?', a3: 'Oui. La carte ne change pas, mais vous modifiez votre page quand vous voulez : photos, numéros, liens et couleurs.',
    q4: 'Comment fonctionne la carte de fidélité ?', a4: 'À chaque visite, le client reçoit un tampon sur sa carte digitale. Une fois complète, il reçoit son cadeau après validation du commerçant.',
    q5: 'Combien de temps pour préparer ma carte ?', a5: 'Après confirmation de la commande et du design, nous préparons votre page et votre carte rapidement et vous contactons pour la livraison.',
    'fin.t': 'Prêt à commencer ?', 'fin.p': 'Écrivez-nous et nous vous aidons à choisir le design et la formule.', 'fin.cta': '💬 Contactez-nous sur WhatsApp',
    'ft.privacy': 'Confidentialité', 'ft.terms': 'Conditions', 'ft.contact': 'Contact', 'ft.made': 'Fait avec amour au Maroc 🇲🇦',
  },
  en: {
    skip: 'Skip to content',
    'nav.services': 'Services', 'nav.builder': 'Design your card', 'nav.sectors': 'Sectors', 'nav.soon': 'Coming soon', 'nav.pricing': 'Pricing', 'nav.faq': 'FAQ',
    'cta.order': 'Order now',
    'hero.tag': 'Made in Morocco, for Moroccan businesses',
    'hero.t1': 'One tap…', 'hero.t2': 'and your customer stays yours.',
    'hero.lead': 'Smart business cards, digital loyalty cards for shops and queue booking for barbers — with NFC and QR code, saved in Google Wallet. No app for the customer, no paper.',
    'hero.try': 'Design your card now', 'hero.more': 'See what we do',
    'hero.k1': 'Android and iPhone', 'hero.k2': 'No app for customers', 'hero.k3': 'Edit anytime',
    'hero.f1': 'New stamp +1', 'hero.f2': 'Your turn in 2',
    's1.t': 'Pick a design', 's1.p': 'From our ready-made designs or in your shop’s colours and logo.',
    's2.t': 'We set it up', 's2.p': 'We build your page and program the card or sticker, ready to use.',
    's3.t': 'Tap… and go', 's3.p': 'Your customer holds their phone near the card and your page opens instantly.',
    'sv.eyebrow': 'What we do', 'sv.title': 'Everything your business needs to stay close to customers', 'sv.sub': 'Simple for the owner, even simpler for the customer.',
    'sv1.t': 'Smart business card', 'sv1.p': 'Tap the card on a phone and your page appears: call, WhatsApp, map location, social links and save-contact in one tap.',
    'sv2.t': 'Digital loyalty card', 'sv2.p': 'Digital stamps instead of paper cards: every visit earns a stamp, a full card earns a gift. Never forgotten at home.',
    'sv3.t': 'In Google Wallet', 'sv3.p': 'Customers keep their card in their phone wallet and get your alerts and offers right on the screen.',
    'sv4.t': 'Queue and booking', 'sv4.p': 'For barbers and beauty salons: customers take their turn from their phone and get notified when it’s close.',
    'sv5.t': 'NFC stickers and QR codes', 'sv5.p': 'For tables, windows, counters and cars — with a print-ready QR code for phones without NFC.',
    'sv6.t': 'Owner dashboard', 'sv6.p': 'Follow your customers and visits, approve rewards and edit your page and photos yourself.',
    'tr1.t': '🔒 Fraud-proof', 'tr1.p': 'Every reward is confirmed by the owner.',
    'tr2.t': '⚡ Fast and light', 'tr2.p': 'Pages open in a second, even on a weak connection.',
    'tr3.t': '🌍 Three languages', 'tr3.p': 'Arabic, French and English.',
    'b.eyebrow': 'Try it yourself', 'b.title': 'Design your card and see it live', 'b.sub': 'Change the design, name and colours and see the result on the phone. Names and numbers are just samples.',
    'b.vcard': '💳 Business card', 'b.loyalty': '🎁 Loyalty card', 'b.design': 'Pick a design',
    'b.name': 'Full name', 'b.job': 'Profession', 'b.phone': 'Phone', 'b.city': 'City',
    'b.sector': 'Type of shop', 'b.shop': 'Shop name', 'b.reward': 'Reward', 'b.stamps': 'Number of stamps', 'b.color': 'Card colour',
    'b.shuffle': '🎲 Other names', 'b.order': 'Order this design', 'b.note': '* Demo preview — the real page opens with a tap on the card.',
    'sc.eyebrow': 'Who is it for?', 'sc.title': 'For every shop and every trade',
    'so.eyebrow': 'Coming soon', 'so.title': 'What we’re building now', 'so.badge': 'Soon',
    'so1.t': 'Digital menus and catalogues for restaurants', 'so1.p': 'A menu with photos and prices that opens with a tap on the table or a QR code. Change dishes and prices in seconds, no reprinting.',
    'so1.m1': 'Beef tagine with prunes', 'so1.m2': 'Vegetable couscous', 'so1.m3': 'Mint tea',
    'so2.t': 'Apple Wallet', 'so2.p': 'Loyalty cards in the iPhone wallet too.',
    'so3.t': 'Online payment', 'so3.p': 'Order and pay directly on the website.',
    'so4.t': 'Shop catalogues', 'so4.p': 'Show your products and prices on your shop page.',
    'pr.eyebrow': 'Order now', 'pr.title': 'Choose the plan that fits you', 'pr.sub': 'Get in touch and we’ll suggest the best option for your business or trade.',
    'pr.ask': 'Price on request', 'pr.order': 'Order now', 'pr.best': 'Most popular',
    'p1.t': 'Business card', 'p1.who': 'For professionals, craftsmen and freelancers',
    'p1.f1': 'NFC card in your design', 'p1.f2': 'Digital page in your name', 'p1.f3': 'Print-ready QR code', 'p1.f4': 'Edit your details yourself',
    'p2.t': 'Shop plan', 'p2.who': 'For barbers, cafés, bakeries and all shops',
    'p2.f1': 'Digital loyalty card', 'p2.f2': 'Google Wallet and notifications', 'p2.f3': 'Queue and booking', 'p2.f4': 'NFC and QR stickers', 'p2.f5': 'Full dashboard',
    'p3.t': 'Business plan', 'p3.who': 'For a whole team with one identity',
    'p3.f1': 'Cards for every employee', 'p3.f2': 'Design in company colours', 'p3.f3': 'Central management', 'p3.f4': 'Guidance and support',
    'pay.t': 'Payment methods', 'pay.p': 'Payment methods will be added to the website soon. For now, order via WhatsApp and we’ll contact you to confirm the order and payment.',
    'pay.m1': '💵 Cash on delivery', 'pay.m2': '🏦 Bank transfer', 'pay.m3': '💳 Bank card',
    'fq.eyebrow': 'FAQ', 'fq.title': 'Got a question?',
    q1: 'Does the customer need to install an app?', a1: 'No. They hold their phone near the card or scan the QR code, and the page opens right in the browser.',
    q2: 'Does it work with every phone?', a2: 'With most recent Android phones and iPhones via NFC, and with every phone via the QR code.',
    q3: 'Can I change my details after printing?', a3: 'Yes. The card stays the same, but you edit your page whenever you like: photos, numbers, links and colours.',
    q4: 'How does the loyalty card work?', a4: 'Each visit adds a stamp to the customer’s digital card. When it’s full, they get their reward after the owner confirms it.',
    q5: 'How long does it take to prepare my card?', a5: 'Once the order and design are confirmed, we prepare your page and card quickly and contact you for delivery.',
    'fin.t': 'Ready to start?', 'fin.p': 'Message us and we’ll help you choose the right design and plan.', 'fin.cta': '💬 Chat with us on WhatsApp',
    'ft.privacy': 'Privacy', 'ft.terms': 'Terms', 'ft.contact': 'Contact', 'ft.made': 'Made with love in Morocco 🇲🇦',
  },
};
const AR = {};
$$('[data-i]').forEach((e) => { AR[e.dataset.i] = e.textContent; });
const SOON = {ar: 'قريباً', fr: 'Bientôt', en: 'Soon'};
let lang = 'ar';
const t = (k) => (lang === 'ar' ? AR[k] : T[lang][k]) ?? AR[k] ?? k;
const pick = (o) => o?.[lang] ?? o?.ar ?? '';

// ---------------------------------------------------------------- sample data
// Made-up Moroccan people and numbers, only for the live preview.
const PEOPLE = [
  {ar: 'يوسف العلوي', fr: 'Youssef Alaoui', en: 'Youssef Alaoui'},
  {ar: 'سلمى بناني', fr: 'Salma Bennani', en: 'Salma Bennani'},
  {ar: 'حمزة التازي', fr: 'Hamza Tazi', en: 'Hamza Tazi'},
  {ar: 'خديجة الإدريسي', fr: 'Khadija Idrissi', en: 'Khadija Idrissi'},
  {ar: 'أمين الفاسي', fr: 'Amine El Fassi', en: 'Amine El Fassi'},
  {ar: 'نادية الشرقاوي', fr: 'Nadia Cherkaoui', en: 'Nadia Cherkaoui'},
  {ar: 'عمر برادة', fr: 'Omar Berrada', en: 'Omar Berrada'},
  {ar: 'إيمان الصقلي', fr: 'Imane Squalli', en: 'Imane Squalli'},
];
const CITIES = [
  {ar: 'الدار البيضاء', fr: 'Casablanca', en: 'Casablanca'},
  {ar: 'الرباط', fr: 'Rabat', en: 'Rabat'},
  {ar: 'مراكش', fr: 'Marrakech', en: 'Marrakesh'},
  {ar: 'فاس', fr: 'Fès', en: 'Fez'},
  {ar: 'طنجة', fr: 'Tanger', en: 'Tangier'},
  {ar: 'أكادير', fr: 'Agadir', en: 'Agadir'},
];
const fakePhone = () => `+212 6 ${String(10 + Math.floor(Math.random() * 89))} ${String(10 + Math.floor(Math.random() * 89))} ${String(10 + Math.floor(Math.random() * 89))} ${String(10 + Math.floor(Math.random() * 89))}`;

const SHOP_TYPES = [
  {id: 'barber', e: '✂️', name: {ar: 'حلاق', fr: 'Barbier', en: 'Barber'}, shop: {ar: 'صالون الأناقة', fr: 'Salon Élégance', en: 'Elegance Barber'}, reward: {ar: 'حلاقة مجانية', fr: 'Une coupe offerte', en: 'A free haircut'}, turn: true},
  {id: 'cafe', e: '☕', name: {ar: 'مقهى', fr: 'Café', en: 'Café'}, shop: {ar: 'مقهى الأطلس', fr: 'Café Atlas', en: 'Atlas Café'}, reward: {ar: 'قهوة مجانية', fr: 'Un café offert', en: 'A free coffee'}},
  {id: 'bakery', e: '🥐', name: {ar: 'مخبزة وحلويات', fr: 'Boulangerie', en: 'Bakery'}, shop: {ar: 'مخبزة السعادة', fr: 'Boulangerie Saâda', en: 'Saada Bakery'}, reward: {ar: 'علبة حلويات مجانية', fr: 'Une boîte de pâtisseries', en: 'A free box of pastries'}},
  {id: 'carwash', e: '🚗', name: {ar: 'غسل السيارات', fr: 'Lavage auto', en: 'Car wash'}, shop: {ar: 'لافاج النجمة', fr: 'Lavage Najma', en: 'Najma Car Wash'}, reward: {ar: 'غسلة كاملة مجانية', fr: 'Un lavage complet offert', en: 'A free full wash'}},
  {id: 'beauty', e: '💅', name: {ar: 'صالون تجميل', fr: 'Institut de beauté', en: 'Beauty salon'}, shop: {ar: 'صالون ياسمين', fr: 'Institut Yasmine', en: 'Yasmine Beauty'}, reward: {ar: 'جلسة عناية مجانية', fr: 'Un soin offert', en: 'A free treatment'}, turn: true},
  {id: 'gym', e: '🏋️', name: {ar: 'قاعة رياضة', fr: 'Salle de sport', en: 'Gym'}, shop: {ar: 'نادي القوة', fr: 'Club Force', en: 'Force Gym'}, reward: {ar: 'أسبوع مجاني', fr: 'Une semaine offerte', en: 'A free week'}},
];
const COLORS = ['#c81e2c', '#138a45', '#1e3a8a', '#b7791f', '#6d28d9', '#1f2937', '#0e7490'];

const SECTORS = [
  {e: '✂️', n: {ar: 'الحلاقون', fr: 'Barbiers', en: 'Barbers'}, d: {ar: 'الدور، الحجز والولاء', fr: 'File, réservation, fidélité', en: 'Queue, booking, loyalty'}},
  {e: '💅', n: {ar: 'صالونات التجميل', fr: 'Instituts de beauté', en: 'Beauty salons'}, d: {ar: 'مواعيد وهدايا للزبونات', fr: 'Rendez-vous et cadeaux', en: 'Appointments and gifts'}},
  {e: '☕', n: {ar: 'المقاهي', fr: 'Cafés', en: 'Cafés'}, d: {ar: 'القهوة العاشرة مجانية', fr: 'Le 10e café offert', en: 'The 10th coffee is free'}},
  {e: '🥐', n: {ar: 'المخابز والحلويات', fr: 'Boulangeries', en: 'Bakeries'}, d: {ar: 'زبائن يعودون كل يوم', fr: 'Des clients chaque jour', en: 'Customers every day'}},
  {e: '🚗', n: {ar: 'غسل السيارات', fr: 'Lavage auto', en: 'Car wash'}, d: {ar: 'غسلات مجانية للأوفياء', fr: 'Lavages offerts', en: 'Free washes for regulars'}},
  {e: '🏋️', n: {ar: 'القاعات الرياضية', fr: 'Salles de sport', en: 'Gyms'}, d: {ar: 'متابعة الحضور والهدايا', fr: 'Présences et cadeaux', en: 'Attendance and rewards'}},
  {e: '🛠️', n: {ar: 'الحرفيون', fr: 'Artisans', en: 'Craftsmen'}, d: {ar: 'كهربائي، سباك، نجار، زليج…', fr: 'Électricien, plombier, zellige…', en: 'Electrician, plumber, zellige…'}},
  {e: '💼', n: {ar: 'المهن الحرة والشركات', fr: 'Professions et entreprises', en: 'Professionals and companies'}, d: {ar: 'بطاقات أعمال أنيقة', fr: 'Cartes de visite élégantes', en: 'Elegant business cards'}},
  {e: '🛍️', n: {ar: 'المحلات التجارية', fr: 'Boutiques', en: 'Shops'}, d: {ar: 'ولاء وعروض للزبائن', fr: 'Fidélité et offres', en: 'Loyalty and offers'}},
  {e: '🍽️', n: {ar: 'المطاعم', fr: 'Restaurants', en: 'Restaurants'}, d: {ar: 'القوائم الرقمية', fr: 'Menus digitaux', en: 'Digital menus'}, soon: true},
];

// ---------------------------------------------------------------- state
const state = {
  mode: 'vcard', design: 'barber', person: 0, city: 0, phone: '+212 6 61 24 58 37',
  name: null, job: null, cityText: null, phoneText: null, // user edits (null = sample)
  shopType: 'barber', shop: null, reward: null, stamps: 10, color: COLORS[0],
};
let DESIGNS = [];

// ---------------------------------------------------------------- previews
function shade(hex, k) {
  const n = parseInt(hex.slice(1), 16);
  const ch = (v) => Math.max(0, Math.min(255, Math.round(k >= 0 ? v + (255 - v) * k : v * (1 + k))));
  return `#${((1 << 24) | (ch((n >> 16) & 255) << 16) | (ch((n >> 8) & 255) << 8) | ch(n & 255)).toString(16).slice(1)}`;
}
const light = (hex) => { const n = parseInt(hex.slice(1), 16); return (0.299 * ((n >> 16) & 255) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255)) / 255 > 0.6; };

function vcardScreen(d, data) {
  const p = d?.palette ?? {surface: '#3e1720', text: '#fff', muted: '#e5c9c9', accent: '#f5ce87', button: '#5a2230', buttonText: '#fff'};
  const lt = light(p.surface);
  const root = h('div', `vc${d?.buttonStyle === 'pill' ? ' vc-shape-pill' : ''}`);
  root.style.cssText = `--vbg:${shade(p.surface, lt ? -0.04 : -0.3)};--vcard:${p.surface};--vtext:${p.text};--vmuted:${p.muted};--vaccent:${p.accent};--vink:${light(p.accent) ? '#111' : '#fff'};--vline:${lt ? '#0000001a' : '#ffffff1f'}`;
  const cover = h('div', 'vc-cover');
  if (d?.assets?.cover) cover.style.backgroundImage = `url(${d.assets.cover})`;
  else cover.style.background = `linear-gradient(135deg,${p.accent},${p.button})`;
  const ava = h('div', 'vc-ava', Array.from(data.name.trim())[0] ?? 'T');
  const name = h('h4', '', data.name);
  const job = h('p', 'job', data.job);
  const btns = h('div', 'row-btns');
  btns.append(h('span', '', lang === 'ar' ? 'تبادل الاتصال' : lang === 'fr' ? 'Échanger le contact' : 'Exchange contact'),
    h('span', '', lang === 'ar' ? 'حفظ الرقم' : lang === 'fr' ? 'Enregistrer' : 'Save contact'));
  const rows = h('div', 'rows');
  const row = (i, txt, ltr) => { const r = h('div'); const ic = h('i', '', i); const s = h('span', '', txt); if (ltr) s.dir = 'ltr'; r.append(ic, s); rows.append(r); };
  row('📞', data.phone, true);
  row('💬', 'WhatsApp', true);
  row('📍', data.city);
  row('✉️', `contact@${(PEOPLE[state.person].fr.split(' ').pop() || 'tap').toLowerCase()}.ma`, true);
  const soc = h('div', 'socials');
  ['f', 'in', '◎', '♪'].forEach((x) => soc.append(h('span', '', x)));
  root.append(cover, ava, name, job, btns, rows, soc);
  if (d?.assets?.footer) { const f = h('div', 'foot-orn'); f.style.backgroundImage = `url(${d.assets.footer})`; root.append(f); }
  return root;
}

function loyaltyScreen(data) {
  const type = SHOP_TYPES.find((x) => x.id === data.type) ?? SHOP_TYPES[0];
  const root = h('div', 'ly');
  root.style.setProperty('--lc', data.color);
  const card = h('div', 'ly-card');
  const head = h('div', 'ly-head');
  const logo = h('div', 'ly-logo', type.e);
  const tt = h('div'); tt.append(h('b', '', data.shop), h('small', '', data.city));
  head.append(logo, tt);
  const who = h('div', 'ly-name');
  who.append(document.createTextNode(lang === 'ar' ? 'بطاقة الزبون' : lang === 'fr' ? 'Carte client' : 'Customer card'), h('b', '', data.customer));
  const n = data.stamps, got = Math.max(1, Math.round(n * 0.6));
  const grid = h('div', 'stamps');
  grid.style.gridTemplateColumns = `repeat(${n > 10 ? 6 : 5},1fr)`;
  for (let i = 0; i < n; i++) grid.append(h('div', `stamp${i < got ? ' on' : ''}${i === n - 1 ? ' gift' : ''}`, i < got ? '★' : i === n - 1 ? '🎁' : ''));
  const bar = h('div', 'ly-bar'); const fill = h('i'); fill.style.width = `${(got / n) * 100}%`; bar.append(fill);
  const rw = h('div', 'ly-reward');
  rw.append(h('span', '', `🎁 ${data.reward}`), h('span', '', `${got}/${n}`));
  card.append(head, who, grid, bar, rw);
  const tile = h('div', 'ly-tile');
  const box = h('div');
  if (type.turn) {
    tile.append(h('span', 'big', '#3'));
    box.append(h('b', '', lang === 'ar' ? 'دورك قريب' : lang === 'fr' ? 'Votre tour approche' : 'Your turn is close'),
      h('small', '', lang === 'ar' ? 'سننبّهك قبل دورك' : lang === 'fr' ? 'On vous prévient avant' : 'We’ll notify you before'));
  } else {
    tile.append(h('span', 'big', `${n - got}`));
    box.append(h('b', '', lang === 'ar' ? 'زيارات متبقية للهدية' : lang === 'fr' ? 'visites avant le cadeau' : 'visits to your reward'),
      h('small', '', lang === 'ar' ? 'آخر زيارة: اليوم' : lang === 'fr' ? 'Dernière visite : aujourd’hui' : 'Last visit: today'));
  }
  tile.append(box);
  const wallet = h('div', 'ly-wallet', lang === 'ar' ? '＋ إضافة إلى Google Wallet' : lang === 'fr' ? '＋ Ajouter à Google Wallet' : '＋ Add to Google Wallet');
  root.append(card, tile, wallet);
  return root;
}

// ---------------------------------------------------------------- builder
const designById = (id) => DESIGNS.find((d) => d.id === id);
function vData() {
  const d = designById(state.design);
  return {
    name: state.name ?? pick(PEOPLE[state.person]),
    job: state.job ?? (pick(d?.sampleSubtitleI18n) || pick(d?.name) || ''),
    phone: state.phoneText ?? state.phone,
    city: state.cityText ?? pick(CITIES[state.city]),
  };
}
function lData() {
  const type = SHOP_TYPES.find((x) => x.id === state.shopType);
  return {
    type: state.shopType, color: state.color, stamps: state.stamps,
    shop: state.shop ?? pick(type.shop), reward: state.reward ?? pick(type.reward),
    city: pick(CITIES[state.city]), customer: pick(PEOPLE[state.person]),
  };
}
function syncInputs() {
  const v = vData(), l = lData();
  $('#vName').value = v.name; $('#vJob').value = v.job; $('#vPhone').value = v.phone; $('#vCity').value = v.city;
  $('#lShop').value = l.shop; $('#lReward').value = l.reward; $('#stOut').value = state.stamps;
}
function renderPreview() {
  const screen = $('#screen');
  screen.replaceChildren(state.mode === 'vcard' ? vcardScreen(designById(state.design), vData()) : loyaltyScreen(lData()));
  $$('.design').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.id === state.design)));
  $$('#sectorsPick .chip').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.id === state.shopType)));
  $$('#swatches button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.c === state.color)));
  $('#orderDesign').href = waLink(orderText());
}
function buildDesigns() {
  const box = $('#designs');
  box.replaceChildren();
  for (const d of DESIGNS) {
    const b = h('button', 'design'); b.type = 'button'; b.dataset.id = d.id; b.title = pick(d.name);
    if (d.assets?.cover) { const i = h('img'); i.src = d.assets.cover; i.alt = ''; i.loading = 'lazy'; b.append(i); }
    else { const s = h('span', 'sw', d.identity ?? '✦'); s.style.background = `linear-gradient(135deg,${d.palette.surface} 50%,${d.palette.accent} 50%)`; s.style.color = d.palette.text; b.append(s); }
    b.append(h('span', 'design-name', pick(d.name)));
    b.addEventListener('click', () => { state.design = d.id; state.job = null; syncInputs(); renderPreview(); });
    box.append(b);
  }
}
function buildShopTypes() {
  const box = $('#sectorsPick');
  box.replaceChildren();
  for (const s of SHOP_TYPES) {
    const b = h('button', 'chip', `${s.e} ${pick(s.name)}`); b.type = 'button'; b.dataset.id = s.id;
    b.addEventListener('click', () => { state.shopType = s.id; state.shop = null; state.reward = null; syncInputs(); renderPreview(); });
    box.append(b);
  }
}
function buildSwatches() {
  const box = $('#swatches');
  for (const c of COLORS) {
    const b = h('button'); b.type = 'button'; b.dataset.c = c; b.style.background = c; b.setAttribute('aria-label', c);
    b.addEventListener('click', () => { state.color = c; renderPreview(); });
    box.append(b);
  }
}
function setMode(m) {
  state.mode = m;
  $$('.seg button').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.mode === m)));
  $('#formVcard').hidden = m !== 'vcard';
  $('#formLoyalty').hidden = m !== 'loyalty';
  renderPreview();
}

// ---------------------------------------------------------------- WhatsApp
const waLink = (text) => `https://wa.me/${WHATSAPP}?text=${encodeURIComponent(text)}`;
function orderText() {
  if (state.mode === 'vcard') {
    const d = designById(state.design), v = vData();
    return lang === 'fr'
      ? `Bonjour TapMaroc 👋\nJe veux une carte de visite NFC.\nDesign : ${pick(d?.name)}\nNom : ${v.name}\nMétier : ${v.job}\nVille : ${v.city}`
      : lang === 'en'
        ? `Hello TapMaroc 👋\nI’d like an NFC business card.\nDesign: ${pick(d?.name)}\nName: ${v.name}\nProfession: ${v.job}\nCity: ${v.city}`
        : `مرحباً TapMaroc 👋\nأريد بطاقة أعمال NFC.\nالتصميم: ${pick(d?.name)}\nالاسم: ${v.name}\nالمهنة: ${v.job}\nالمدينة: ${v.city}`;
  }
  const l = lData(), type = SHOP_TYPES.find((x) => x.id === state.shopType);
  return lang === 'fr'
    ? `Bonjour TapMaroc 👋\nJe veux une carte de fidélité pour mon commerce.\nType : ${pick(type.name)}\nNom : ${l.shop}\nCadeau : ${l.reward} après ${l.stamps} tampons`
    : lang === 'en'
      ? `Hello TapMaroc 👋\nI’d like a loyalty card for my shop.\nType: ${pick(type.name)}\nName: ${l.shop}\nReward: ${l.reward} after ${l.stamps} stamps`
      : `مرحباً TapMaroc 👋\nأريد بطاقة ولاء لمحلي.\nالنوع: ${pick(type.name)}\nاسم المحل: ${l.shop}\nالهدية: ${l.reward} بعد ${l.stamps} طوابع`;
}
const PLAN_MSG = {
  p1: {ar: 'مرحباً TapMaroc 👋\nأريد طلب «بطاقة الأعمال».', fr: 'Bonjour TapMaroc 👋\nJe souhaite commander la « Carte de visite ».', en: 'Hello TapMaroc 👋\nI’d like to order the “Business card”.'},
  p2: {ar: 'مرحباً TapMaroc 👋\nأريد طلب «باقة المحل».', fr: 'Bonjour TapMaroc 👋\nJe souhaite commander la « Formule commerce ».', en: 'Hello TapMaroc 👋\nI’d like to order the “Shop plan”.'},
  p3: {ar: 'مرحباً TapMaroc 👋\nأريد طلب «باقة الشركات».', fr: 'Bonjour TapMaroc 👋\nJe souhaite commander la « Formule entreprise ».', en: 'Hello TapMaroc 👋\nI’d like to order the “Business plan”.'},
  contact: {ar: 'مرحباً TapMaroc 👋\nأريد معلومات عن خدماتكم.', fr: 'Bonjour TapMaroc 👋\nJe voudrais des informations sur vos services.', en: 'Hello TapMaroc 👋\nI’d like some information about your services.'},
};
const updateWaLinks = () => $$('a.wa').forEach((a) => { a.href = waLink(pick(PLAN_MSG[a.dataset.plan] ?? PLAN_MSG.contact)); });

// ---------------------------------------------------------------- sectors grid
function buildSectors() {
  const box = $('#sectorsGrid');
  box.replaceChildren();
  for (const s of SECTORS) {
    const c = h('div', 'sector reveal in');
    c.append(h('span', 'e', s.e), h('b', '', pick(s.n)), h('small', '', pick(s.d)));
    if (s.soon) c.append(h('span', 'soon-pill', SOON[lang]));
    box.append(c);
  }
}

// ---------------------------------------------------------------- hero phone
let heroTick = 0;
function renderHero() {
  const screen = $('#heroScreen');
  if (!screen) return;
  const barber = designById('barber');
  const show = heroTick % 2 === 0
    ? vcardScreen(barber, {name: pick(PEOPLE[0]), job: pick(barber?.sampleSubtitleI18n) || '', phone: '+212 6 61 24 58 37', city: pick(CITIES[0])})
    : loyaltyScreen({type: 'cafe', color: '#138a45', stamps: 10, shop: pick(SHOP_TYPES[1].shop), reward: pick(SHOP_TYPES[1].reward), city: pick(CITIES[2]), customer: pick(PEOPLE[1])});
  show.style.animation = 'fadeIn .6s ease';
  screen.replaceChildren(show);
}
const fade = document.createElement('style');
fade.textContent = '@keyframes fadeIn{from{opacity:0;transform:scale(.98)}to{opacity:1;transform:none}}';
document.head.append(fade);

// ---------------------------------------------------------------- language
function setLang(l) {
  lang = T[l] || l === 'ar' ? l : 'ar';
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
  $$('[data-i]').forEach((e) => { e.textContent = t(e.dataset.i); });
  $$('.langs button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.lang === lang)));
  $$('.pay-methods .off').forEach((e) => { e.dataset.soon = SOON[lang]; });
  document.title = lang === 'fr'
    ? 'TapMaroc — Cartes NFC intelligentes et cartes de fidélité au Maroc'
    : lang === 'en' ? 'TapMaroc — Smart NFC cards and loyalty cards in Morocco'
      : 'TapMaroc — بطاقات ذكية NFC وبطاقات ولاء للمحلات في المغرب';
  try { localStorage.setItem('tm_lang', lang); } catch { /* private mode */ }
  buildDesigns(); buildShopTypes(); buildSectors(); syncInputs(); renderPreview(); renderHero(); updateWaLinks();
}

// ---------------------------------------------------------------- wiring
function wire() {
  $$('.langs button').forEach((b) => b.addEventListener('click', () => setLang(b.dataset.lang)));
  $$('.seg button').forEach((b) => b.addEventListener('click', () => setMode(b.dataset.mode)));
  const bind = (id, key) => $(id).addEventListener('input', (e) => { state[key] = e.target.value; renderPreview(); });
  bind('#vName', 'name'); bind('#vJob', 'job'); bind('#vPhone', 'phoneText'); bind('#vCity', 'cityText');
  bind('#lShop', 'shop'); bind('#lReward', 'reward');
  $('#stMinus').addEventListener('click', () => { state.stamps = Math.max(5, state.stamps - 1); syncInputs(); renderPreview(); });
  $('#stPlus').addEventListener('click', () => { state.stamps = Math.min(12, state.stamps + 1); syncInputs(); renderPreview(); });
  $('#shuffle').addEventListener('click', () => {
    state.person = (state.person + 1 + Math.floor(Math.random() * (PEOPLE.length - 1))) % PEOPLE.length;
    state.city = (state.city + 1) % CITIES.length;
    state.phone = fakePhone();
    state.name = state.cityText = state.phoneText = null;
    syncInputs(); renderPreview();
  });
  const menu = $('#menu'), nav = $('#nav');
  menu.addEventListener('click', () => { const open = nav.classList.toggle('open'); menu.setAttribute('aria-expanded', String(open)); });
  $$('#nav a').forEach((a) => a.addEventListener('click', () => { nav.classList.remove('open'); menu.setAttribute('aria-expanded', 'false'); }));
  $('#year').textContent = new Date().getFullYear();

  const io = 'IntersectionObserver' in window
    ? new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }), {threshold: 0.12})
    : null;
  $$('.reveal').forEach((e) => (io ? io.observe(e) : e.classList.add('in')));

  if (!matchMedia('(prefers-reduced-motion: reduce)').matches) setInterval(() => { heroTick++; renderHero(); }, 4500);
}

async function start() {
  try {
    const r = await fetch('/card-themes.json');
    DESIGNS = r.ok ? (await r.json()).themes ?? [] : [];
  } catch { DESIGNS = []; }
  buildSwatches();
  wire();
  let saved = null;
  try { saved = localStorage.getItem('tm_lang'); } catch { /* ignore */ }
  const nav = (navigator.language || '').slice(0, 2);
  setLang(saved || (nav === 'fr' ? 'fr' : 'ar'));
}
start();
