// /app/<token>: the staff invitation page. Downloads the app (private, 10-min
// link from the app-download function while the 24 h invitation is valid)
// and opens the app's activation screen (tapmaroc://activate?t=...).
const FN = 'https://ikcaingdfybpqrdzucyd.supabase.co/functions/v1/app-download';
const token = (location.pathname.split('/')[2] || '').replace(/[^A-Za-z0-9]/g, '');

const T = {
  ar: {
    alert: '⚠️ تنبيه هام: إذا دخل شخص آخر إلى التطبيق بهذه الدعوة قبلك فلن تستطيع الدخول، لأن الحساب يعمل على الهاتف الذي دخل أولاً فقط ويجب أن يوافق على هاتفك. في هذه الحالة تواصل معنا فوراً:',
    hi: 'مرحباً {0} 👋', lead: 'هذه دعوتك إلى تطبيق فريق TapMaroc. نزّل التطبيق من هاتفك الأندرويد ثم فعّل حسابك واختر كلمة مرورك.',
    download: '⬇ تحميل التطبيق', activate: '✅ تفعيل الحساب (بعد التثبيت)', old: 'هاتف قديم؟ نسخة 32-bit',
    steps: ['اضغط «تحميل التطبيق» وانتظر انتهاء التحميل.', 'افتح الملف TapMaroc.apk واسمح بالتثبيت من هذا المصدر إذا طلب الهاتف ذلك.', 'ارجع إلى هذه الصفحة واضغط «تفعيل الحساب»، أو افتح التطبيق واختر «لدي دعوة» واكتب بريدك ورمز التفعيل الموجود في الرسالة.', 'اختر كلمة مرورك. الحساب يعمل على هذا الهاتف فقط.'],
    expires: '⏱ الرابط صالح حتى {0} ولمرة واحدة.',
    dead: {expired: 'انتهت صلاحية هذا الرابط (24 ساعة).', used: 'هذا الرابط استُعمل من قبل: الحساب مفعّل.', revoked: 'هذا الرابط أُلغي أو استُبدل برابط أحدث.', not_found: 'الرابط غير صحيح.'},
    deadLead: 'اطلب من المسؤول عنك إرسال رابط جديد.', notReady: 'التطبيق غير متوفر الآن، حاول بعد قليل.',
    foot: 'التطبيق خاص بفريق TapMaroc ولا يُنشر للعموم.', desktop: 'افتح هذا الرابط من هاتفك الأندرويد.',
  },
  fr: {
    alert: '⚠️ Important : si une autre personne entre dans l’application avec cette invitation avant vous, vous ne pourrez pas vous connecter, car le compte fonctionne uniquement sur le premier téléphone connecté, qui doit approuver le vôtre. Dans ce cas, contactez-nous :',
    hi: 'Bonjour {0} 👋', lead: 'Voici votre invitation à l’application de l’équipe TapMaroc. Téléchargez-la sur votre téléphone Android, puis activez votre compte et choisissez votre mot de passe.',
    download: '⬇ Télécharger l’application', activate: '✅ Activer le compte (après l’installation)', old: 'Ancien téléphone ? Version 32 bits',
    steps: ['Touchez « Télécharger l’application » et attendez la fin du téléchargement.', 'Ouvrez TapMaroc.apk et autorisez l’installation depuis cette source si le téléphone le demande.', 'Revenez ici et touchez « Activer le compte », ou ouvrez l’application, choisissez « J’ai une invitation » et saisissez votre e-mail et le code reçu.', 'Choisissez votre mot de passe. Le compte fonctionne uniquement sur ce téléphone.'],
    expires: '⏱ Lien valable jusqu’au {0}, une seule fois.',
    dead: {expired: 'Ce lien a expiré (24 heures).', used: 'Ce lien a déjà été utilisé : le compte est activé.', revoked: 'Ce lien a été annulé ou remplacé par un plus récent.', not_found: 'Lien invalide.'},
    deadLead: 'Demandez un nouveau lien à votre responsable.', notReady: 'L’application n’est pas disponible pour le moment, réessayez bientôt.',
    foot: 'Application réservée à l’équipe TapMaroc, non publique.', desktop: 'Ouvrez ce lien sur votre téléphone Android.',
  },
  en: {
    alert: '⚠️ Important: if someone else enters the app with this invitation before you, you will not be able to log in, because the account only works on the first phone that logged in and that phone must approve yours. If this happens, contact us:',
    hi: 'Hello {0} 👋', lead: 'This is your invitation to the TapMaroc team app. Download it on your Android phone, then activate your account and choose your password.',
    download: '⬇ Download the app', activate: '✅ Activate account (after installing)', old: 'Older phone? 32-bit version',
    steps: ['Tap “Download the app” and wait for the download to finish.', 'Open TapMaroc.apk and allow installing from this source if the phone asks.', 'Come back here and tap “Activate account”, or open the app, choose “I have an invitation” and type your e-mail and the code from the message.', 'Choose your password. The account works on this phone only.'],
    expires: '⏱ Valid until {0}, one use only.',
    dead: {expired: 'This link has expired (24 hours).', used: 'This link was already used: the account is active.', revoked: 'This link was cancelled or replaced by a newer one.', not_found: 'Invalid link.'},
    deadLead: 'Ask your manager for a new link.', notReady: 'The app is not available right now, try again shortly.',
    foot: 'This app is for the TapMaroc team only and is not public.', desktop: 'Open this link on your Android phone.',
  },
  it: {
    alert: '⚠️ Importante: se qualcun altro entra nell’app con questo invito prima di te, non potrai accedere, perché l’account funziona solo sul primo telefono che ha fatto l’accesso, che deve approvare il tuo. In questo caso contattaci:',
    hi: 'Ciao {0} 👋', lead: 'Questo è il tuo invito all’app del team TapMaroc. Scaricala sul tuo telefono Android, poi attiva l’account e scegli la tua password.',
    download: '⬇ Scarica l’app', activate: '✅ Attiva account (dopo l’installazione)', old: 'Telefono vecchio? Versione 32 bit',
    steps: ['Tocca «Scarica l’app» e attendi la fine del download.', 'Apri TapMaroc.apk e consenti l’installazione da questa fonte se il telefono lo chiede.', 'Torna qui e tocca «Attiva account», oppure apri l’app, scegli «Ho un invito» e scrivi la tua e-mail e il codice del messaggio.', 'Scegli la tua password. L’account funziona solo su questo telefono.'],
    expires: '⏱ Valido fino al {0}, una sola volta.',
    dead: {expired: 'Questo link è scaduto (24 ore).', used: 'Questo link è già stato usato: l’account è attivo.', revoked: 'Questo link è stato annullato o sostituito da uno più recente.', not_found: 'Link non valido.'},
    deadLead: 'Chiedi un nuovo link al tuo responsabile.', notReady: 'L’app non è disponibile ora, riprova tra poco.',
    foot: 'App riservata al team TapMaroc, non pubblica.', desktop: 'Apri questo link dal tuo telefono Android.',
  },
};

const $ = (id) => document.getElementById(id);
const fmt = (s, v) => s.replace('{0}', v);

function setLang(lang) {
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
  return T[lang] ?? T.ar;
}

async function main() {
  let info = {state: 'not_found'};
  if (token.length >= 30) {
    try {
      const res = await fetch(`${FN}?t=${token}&info=1`, {cache: 'no-store'});
      info = await res.json();
    } catch { info = {state: 'error'}; }
  }
  const t = setLang(info.lang || (navigator.language || 'ar').slice(0, 2));
  $('foot').textContent = t.foot;
  if (info.state !== 'ok') {
    $('title').textContent = t.dead[info.state] ?? t.notReady;
    $('title').classList.add('bad');
    $('lead').textContent = info.state === 'error' ? t.notReady : t.deadLead;
    return;
  }
  $('title').textContent = fmt(t.hi, info.name || '');
  $('lead').textContent = /Android/i.test(navigator.userAgent) ? t.lead : `${t.lead} ${t.desktop}`;
  if (!info.ready) {
    $('lead').textContent = t.notReady;
    return;
  }
  $('ok').classList.remove('hide');
  $('download').textContent = t.download;
  $('download').href = `${FN}?t=${token}`;
  $('old').textContent = t.old;
  $('old').href = `${FN}?t=${token}&abi=v7`;
  $('activate').textContent = t.activate;
  $('activate').href = `intent://activate?t=${token}#Intent;scheme=tapmaroc;package=com.nfcstudio.nfc_studio;end`;
  const ol = $('steps');
  for (const s of t.steps) {
    const li = document.createElement('li');
    li.textContent = s;
    ol.append(li);
  }
  $('alert').textContent = t.alert;
  const until = new Date(info.expires_at);
  $('expires').textContent = fmt(t.expires, until.toLocaleString(document.documentElement.lang, {dateStyle: 'medium', timeStyle: 'short'}));
}

main();
