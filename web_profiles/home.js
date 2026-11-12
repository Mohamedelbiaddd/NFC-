// TapMaroc landing page: language switch (ar / fr / en), live card designer
// with made-up sample data, WhatsApp ordering and small UI touches.
// Static only: it talks to no database.

// Orders and questions arrive on this WhatsApp number (digits only). The
// admin can change it (and every text) from the hidden editor: /#studio.
const DEFAULT_WHATSAPP = '393295586046';
let CONTENT = {};      // published overrides {ar:{key:text}, fr:{}, en:{}, settings:{}}
const DRAFT = {ar: {}, fr: {}, en: {}, it: {}}; // unsaved edits in the editor
let CONFIG = null;
const whatsapp = () => DRAFT.whatsapp ?? CONTENT.settings?.whatsapp ?? DEFAULT_WHATSAPP;

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const h = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };

// ---------------------------------------------------------------- i18n
// Arabic lives in the HTML; French and English here, keyed by data-i.
const T = {
  fr: {
    "hero.free": "Créer ma carte gratuitement", "cta.login": "Connexion", "cta.free": "Commencer gratuitement", "p0.t": "Carte digitale", "p0.who": "Pour tous, prête en une minute", "p0.price": "Gratuit", "p0.f1": "Page carte à votre nom avec lien unique", "p0.f2": "QR code à télécharger et imprimer", "p0.f3": "Photos, liens, réseaux et designs", "p0.f4": "Modifiable à tout moment", "p0.cta": "Créer mon compte gratuit",
    "nav.app": "L’application", "nav.agents": "Agents", "ap.eyebrow": "L’application TapMaroc", "ap.title": "Tout se fait depuis votre téléphone", "ap.sub": "Une seule application pour tout gérer : de la création du compte du café à la programmation de la carte NFC, sur place.", "ap1.t": "Ajoutez un commerce ou une carte de visite en une minute", "ap1.p": "Choisissez le secteur, le nom et le téléphone : la page est prête.", "ap2.t": "Programmez cartes et tags NFC depuis le téléphone", "ap2.p": "Approchez la carte du téléphone et le lien s’écrit directement, sans autre appareil.", "ap3.t": "QR code prêt à l’emploi", "ap3.p": "À imprimer sur les tables et vitrines, ou à partager sur WhatsApp.", "ap4.t": "Suivi des clients et des visites", "ap4.p": "Qui est venu, combien de tampons restent, qui attend son cadeau.", "ap5.t": "Abonnements et paiements", "ap5.p": "Enregistrez 1 mois, 3 mois ou un an, avec alerte avant l’échéance.", "ap6.t": "Messages et alertes", "ap6.p": "Envoyez un avis à un commerçant ou suspendez un service en un geste.", "am.r1": "Salon Élégance", "am.s1": "Payé jusqu’au 12/2026", "am.r2": "Café Atlas", "am.s2": "18 clients cette semaine", "am.r3": "Carte : Sarah Martin", "am.s3": "Carte de visite", "am.nfc": "Approchez la carte pour écrire…", "am.b1": "📡 NFC", "am.b2": "🔳 QR", "am.b3": "🔗 Lien", "ag.eyebrow": "Agents et équipes", "ag.title": "Devenez agent ou gérez votre équipe", "ag.sub": "Chacun se connecte avec son propre compte et ne voit que les commerces et cartes qu’il a inscrits.", "ag1.t": "Administration", "ag1.p": "Vous voyez tout le réseau, ajoutez, suspendez ou supprimez n’importe qui à tout moment et définissez ses droits.", "ag2.t": "Agent", "ag2.p": "Inscrit cafés, commerces et cartes de visite, suit ses clients et leurs abonnements, et peut créer son équipe.", "ag3.t": "Commercial / employé", "ag3.p": "Ajoute les comptes et programme les cartes sur le terrain, selon les droits que vous lui donnez.", "ag.k1": "Droits clairs : qui ajoute, qui gère, qui consulte seulement", "ag.k2": "Suspendre un compte ou un commerce, ou le supprimer définitivement", "ag.k3": "Réinitialiser le mot de passe d’un membre depuis le téléphone", "ag.k4": "Historique complet : qui a ajouté quoi, et quand", "ag.cta": "🤝 Devenir agent", "tri.t": "Essai gratuit sur votre commerce", "tri.p": "Inscrivez-vous sur le site, ajoutez votre commerce et testez la fidélité avec vos vrais clients et un tableau de bord complet pendant une durée limitée — avant de payer quoi que ce soit.", "tri.cta": "Prévenez-moi au lancement",
    skip: 'Aller au contenu',
    'nav.services': 'Services', 'nav.builder': 'Créer ma carte', 'nav.sectors': 'Secteurs', 'nav.soon': 'Bientôt', 'nav.pricing': 'Tarifs', 'nav.faq': 'FAQ',
    'cta.order': 'Commander',
    'hero.tag': 'Pour tous les commerces et professionnels, partout',
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
    'sv5.t': 'Tags NFC personnalisés et QR code', 'sv5.p': 'Pour tables, vitrines, comptoirs et voitures — avec un QR code prêt à imprimer pour les téléphones sans NFC.',
    'sv6.t': 'Tableau de bord commerçant', 'sv6.p': 'Suivez vos clients et leurs visites, validez les cadeaux et modifiez votre page et vos photos vous-même.',
    'tr1.t': '🔒 Anti-fraude', 'tr1.p': 'Chaque cadeau est validé par le commerçant.',
    'tr2.t': '⚡ Rapide et léger', 'tr2.p': 'Des pages qui s’ouvrent en une seconde, même avec une connexion faible.',
    'tr3.t': '🌍 En quatre langues', 'tr3.p': 'Arabe, français, anglais et italien.',
    'b.eyebrow': 'Essayez vous-même', 'b.title': 'Créez votre carte et voyez-la en direct', 'b.sub': 'Changez le design, le nom et les couleurs et voyez le résultat sur le téléphone. Les noms et numéros sont fictifs.',
    'b.vcard': '💳 Carte de visite', 'b.loyalty': '🎁 Carte de fidélité', 'b.design': 'Choisissez le design',
    'b.name': 'Nom complet', 'b.job': 'Métier', 'b.phone': 'Téléphone', 'b.city': 'Ville',
    'b.sector': 'Type de commerce', 'b.shop': 'Nom du commerce', 'b.reward': 'Cadeau', 'b.stamps': 'Nombre de tampons', 'b.color': 'Couleur de la carte',
    'b.shuffle': '🎲 Autres noms', 'b.order': 'Commander ce design', 'b.note': '* Aperçu de démonstration — la vraie page s’ouvre d’une touche sur la carte.',
    'sc.eyebrow': 'Pour qui ?', 'sc.title': 'Pour chaque commerce et chaque métier',
    'so.eyebrow': 'Bientôt', 'so.title': 'Ce que nous préparons', 'so.badge': 'Bientôt',
    'so1.t': 'Menus et catalogues digitaux pour restaurants', 'so1.p': 'Un menu avec photos et prix qui s’ouvre d’une touche sur la table ou par QR code. Modifiez plats et prix en quelques secondes, sans réimprimer.',
    'so1.m1': 'Pizza margherita', 'so1.m2': 'Tajine aux légumes', 'so1.m3': 'Cappuccino',
    'so2.t': 'Apple Wallet', 'so2.p': 'Les cartes de fidélité aussi dans le portefeuille de l’iPhone.',
    'so3.t': 'Paiement en ligne', 'so3.p': 'Commandez et payez directement sur le site.',
    'so4.t': 'Catalogues pour commerces', 'so4.p': 'Présentez vos produits et vos prix sur la page de votre commerce.',
    'pr.eyebrow': 'Commander', 'pr.title': 'Choisissez la formule qui vous convient', 'pr.sub': 'Contactez-nous et nous vous proposerons la meilleure solution pour votre commerce ou votre métier.',
    'p1.price': 'Prix sur demande', 'p2.price': 'Prix sur demande', 'p3.price': 'Prix sur demande', 'pr.order': 'Commander', 'pr.best': 'La plus demandée',
    'p1.t': 'Carte NFC', 'p1.who': 'Pour professionnels, artisans et indépendants',
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
    q6: 'Où sont disponibles vos services ?', a6: 'Nous servons les commerces et professionnels au Maroc — Casablanca, Rabat, Marrakech, Tanger, Fès, Agadir et partout — et dans n’importe quel pays, car tout est digital et livré chez vous.',
    q5: 'Combien de temps pour préparer ma carte ?', a5: 'Après confirmation de la commande et du design, nous préparons votre page et votre carte rapidement et vous contactons pour la livraison.',
    'fin.t': 'Prêt à commencer ?', 'fin.p': 'Écrivez-nous et nous vous aidons à choisir le design et la formule.', 'fin.cta': '💬 Contactez-nous sur WhatsApp',
    'ft.privacy': 'Confidentialité', 'ft.terms': 'Conditions', 'ft.contact': 'Contact', 'ft.made': 'Des cartes intelligentes pour chaque commerce, partout 🌍',
  },
  en: {
    "hero.free": "Create your card for free", "cta.login": "Sign in", "cta.free": "Start free", "p0.t": "Digital card", "p0.who": "For everyone, ready in a minute", "p0.price": "Free", "p0.f1": "Card page in your name with your own link", "p0.f2": "QR code to download and print", "p0.f3": "Photos, links, socials and designs", "p0.f4": "Edit it yourself anytime", "p0.cta": "Create my free account",
    "nav.app": "The app", "nav.agents": "Agents", "ap.eyebrow": "The TapMaroc app", "ap.title": "All the work from your phone", "ap.sub": "One app to run everything: from creating the café’s account to programming the NFC card, right in the shop.", "ap1.t": "Add a shop or business card in a minute", "ap1.p": "Pick the sector, type the name and phone, and the page is ready.", "ap2.t": "Program NFC cards and tags from the phone", "ap2.p": "Hold the card to the phone and the link is written straight away, no other device needed.", "ap3.t": "Ready-made QR code", "ap3.p": "Print it on tables and windows, or share it on WhatsApp.", "ap4.t": "Customers and visits at a glance", "ap4.p": "Who came, how many stamps are left, who is waiting for a reward.", "ap5.t": "Subscriptions and payments", "ap5.p": "Record 1 month, 3 months or a year, with a reminder before it ends.", "ap6.t": "Messages and alerts", "ap6.p": "Send a notice to a shop owner or pause a service in one tap.", "am.r1": "Elegance Barber", "am.s1": "Paid until 12/2026", "am.r2": "Atlas Café", "am.s2": "18 customers this week", "am.r3": "Card: Sarah Martin", "am.s3": "Business card", "am.nfc": "Hold the card to write…", "am.b1": "📡 NFC", "am.b2": "🔳 QR", "am.b3": "🔗 Link", "ag.eyebrow": "Agents and teams", "ag.title": "Work with us as an agent, or run your team", "ag.sub": "Everyone signs in with their own account and only sees the shops and cards they registered.", "ag1.t": "Admin", "ag1.p": "You see the whole network, add, pause or remove anyone at any time, and set their permissions.", "ag2.t": "Agent", "ag2.p": "Registers cafés, shops and business cards, follows their customers and subscriptions, and can build a team.", "ag3.t": "Sales rep / staff", "ag3.p": "Adds accounts and programs cards in the field, within the permissions you give.", "ag.k1": "Clear permissions: who adds, who manages, who only views", "ag.k2": "Pause any account or shop, or delete it for good", "ag.k3": "Reset any member’s password from the phone", "ag.k4": "Full log: who added what, and when", "ag.cta": "🤝 Become an agent", "tri.t": "Free trial on your own shop", "tri.p": "Sign up on the website, add your shop and try the loyalty system with your real customers and a full dashboard for a limited time — before paying anything.", "tri.cta": "Tell me when it launches",
    skip: 'Skip to content',
    'nav.services': 'Services', 'nav.builder': 'Design your card', 'nav.sectors': 'Sectors', 'nav.soon': 'Coming soon', 'nav.pricing': 'Pricing', 'nav.faq': 'FAQ',
    'cta.order': 'Order now',
    'hero.tag': 'For every shop and professional, everywhere',
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
    'sv5.t': 'Custom NFC tags and QR codes', 'sv5.p': 'For tables, windows, counters and cars — with a print-ready QR code for phones without NFC.',
    'sv6.t': 'Owner dashboard', 'sv6.p': 'Follow your customers and visits, approve rewards and edit your page and photos yourself.',
    'tr1.t': '🔒 Fraud-proof', 'tr1.p': 'Every reward is confirmed by the owner.',
    'tr2.t': '⚡ Fast and light', 'tr2.p': 'Pages open in a second, even on a weak connection.',
    'tr3.t': '🌍 Four languages', 'tr3.p': 'Arabic, French, English and Italian.',
    'b.eyebrow': 'Try it yourself', 'b.title': 'Design your card and see it live', 'b.sub': 'Change the design, name and colours and see the result on the phone. Names and numbers are just samples.',
    'b.vcard': '💳 Business card', 'b.loyalty': '🎁 Loyalty card', 'b.design': 'Pick a design',
    'b.name': 'Full name', 'b.job': 'Profession', 'b.phone': 'Phone', 'b.city': 'City',
    'b.sector': 'Type of shop', 'b.shop': 'Shop name', 'b.reward': 'Reward', 'b.stamps': 'Number of stamps', 'b.color': 'Card colour',
    'b.shuffle': '🎲 Other names', 'b.order': 'Order this design', 'b.note': '* Demo preview — the real page opens with a tap on the card.',
    'sc.eyebrow': 'Who is it for?', 'sc.title': 'For every shop and every trade',
    'so.eyebrow': 'Coming soon', 'so.title': 'What we’re building now', 'so.badge': 'Soon',
    'so1.t': 'Digital menus and catalogues for restaurants', 'so1.p': 'A menu with photos and prices that opens with a tap on the table or a QR code. Change dishes and prices in seconds, no reprinting.',
    'so1.m1': 'Margherita pizza', 'so1.m2': 'Vegetable tagine', 'so1.m3': 'Cappuccino',
    'so2.t': 'Apple Wallet', 'so2.p': 'Loyalty cards in the iPhone wallet too.',
    'so3.t': 'Online payment', 'so3.p': 'Order and pay directly on the website.',
    'so4.t': 'Shop catalogues', 'so4.p': 'Show your products and prices on your shop page.',
    'pr.eyebrow': 'Order now', 'pr.title': 'Choose the plan that fits you', 'pr.sub': 'Get in touch and we’ll suggest the best option for your business or trade.',
    'p1.price': 'Price on request', 'p2.price': 'Price on request', 'p3.price': 'Price on request', 'pr.order': 'Order now', 'pr.best': 'Most popular',
    'p1.t': 'NFC card', 'p1.who': 'For professionals, craftsmen and freelancers',
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
    q6: 'Where are your services available?', a6: 'We serve shops and professionals in Morocco — Casablanca, Rabat, Marrakesh, Tangier, Fez, Agadir and everywhere — and in any country, since everything is digital and delivered to you.',
    q5: 'How long does it take to prepare my card?', a5: 'Once the order and design are confirmed, we prepare your page and card quickly and contact you for delivery.',
    'fin.t': 'Ready to start?', 'fin.p': 'Message us and we’ll help you choose the right design and plan.', 'fin.cta': '💬 Chat with us on WhatsApp',
    'ft.privacy': 'Privacy', 'ft.terms': 'Terms', 'ft.contact': 'Contact', 'ft.made': 'Smart cards for every business, everywhere 🌍',
  },
  it: {
    "hero.free": "Crea gratis il tuo biglietto", "cta.login": "Accedi", "cta.free": "Inizia gratis", "p0.t": "Biglietto digitale", "p0.who": "Per tutti, pronto in un minuto", "p0.price": "Gratis", "p0.f1": "Pagina a tuo nome con link personale", "p0.f2": "QR code da scaricare e stampare", "p0.f3": "Foto, link, social e design", "p0.f4": "Lo modifichi quando vuoi", "p0.cta": "Crea il mio account gratis",
    "nav.app": "L’app", "nav.agents": "Agenti", "ap.eyebrow": "L’app TapMaroc", "ap.title": "Tutto il lavoro dal tuo telefono", "ap.sub": "Un’unica app per gestire tutto: dalla creazione dell’account del bar alla programmazione della tessera NFC, direttamente in negozio.", "ap1.t": "Aggiungi un negozio o un biglietto da visita in un minuto", "ap1.p": "Scegli il settore, scrivi nome e telefono, e la pagina è pronta.", "ap2.t": "Programma tessere e tag NFC dal telefono", "ap2.p": "Avvicina la tessera al telefono e il link viene scritto subito, senza altri dispositivi.", "ap3.t": "QR code pronto", "ap3.p": "Da stampare su tavoli e vetrine, o da condividere su WhatsApp.", "ap4.t": "Clienti e visite sotto controllo", "ap4.p": "Chi è venuto, quanti timbri mancano, chi aspetta il premio.", "ap5.t": "Abbonamenti e pagamenti", "ap5.p": "Registra 1 mese, 3 mesi o un anno, con avviso prima della scadenza.", "ap6.t": "Messaggi e avvisi", "ap6.p": "Invia un avviso a un negoziante o sospendi un servizio con un tocco.", "am.r1": "Barberia Eleganza", "am.s1": "Pagato fino a 12/2026", "am.r2": "Caffè Atlas", "am.s2": "18 clienti questa settimana", "am.r3": "Tessera: Sarah Martin", "am.s3": "Biglietto da visita", "am.nfc": "Avvicina la tessera per scrivere…", "am.b1": "📡 NFC", "am.b2": "🔳 QR", "am.b3": "🔗 Link", "ag.eyebrow": "Agenti e team", "ag.title": "Lavora con noi come agente, o gestisci il tuo team", "ag.sub": "Ognuno entra con il proprio account e vede solo i negozi e le tessere che ha registrato.", "ag1.t": "Amministrazione", "ag1.p": "Vedi tutta la rete, aggiungi, sospendi o elimini chiunque in qualsiasi momento e ne decidi i permessi.", "ag2.t": "Agente", "ag2.p": "Registra bar, negozi e biglietti da visita, segue clienti e abbonamenti, e può creare il suo team.", "ag3.t": "Commerciale / dipendente", "ag3.p": "Aggiunge account e programma tessere sul campo, con i permessi che gli dai.", "ag.k1": "Permessi chiari: chi aggiunge, chi gestisce, chi vede soltanto", "ag.k2": "Sospendi un account o un negozio, o eliminalo definitivamente", "ag.k3": "Reimposta la password di un membro dal telefono", "ag.k4": "Registro completo: chi ha aggiunto cosa, e quando", "ag.cta": "🤝 Diventa agente", "tri.t": "Prova gratuita sul tuo negozio", "tri.p": "Registrati sul sito, aggiungi il tuo negozio e prova la fedeltà con i tuoi clienti veri e un pannello completo per un periodo limitato — prima di pagare qualsiasi cosa.", "tri.cta": "Avvisami al lancio",
    skip: 'Vai al contenuto',
    'nav.services': 'Servizi', 'nav.builder': 'Crea la tua tessera', 'nav.sectors': 'Settori', 'nav.soon': 'In arrivo', 'nav.pricing': 'Prezzi', 'nav.faq': 'FAQ',
    'cta.order': 'Ordina ora',
    'hero.tag': 'Per ogni negozio e professionista, ovunque',
    'hero.t1': 'Un solo tocco…', 'hero.t2': 'e il cliente resta tuo.',
    'hero.lead': 'Biglietti da visita smart, tessere fedeltà digitali per i negozi e coda prenotabile per i barbieri — con NFC e QR code, salvate in Google Wallet. Nessuna app per il cliente, niente carta.',
    'hero.try': 'Crea la tua tessera ora', 'hero.more': 'Scopri cosa facciamo',
    'hero.k1': 'Android e iPhone', 'hero.k2': 'Nessuna app per il cliente', 'hero.k3': 'Modificabile in ogni momento',
    'hero.f1': 'Nuovo timbro +1', 'hero.f2': 'Il tuo turno tra 2',
    's1.t': 'Scegli il design', 's1.p': 'Tra i nostri modelli o con i colori e il logo del tuo negozio.',
    's2.t': 'Prepariamo e programmiamo', 's2.p': 'Creiamo la tua pagina e programmiamo la tessera o l’adesivo, pronti all’uso.',
    's3.t': 'Un tocco… e via', 's3.p': 'Il cliente avvicina il telefono e la tua pagina si apre subito.',
    'sv.eyebrow': 'Cosa offriamo', 'sv.title': 'Tutto ciò che serve per restare vicino ai tuoi clienti', 'sv.sub': 'Semplice per il negoziante, ancora più semplice per il cliente.',
    'sv1.t': 'Biglietto da visita smart', 'sv1.p': 'Avvicina la tessera a un telefono e appare la tua pagina: chiamata, WhatsApp, posizione, social e salvataggio del contatto con un tocco.',
    'sv2.t': 'Tessera fedeltà digitale', 'sv2.p': 'Timbri digitali al posto del cartoncino: ogni visita un timbro, tessera completa = un regalo. Mai più dimenticata a casa.',
    'sv3.t': 'In Google Wallet', 'sv3.p': 'Il cliente tiene la tessera nel wallet del telefono e riceve avvisi e offerte direttamente sullo schermo.',
    'sv4.t': 'Coda e prenotazioni', 'sv4.p': 'Per barbieri e centri estetici: il cliente prende il turno dal telefono e viene avvisato quando tocca a lui.',
    'sv5.t': 'Tag NFC personalizzati e QR code', 'sv5.p': 'Per tavoli, vetrine, banconi e auto — con un QR code pronto da stampare per i telefoni senza NFC.',
    'sv6.t': 'Pannello per il negoziante', 'sv6.p': 'Segui clienti e visite, conferma i premi e modifica da solo la tua pagina e le foto.',
    'tr1.t': '🔒 Anti-frode', 'tr1.p': 'Ogni premio è confermato dal negoziante.',
    'tr2.t': '⚡ Veloce e leggero', 'tr2.p': 'Pagine che si aprono in un secondo, anche con connessione debole.',
    'tr3.t': '🌍 In quattro lingue', 'tr3.p': 'Arabo, francese, inglese e italiano.',
    'b.eyebrow': 'Provalo tu', 'b.title': 'Crea la tua tessera e guardala dal vivo', 'b.sub': 'Cambia design, nome e colori e guarda il risultato sul telefono. Nomi e numeri sono di esempio.',
    'b.vcard': '💳 Biglietto da visita', 'b.loyalty': '🎁 Tessera fedeltà', 'b.design': 'Scegli il design',
    'b.name': 'Nome completo', 'b.job': 'Professione', 'b.phone': 'Telefono', 'b.city': 'Città',
    'b.sector': 'Tipo di negozio', 'b.shop': 'Nome del negozio', 'b.reward': 'Premio', 'b.stamps': 'Numero di timbri', 'b.color': 'Colore della tessera',
    'b.shuffle': '🎲 Altri nomi', 'b.order': 'Ordina questo design', 'b.note': '* Anteprima dimostrativa — la pagina vera si apre toccando la tessera.',
    'sc.eyebrow': 'Per chi?', 'sc.title': 'Per ogni negozio e ogni mestiere',
    'so.eyebrow': 'In arrivo', 'so.title': 'A cosa stiamo lavorando', 'so.badge': 'Presto',
    'so1.t': 'Menu e cataloghi digitali per ristoranti', 'so1.p': 'Un menu con foto e prezzi che si apre con un tocco sul tavolo o con un QR code. Cambi piatti e prezzi in pochi secondi, senza ristampare.',
    'so1.m1': 'Pizza margherita', 'so1.m2': 'Tajine di verdure', 'so1.m3': 'Cappuccino',
    'so2.t': 'Apple Wallet', 'so2.p': 'Le tessere fedeltà anche nel wallet dell’iPhone.',
    'so3.t': 'Pagamento online', 'so3.p': 'Ordina e paga direttamente sul sito.',
    'so4.t': 'Cataloghi per negozi', 'so4.p': 'Mostra prodotti e prezzi sulla pagina del tuo negozio.',
    'pr.eyebrow': 'Ordina ora', 'pr.title': 'Scegli il pacchetto giusto per te', 'pr.sub': 'Contattaci e ti proporremo la soluzione migliore per il tuo negozio o mestiere.',
    'p1.price': 'Prezzo su richiesta', 'p2.price': 'Prezzo su richiesta', 'p3.price': 'Prezzo su richiesta', 'pr.order': 'Ordina ora', 'pr.best': 'Il più richiesto',
    'p1.t': 'Tessera NFC', 'p1.who': 'Per professionisti, artigiani e freelance',
    'p1.f1': 'Tessera NFC con il tuo design', 'p1.f2': 'Pagina digitale a tuo nome', 'p1.f3': 'QR code da stampare', 'p1.f4': 'Modifichi i tuoi dati da solo',
    'p2.t': 'Pacchetto negozio', 'p2.who': 'Per barbieri, bar, panetterie e tutti i negozi',
    'p2.f1': 'Tessera fedeltà digitale', 'p2.f2': 'Google Wallet e notifiche', 'p2.f3': 'Coda e prenotazioni', 'p2.f4': 'Adesivi NFC e QR per il negozio', 'p2.f5': 'Pannello completo',
    'p3.t': 'Pacchetto aziende', 'p3.who': 'Per un intero team con un’identità unica',
    'p3.f1': 'Tessere per tutti i dipendenti', 'p3.f2': 'Design con logo e colori aziendali', 'p3.f3': 'Gestione centralizzata', 'p3.f4': 'Assistenza e supporto',
    'pay.t': 'Metodi di pagamento', 'pay.p': 'I metodi di pagamento saranno presto aggiunti al sito. Per ora ordina su WhatsApp e ti contattiamo per confermare ordine e pagamento.',
    'pay.m1': '💵 Pagamento alla consegna', 'pay.m2': '🏦 Bonifico bancario', 'pay.m3': '💳 Carta bancaria',
    'fq.eyebrow': 'Domande frequenti', 'fq.title': 'Hai una domanda?',
    q1: 'Il cliente deve installare un’app?', a1: 'No. Avvicina il telefono alla tessera o scansiona il QR code, e la pagina si apre direttamente nel browser.',
    q2: 'Funziona con tutti i telefoni?', a2: 'Con la maggior parte degli Android e iPhone recenti tramite NFC, e con tutti i telefoni tramite QR code.',
    q3: 'Posso cambiare i miei dati dopo la stampa?', a3: 'Sì. La tessera resta la stessa, ma la tua pagina la modifichi quando vuoi: foto, numeri, link e colori.',
    q4: 'Come funziona la tessera fedeltà?', a4: 'A ogni visita il cliente riceve un timbro sulla tessera digitale. Quando è completa riceve il premio, dopo la conferma del negoziante.',
    q6: 'Dove sono disponibili i vostri servizi?', a6: 'Serviamo negozi e professionisti in Marocco — Casablanca, Rabat, Marrakech, Tangeri, Fès, Agadir e ovunque — e in qualsiasi paese, perché tutto è digitale e ti viene consegnato.',
    q5: 'Quanto tempo serve per preparare la mia tessera?', a5: 'Dopo la conferma dell’ordine e del design, prepariamo pagina e tessera in poco tempo e ti contattiamo per la consegna.',
    'fin.t': 'Pronto a iniziare?', 'fin.p': 'Scrivici e ti aiutiamo a scegliere design e pacchetto.', 'fin.cta': '💬 Scrivici su WhatsApp',
    'ft.privacy': 'Privacy', 'ft.terms': 'Termini', 'ft.contact': 'Contatti', 'ft.made': 'Tessere smart per ogni negozio, ovunque 🌍',
  },
};
const AR = {};
$$('[data-i]').forEach((e) => { AR[e.dataset.i] = e.textContent; });
const SOON = {ar: 'قريباً', fr: 'Bientôt', en: 'Soon', it: 'Presto'};
const AR_DESC = document.querySelector('meta[name=description]')?.content ?? '';
let lang = 'ar';
const base = (k, l = lang) => (l === 'ar' ? AR[k] : T[l][k]) ?? AR[k] ?? k;
const t = (k) => DRAFT[lang][k] ?? CONTENT[lang]?.[k] ?? base(k);
const pick = (o) => o?.[lang] ?? (lang === 'it' ? o?.en ?? o?.fr : undefined) ?? o?.ar ?? '';
const L = (ar, fr, en, it) => ({ar, fr, en, it})[lang] ?? en;

// ---------------------------------------------------------------- sample data
// Made-up people and numbers from around the world, only for the live preview.
const PEOPLE = [
  {ar: 'يوسف العلوي', fr: 'Youssef Alaoui', en: 'Youssef Alaoui'},
  {ar: 'سارة مارتان', fr: 'Sarah Martin', en: 'Sarah Martin'},
  {ar: 'عمر حداد', fr: 'Omar Haddad', en: 'Omar Haddad'},
  {ar: 'لينا روسي', fr: 'Lina Rossi', en: 'Lina Rossi'},
  {ar: 'دانيال كارتر', fr: 'Daniel Carter', en: 'Daniel Carter'},
  {ar: 'خديجة الإدريسي', fr: 'Khadija Idrissi', en: 'Khadija Idrissi'},
  {ar: 'كارلوس غارسيا', fr: 'Carlos García', en: 'Carlos García'},
  {ar: 'إيمان بن علي', fr: 'Imane Ben Ali', en: 'Imane Ben Ali'},
];
const CITIES = [
  {ar: 'الدار البيضاء', fr: 'Casablanca', en: 'Casablanca', cc: '+212 6'},
  {ar: 'باريس', fr: 'Paris', en: 'Paris', it: 'Parigi', cc: '+33 6'},
  {ar: 'دبي', fr: 'Dubaï', en: 'Dubai', it: 'Dubai', cc: '+971 50'},
  {ar: 'روما', fr: 'Rome', en: 'Rome', it: 'Roma', cc: '+39 3'},
  {ar: 'لندن', fr: 'Londres', en: 'London', it: 'Londra', cc: '+44 7'},
  {ar: 'مدريد', fr: 'Madrid', en: 'Madrid', cc: '+34 6'},
  {ar: 'مونتريال', fr: 'Montréal', en: 'Montreal', cc: '+1 514'},
];
const fakePhone = (cc = '+212 6') => `${cc} ${String(10 + Math.floor(Math.random() * 89))} ${String(10 + Math.floor(Math.random() * 89))} ${String(10 + Math.floor(Math.random() * 89))} ${String(10 + Math.floor(Math.random() * 89))}`;

const SHOP_TYPES = [
  {id: 'barber', e: '✂️', name: {ar: 'حلاق', fr: 'Barbier', en: 'Barber', it: 'Barbiere'}, shop: {ar: 'صالون الأناقة', fr: 'Salon Élégance', en: 'Elegance Barber', it: 'Barberia Eleganza'}, reward: {ar: 'حلاقة مجانية', fr: 'Une coupe offerte', en: 'A free haircut', it: 'Un taglio gratis'}, turn: true},
  {id: 'cafe', e: '☕', name: {ar: 'مقهى', fr: 'Café', en: 'Café', it: 'Bar'}, shop: {ar: 'مقهى الأطلس', fr: 'Café Atlas', en: 'Atlas Café', it: 'Caffè Atlas'}, reward: {ar: 'قهوة مجانية', fr: 'Un café offert', en: 'A free coffee', it: 'Un caffè gratis'}},
  {id: 'bakery', e: '🥐', name: {ar: 'مخبزة وحلويات', fr: 'Boulangerie', en: 'Bakery', it: 'Panetteria'}, shop: {ar: 'مخبزة السعادة', fr: 'Boulangerie Saâda', en: 'Saada Bakery', it: 'Panetteria Saada'}, reward: {ar: 'علبة حلويات مجانية', fr: 'Une boîte de pâtisseries', en: 'A free box of pastries', it: 'Una scatola di dolci gratis'}},
  {id: 'carwash', e: '🚗', name: {ar: 'غسل السيارات', fr: 'Lavage auto', en: 'Car wash', it: 'Autolavaggi'}, shop: {ar: 'لافاج النجمة', fr: 'Lavage Najma', en: 'Najma Car Wash', it: 'Autolavaggio Najma'}, reward: {ar: 'غسلة كاملة مجانية', fr: 'Un lavage complet offert', en: 'A free full wash', it: 'Un lavaggio completo gratis'}},
  {id: 'beauty', e: '💅', name: {ar: 'صالون تجميل', fr: 'Institut de beauté', en: 'Beauty salon', it: 'Centro estetico'}, shop: {ar: 'صالون ياسمين', fr: 'Institut Yasmine', en: 'Yasmine Beauty', it: 'Estetica Yasmine'}, reward: {ar: 'جلسة عناية مجانية', fr: 'Un soin offert', en: 'A free treatment', it: 'Un trattamento gratis'}, turn: true},
  {id: 'snack', e: '🍕', name: {ar: 'سناك / بيتزاريا', fr: 'Snack / Pizzeria', en: 'Snack / Pizzeria', it: 'Snack / Pizzeria'}, shop: {ar: 'بيتزا الريف', fr: 'Pizza Rif', en: 'Rif Pizza', it: 'Pizzeria Rif'}, reward: {ar: 'بيتزا مجانية', fr: 'Une pizza offerte', en: 'A free pizza', it: 'Una pizza gratis'}},
  {id: 'gym', e: '🏋️', name: {ar: 'قاعة رياضة', fr: 'Salle de sport', en: 'Gym', it: 'Palestra'}, shop: {ar: 'نادي القوة', fr: 'Club Force', en: 'Force Gym', it: 'Palestra Force'}, reward: {ar: 'أسبوع مجاني', fr: 'Une semaine offerte', en: 'A free week', it: 'Una settimana gratis'}},
];
const COLORS = ['#c81e2c', '#138a45', '#1e3a8a', '#b7791f', '#6d28d9', '#1f2937', '#0e7490'];

const SECTORS = [
  {e: '✂️', n: {ar: 'الحلاقون', fr: 'Barbiers', en: 'Barbers', it: 'Barbieri'}, d: {ar: 'الدور، الحجز والولاء', fr: 'File, réservation, fidélité', en: 'Queue, booking, loyalty', it: 'Coda, prenotazioni, fedeltà'}},
  {e: '💅', n: {ar: 'صالونات التجميل', fr: 'Instituts de beauté', en: 'Beauty salons', it: 'Centri estetici'}, d: {ar: 'مواعيد وهدايا للزبونات', fr: 'Rendez-vous et cadeaux', en: 'Appointments and gifts', it: 'Appuntamenti e regali'}},
  {e: '☕', n: {ar: 'المقاهي', fr: 'Cafés', en: 'Cafés', it: 'Bar e caffetterie'}, d: {ar: 'القهوة العاشرة مجانية', fr: 'Le 10e café offert', en: 'The 10th coffee is free', it: 'Il 10° caffè è gratis'}},
  {e: '🥐', n: {ar: 'المخابز والحلويات', fr: 'Boulangeries', en: 'Bakeries', it: 'Panetterie e pasticcerie'}, d: {ar: 'زبائن يعودون كل يوم', fr: 'Des clients chaque jour', en: 'Customers every day', it: 'Clienti ogni giorno'}},
  {e: '🚗', n: {ar: 'غسل السيارات', fr: 'Lavage auto', en: 'Car wash', it: 'Autolavaggi'}, d: {ar: 'غسلات مجانية للأوفياء', fr: 'Lavages offerts', en: 'Free washes for regulars', it: 'Lavaggi gratis ai clienti fedeli'}},
  {e: '🏋️', n: {ar: 'القاعات الرياضية', fr: 'Salles de sport', en: 'Gyms', it: 'Palestre'}, d: {ar: 'متابعة الحضور والهدايا', fr: 'Présences et cadeaux', en: 'Attendance and rewards', it: 'Presenze e premi'}},
  {e: '🛠️', n: {ar: 'الحرفيون', fr: 'Artisans', en: 'Craftsmen', it: 'Artigiani'}, d: {ar: 'كهربائي، سباك، نجار، دهّان…', fr: 'Électricien, plombier, peintre…', en: 'Electrician, plumber, painter…', it: 'Elettricista, idraulico, imbianchino…'}},
  {e: '💼', n: {ar: 'المهن الحرة والشركات', fr: 'Professions et entreprises', en: 'Professionals and companies', it: 'Professionisti e aziende'}, d: {ar: 'بطاقات أعمال أنيقة', fr: 'Cartes de visite élégantes', en: 'Elegant business cards', it: 'Biglietti da visita eleganti'}},
  {e: '🛍️', n: {ar: 'المحلات التجارية', fr: 'Boutiques', en: 'Shops', it: 'Negozi'}, d: {ar: 'ولاء وعروض للزبائن', fr: 'Fidélité et offres', en: 'Loyalty and offers', it: 'Fedeltà e offerte'}},
  {e: '🍽️', n: {ar: 'المطاعم', fr: 'Restaurants', en: 'Restaurants', it: 'Ristoranti'}, d: {ar: 'القوائم الرقمية', fr: 'Menus digitaux', en: 'Digital menus', it: 'Menu digitali'}, soon: true},
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
  btns.append(h('span', '', L('تبادل الاتصال', 'Échanger le contact', 'Exchange contact', 'Scambia contatto')),
    h('span', '', L('حفظ الرقم', 'Enregistrer', 'Save contact', 'Salva contatto')));
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
  who.append(document.createTextNode(L('بطاقة الزبون', 'Carte client', 'Customer card', 'Tessera cliente')), h('b', '', data.customer));
  const n = data.stamps, got = Math.max(1, Math.round(n * 0.6));
  const grid = h('div', 'stamps');
  grid.style.gridTemplateColumns = `repeat(${n > 10 ? 6 : 5},1fr)`;
  for (let i = 0; i < n; i++) grid.append(h('div', `stamp${i < got ? ' on' : ''}${i === n - 1 ? ' gift' : ''}`, i === n - 1 ? '🎁' : type.e));
  const bar = h('div', 'ly-bar'); const fill = h('i'); fill.style.width = `${(got / n) * 100}%`; bar.append(fill);
  const rw = h('div', 'ly-reward');
  rw.append(h('span', '', `🎁 ${data.reward}`), h('span', '', `${got}/${n}`));
  card.append(head, who, grid, bar, rw);
  const tile = h('div', 'ly-tile');
  const box = h('div');
  if (type.turn) {
    tile.append(h('span', 'big', '#3'));
    box.append(h('b', '', L('دورك قريب', 'Votre tour approche', 'Your turn is close', 'Il tuo turno è vicino')),
      h('small', '', L('سننبّهك قبل دورك', 'On vous prévient avant', 'We’ll notify you before', 'Ti avvisiamo prima')));
  } else {
    tile.append(h('span', 'big', `${n - got}`));
    box.append(h('b', '', L('زيارات متبقية للهدية', 'visites avant le cadeau', 'visits to your reward', 'visite al premio')),
      h('small', '', L('آخر زيارة: اليوم', 'Dernière visite : aujourd’hui', 'Last visit: today', 'Ultima visita: oggi')));
  }
  tile.append(box);
  const wallet = h('div', 'ly-wallet', L('＋ إضافة إلى Google Wallet', '＋ Ajouter à Google Wallet', '＋ Add to Google Wallet', '＋ Aggiungi a Google Wallet'));
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
const waLink = (text) => `https://wa.me/${whatsapp()}?text=${encodeURIComponent(text)}`;
function orderText() {
  if (state.mode === 'vcard') {
    const d = designById(state.design), v = vData();
    return lang === 'fr'
      ? `Bonjour TapMaroc 👋\nJe veux une carte de visite NFC.\nDesign : ${pick(d?.name)}\nNom : ${v.name}\nMétier : ${v.job}\nVille : ${v.city}`
      : lang === 'en'
        ? `Hello TapMaroc 👋\nI’d like an NFC business card.\nDesign: ${pick(d?.name)}\nName: ${v.name}\nProfession: ${v.job}\nCity: ${v.city}`
        : lang === 'it'
          ? `Ciao TapMaroc 👋\nVorrei un biglietto da visita NFC.\nDesign: ${pick(d?.name)}\nNome: ${v.name}\nProfessione: ${v.job}\nCittà: ${v.city}`
        : `مرحباً TapMaroc 👋\nأريد بطاقة أعمال NFC.\nالتصميم: ${pick(d?.name)}\nالاسم: ${v.name}\nالمهنة: ${v.job}\nالمدينة: ${v.city}`;
  }
  const l = lData(), type = SHOP_TYPES.find((x) => x.id === state.shopType);
  return lang === 'fr'
    ? `Bonjour TapMaroc 👋\nJe veux une carte de fidélité pour mon commerce.\nType : ${pick(type.name)}\nNom : ${l.shop}\nCadeau : ${l.reward} après ${l.stamps} tampons`
    : lang === 'en'
      ? `Hello TapMaroc 👋\nI’d like a loyalty card for my shop.\nType: ${pick(type.name)}\nName: ${l.shop}\nReward: ${l.reward} after ${l.stamps} stamps`
      : lang === 'it'
        ? `Ciao TapMaroc 👋\nVorrei una tessera fedeltà per il mio negozio.\nTipo: ${pick(type.name)}\nNome: ${l.shop}\nPremio: ${l.reward} dopo ${l.stamps} timbri`
      : `مرحباً TapMaroc 👋\nأريد بطاقة ولاء لمحلي.\nالنوع: ${pick(type.name)}\nاسم المحل: ${l.shop}\nالهدية: ${l.reward} بعد ${l.stamps} طوابع`;
}
const PLAN_MSG = {
  agent: {ar: 'مرحباً TapMaroc 👋\nأريد العمل معكم كوكيل.', fr: 'Bonjour TapMaroc 👋\nJe souhaite devenir agent.', en: 'Hello TapMaroc 👋\nI’d like to become an agent.', it: 'Ciao TapMaroc 👋\nVorrei diventare agente.'},
  trial: {ar: 'مرحباً TapMaroc 👋\nأريد تجربة مجانية لمحلّي عند الإطلاق.', fr: 'Bonjour TapMaroc 👋\nJe veux l’essai gratuit pour mon commerce dès le lancement.', en: 'Hello TapMaroc 👋\nI’d like the free trial for my shop when it launches.', it: 'Ciao TapMaroc 👋\nVorrei la prova gratuita per il mio negozio al lancio.'},
  p1: {ar: 'مرحباً TapMaroc 👋\nأريد طلب «بطاقة الأعمال».', fr: 'Bonjour TapMaroc 👋\nJe souhaite commander la « Carte de visite ».', en: 'Hello TapMaroc 👋\nI’d like to order the “Business card”.', it: 'Ciao TapMaroc 👋\nVorrei ordinare il « Biglietto da visita ».'},
  p2: {ar: 'مرحباً TapMaroc 👋\nأريد طلب «باقة المحل».', fr: 'Bonjour TapMaroc 👋\nJe souhaite commander la « Formule commerce ».', en: 'Hello TapMaroc 👋\nI’d like to order the “Shop plan”.', it: 'Ciao TapMaroc 👋\nVorrei ordinare il « Pacchetto negozio ».'},
  p3: {ar: 'مرحباً TapMaroc 👋\nأريد طلب «باقة الشركات».', fr: 'Bonjour TapMaroc 👋\nJe souhaite commander la « Formule entreprise ».', en: 'Hello TapMaroc 👋\nI’d like to order the “Business plan”.', it: 'Ciao TapMaroc 👋\nVorrei ordinare il « Pacchetto aziende ».'},
  contact: {ar: 'مرحباً TapMaroc 👋\nأريد معلومات عن خدماتكم.', fr: 'Bonjour TapMaroc 👋\nJe voudrais des informations sur vos services.', en: 'Hello TapMaroc 👋\nI’d like some information about your services.', it: 'Ciao TapMaroc 👋\nVorrei informazioni sui vostri servizi.'},
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
    ? 'TapMaroc — Carte de visite NFC & carte de fidélité digitale'
    : lang === 'en' ? 'TapMaroc — NFC business cards & digital loyalty cards'
    : lang === 'it' ? 'TapMaroc — Biglietti da visita NFC e tessere fedeltà digitali'
      : 'TapMaroc — بطاقات ذكية NFC وبطاقات ولاء لكل المحلات';
  try { localStorage.setItem('tm_lang', lang); } catch { /* private mode */ }
  // One address per language (/, /fr, /en) so search engines index each.
  const path = lang === 'ar' ? '/' : `/${lang}`;
  if (location.pathname !== path) history.replaceState(null, '', path + location.hash);
  $('link[rel=canonical]')?.setAttribute('href', `https://tapmaroc.com${path}`);
  const desc = {ar: AR_DESC, fr: 'Carte de visite NFC, carte de fidélité digitale avec Google Wallet et file d’attente pour barbiers, cafés et commerces. Au Maroc et partout. Sans application.', en: 'NFC business cards, digital loyalty cards with Google Wallet and queue booking for barbers, cafés and shops. In Morocco and worldwide. No app needed.', it: 'Biglietti da visita NFC, tessere fedeltà digitali con Google Wallet e coda prenotabile per barbieri, bar e negozi. In Marocco e nel mondo. Nessuna app.'}[lang];
  $('meta[name=description]')?.setAttribute('content', desc);
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
    state.phone = fakePhone(CITIES[state.city].cc);
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
  // E-mail confirmation / reset links may land here: hand them to the account page.
  if (/access_token=|error_description=/.test(location.hash)) { location.replace('/start' + location.hash); return; }
  const [designs, config] = await Promise.all([
    fetch('/card-themes.json').then((r) => (r.ok ? r.json() : {})).catch(() => ({})),
    fetch('/config.json', {cache: 'no-store'}).then((r) => (r.ok ? r.json() : null)).catch(() => null),
  ]);
  DESIGNS = designs.themes ?? [];
  CONFIG = config;
  CONTENT = await loadContent();
  buildSwatches();
  wire();
  let saved = null;
  try { saved = localStorage.getItem('tm_lang'); } catch { /* ignore */ }
  const nav = (navigator.language || '').slice(0, 2);
  const fromPath = /^\/(fr|en|it)\/?$/.exec(location.pathname)?.[1];
  setLang(fromPath || saved || (nav === 'fr' || nav === 'it' ? nav : 'ar'));
  initStudio();
}

// ---------------------------------------------------------------- content
async function loadContent() {
  if (!CONFIG?.supabaseUrl) return {};
  try {
    const r = await fetch(`${CONFIG.supabaseUrl}/rest/v1/rpc/nfc_site_content`, {
      method: 'POST', headers: {'Content-Type': 'application/json', apikey: CONFIG.publishableKey}, body: '{}', cache: 'no-store',
    });
    const doc = r.ok ? await r.json() : {};
    return doc && typeof doc === 'object' ? doc : {};
  } catch { return {}; }
}

// ---------------------------------------------------------------- studio
// Hidden editor for the site owner: open tapmaroc.com/#studio (or tap the
// © line 5 times), sign in with the admin account, then click any text on
// the page to change it, in each language. Only a super admin can save:
// the database checks it, the hidden address is just a convenience.
const SESSION_KEY = 'tm_studio';
const getSession = () => { try { const s = JSON.parse(sessionStorage.getItem(SESSION_KEY) || 'null'); return s && s.exp > Date.now() / 1000 + 30 ? s : null; } catch { return null; } };
const setSession = (s) => { try { s ? sessionStorage.setItem(SESSION_KEY, JSON.stringify(s)) : sessionStorage.removeItem(SESSION_KEY); } catch { /* ignore */ } };
const S = {
  ar: {title: 'دخول الإدارة', email: 'البريد الإلكتروني', pass: 'كلمة المرور', go: 'دخول', cancel: 'إلغاء', bad: 'البريد أو كلمة المرور غير صحيحة.', notAdmin: 'هذا الحساب ليس حساب إدارة.', net: 'تعذّر الاتصال. حاول مجدداً.',
    bar: '✏️ وضع التعديل — اضغط على أي نص لتغييره', lang: 'اللغة', wa: 'واتساب', save: 'حفظ ونشر', saved: '✓ تم الحفظ والنشر', discard: 'إلغاء التغييرات', exit: 'خروج', changes: 'تغييرات غير محفوظة', expired: 'انتهت الجلسة، سجّل الدخول مجدداً.', waBad: 'رقم واتساب غير صحيح (أرقام فقط مع رمز الدولة).', reset: 'استرجاع النص الأصلي لهذا العنصر'},
  fr: {title: 'Accès administrateur', email: 'E-mail', pass: 'Mot de passe', go: 'Connexion', cancel: 'Annuler', bad: 'E-mail ou mot de passe incorrect.', notAdmin: 'Ce compte n’est pas administrateur.', net: 'Connexion impossible. Réessayez.',
    bar: '✏️ Mode édition — cliquez sur un texte pour le modifier', lang: 'Langue', wa: 'WhatsApp', save: 'Enregistrer et publier', saved: '✓ Enregistré et publié', discard: 'Annuler les modifications', exit: 'Quitter', changes: 'modifications non enregistrées', expired: 'Session expirée, reconnectez-vous.', waBad: 'Numéro WhatsApp invalide (chiffres avec indicatif).', reset: 'Rétablir le texte d’origine'},
  it: {title: 'Accesso amministratore', email: 'E-mail', pass: 'Password', go: 'Accedi', cancel: 'Annulla', bad: 'E-mail o password errata.', notAdmin: 'Questo account non è amministratore.', net: 'Connessione non riuscita. Riprova.',
    bar: '✏️ Modalità modifica — tocca un testo per cambiarlo', lang: 'Lingua', wa: 'WhatsApp', save: 'Salva e pubblica', saved: '✓ Salvato e pubblicato', discard: 'Annulla modifiche', exit: 'Esci', changes: 'modifiche non salvate', expired: 'Sessione scaduta, accedi di nuovo.', waBad: 'Numero WhatsApp non valido (solo cifre con prefisso).', reset: 'Ripristina il testo originale'},
  en: {title: 'Admin sign-in', email: 'Email', pass: 'Password', go: 'Sign in', cancel: 'Cancel', bad: 'Wrong email or password.', notAdmin: 'This account is not an admin.', net: 'Connection failed. Try again.',
    bar: '✏️ Edit mode — click any text to change it', lang: 'Language', wa: 'WhatsApp', save: 'Save & publish', saved: '✓ Saved and published', discard: 'Discard changes', exit: 'Exit', changes: 'unsaved changes', expired: 'Session expired, sign in again.', waBad: 'Invalid WhatsApp number (digits with country code).', reset: 'Restore the original text'},
};
const s_ = (k) => S[lang][k];
let studioOn = false;

async function api(path, body, token) {
  const r = await fetch(`${CONFIG.supabaseUrl}${path}`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json', apikey: CONFIG.publishableKey, ...(token ? {Authorization: `Bearer ${token}`} : {})},
    body: JSON.stringify(body ?? {}), cache: 'no-store',
  });
  const data = await r.json().catch(() => null);
  return {ok: r.ok, status: r.status, data};
}

function loginDialog() {
  const dlg = h('dialog', 'studio-login');
  const f = h('form');
  f.method = 'dialog';
  const title = h('h3', '', s_('title'));
  const email = h('input'); email.type = 'email'; email.required = true; email.autocomplete = 'username'; email.placeholder = s_('email'); email.dir = 'ltr';
  const pass = h('input'); pass.type = 'password'; pass.required = true; pass.autocomplete = 'current-password'; pass.placeholder = s_('pass'); pass.dir = 'ltr';
  const msg = h('p', 'studio-msg');
  const row = h('div', 'studio-row');
  const go = h('button', 'btn btn-red btn-sm', s_('go')); go.type = 'submit';
  const cancel = h('button', 'btn btn-ghost btn-sm', s_('cancel')); cancel.type = 'button';
  row.append(go, cancel);
  f.append(title, email, pass, msg, row);
  dlg.append(f);
  document.body.append(dlg);
  cancel.addEventListener('click', () => { dlg.close(); dlg.remove(); history.replaceState(null, '', location.pathname); });
  f.addEventListener('submit', async (e) => {
    e.preventDefault();
    go.disabled = true; msg.textContent = '…';
    try {
      const auth = await api('/auth/v1/token?grant_type=password', {email: email.value.trim(), password: pass.value});
      if (!auth.ok || !auth.data?.access_token) { msg.textContent = s_('bad'); return; }
      const token = auth.data.access_token;
      const admin = await api('/rest/v1/rpc/nfc_site_is_admin', {}, token);
      if (admin.data !== true) { msg.textContent = s_('notAdmin'); return; }
      setSession({token, exp: Math.floor(Date.now() / 1000) + (auth.data.expires_in ?? 3600)});
      pass.value = '';
      dlg.close(); dlg.remove();
      enterStudio();
    } catch { msg.textContent = s_('net'); } finally { go.disabled = false; }
  });
  dlg.showModal();
  email.focus();
}

function markEditable() {
  $$('[data-i]').forEach((e) => {
    try { e.contentEditable = 'plaintext-only'; } catch { e.contentEditable = 'true'; }
    if (e.contentEditable !== 'plaintext-only') e.contentEditable = 'true';
    e.spellcheck = false;
  });
}
function changedCount() { return ['ar', 'fr', 'en', 'it'].reduce((n, l) => n + Object.keys(DRAFT[l]).length, 0) + (DRAFT.whatsapp != null ? 1 : 0); }

function studioBar() {
  const bar = h('div', 'studio-bar');
  bar.id = 'studioBar';
  const info = h('b', '', s_('bar'));
  const count = h('span', 'studio-count');
  const wa = h('label', 'studio-wa');
  const waIn = h('input'); waIn.inputMode = 'numeric'; waIn.dir = 'ltr'; waIn.value = whatsapp(); waIn.maxLength = 15;
  wa.append(h('span', '', s_('wa')), waIn);
  waIn.addEventListener('input', () => { waIn.value = waIn.value.replace(/\D/g, ''); DRAFT.whatsapp = waIn.value; refreshCount(); updateWaLinks(); renderPreview(); });
  const save = h('button', 'btn btn-green btn-sm', s_('save'));
  const discard = h('button', 'btn btn-ghost btn-sm', s_('discard'));
  const exit = h('button', 'btn btn-ghost btn-sm', s_('exit'));
  const msg = h('span', 'studio-msg');
  bar.append(info, count, wa, save, discard, exit, msg);
  document.body.append(bar);
  function refreshCount() { const n = changedCount(); count.textContent = n ? `• ${n} ${s_('changes')}` : ''; save.disabled = !n; }
  refreshCount();
  bar.refresh = refreshCount;

  save.addEventListener('click', async () => {
    const ses = getSession();
    if (!ses) { msg.textContent = s_('expired'); exitStudio(); loginDialog(); return; }
    if (DRAFT.whatsapp != null && !/^[0-9]{8,15}$/.test(DRAFT.whatsapp)) { msg.textContent = s_('waBad'); return; }
    const doc = {ar: {...CONTENT.ar}, fr: {...CONTENT.fr}, en: {...CONTENT.en}, it: {...CONTENT.it}, settings: {...CONTENT.settings}};
    for (const l of ['ar', 'fr', 'en', 'it']) {
      for (const [k, v] of Object.entries(DRAFT[l])) {
        const text = v.replace(/\s+/g, ' ').trim();
        if (!text || text === base(k, l)) delete doc[l][k]; else doc[l][k] = text.slice(0, 2000);
      }
    }
    if (DRAFT.whatsapp != null) { if (DRAFT.whatsapp === DEFAULT_WHATSAPP) delete doc.settings.whatsapp; else doc.settings.whatsapp = DRAFT.whatsapp; }
    save.disabled = true; msg.textContent = '…';
    try {
      const r = await api('/rest/v1/rpc/nfc_site_save', {new_doc: doc}, ses.token);
      if (r.status === 401) { msg.textContent = s_('expired'); setSession(null); return; }
      if (!r.ok) { msg.textContent = r.data?.message || s_('net'); save.disabled = false; return; }
      CONTENT = r.data;
      for (const l of ['ar', 'fr', 'en', 'it']) DRAFT[l] = {};
      delete DRAFT.whatsapp;
      msg.textContent = s_('saved');
      setLang(lang);
      refreshCount();
    } catch { msg.textContent = s_('net'); save.disabled = false; }
  });
  discard.addEventListener('click', () => { for (const l of ['ar', 'fr', 'en', 'it']) DRAFT[l] = {}; delete DRAFT.whatsapp; waIn.value = whatsapp(); msg.textContent = ''; setLang(lang); refreshCount(); });
  exit.addEventListener('click', () => { setSession(null); exitStudio(); history.replaceState(null, '', location.pathname); });
}

function onEdit(e) {
  const el = e.target.closest?.('[data-i]');
  if (!studioOn || !el) return;
  DRAFT[lang][el.dataset.i] = el.textContent;
  // Same key used in several places (e.g. the "Soon" badges): keep them in step.
  $$(`[data-i="${CSS.escape(el.dataset.i)}"]`).forEach((o) => { if (o !== el) o.textContent = el.textContent; });
  $('#studioBar')?.refresh();
}
function blockClicks(e) {
  if (!studioOn) return;
  if (e.target.closest('#studioBar, .langs, .studio-login')) return;
  const a = e.target.closest('a, button, summary');
  if (a && (a.matches('[data-i]') || a.querySelector('[data-i]') || a.closest('[data-i]'))) e.preventDefault();
}
function blockKeys(e) {
  if (studioOn && e.key === 'Enter' && e.target.closest?.('[data-i]')) e.preventDefault();
}

function enterStudio() {
  studioOn = true;
  document.body.classList.add('studio');
  markEditable();
  studioBar();
}
function exitStudio() {
  studioOn = false;
  document.body.classList.remove('studio');
  $$('[data-i]').forEach((e) => e.removeAttribute('contenteditable'));
  $('#studioBar')?.remove();
  for (const l of ['ar', 'fr', 'en', 'it']) DRAFT[l] = {};
  delete DRAFT.whatsapp;
  setLang(lang);
}
function openStudio() {
  if (studioOn || !CONFIG?.supabaseUrl) return;
  if (getSession()) enterStudio(); else if (!$('.studio-login')) loginDialog();
}
function initStudio() {
  document.addEventListener('input', onEdit, true);
  document.addEventListener('click', blockClicks, true);
  document.addEventListener('keydown', blockKeys, true);
  window.addEventListener('hashchange', () => { if (location.hash === '#studio') openStudio(); });
  let taps = 0, timer;
  $('.foot p')?.addEventListener('click', () => { taps++; clearTimeout(timer); timer = setTimeout(() => { taps = 0; }, 1500); if (taps >= 5) { taps = 0; openStudio(); } });
  if (location.hash === '#studio') openStudio();
}

start();
