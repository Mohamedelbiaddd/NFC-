// The invitation e-mail, in the language the admin uses.
const T: Record<string, {subject: string; hi: string; body: string; button: string; code: string; steps: string[]; expire: string; ignore: string}> = {
  ar: {
    subject: 'دعوتك إلى تطبيق TapMaroc',
    hi: 'مرحباً {name}،',
    body: 'تمت إضافتك إلى فريق TapMaroc. نزّل التطبيق من الزر أدناه وفعّل حسابك واختر كلمة المرور الخاصة بك.',
    button: 'تحميل التطبيق وتفعيل الحساب',
    code: 'رمز التفعيل',
    steps: ['افتح الرابط من هاتفك الأندرويد ونزّل التطبيق وثبّته.', 'ارجع إلى الصفحة واضغط «تفعيل الحساب»، أو افتح التطبيق واختر «لدي دعوة» واكتب بريدك والرمز.', 'اختر كلمة مرورك. الحساب يعمل على هذا الهاتف فقط.'],
    expire: 'الرابط صالح 24 ساعة ولمرة واحدة فقط.',
    ignore: 'إذا لم تكن تنتظر هذه الدعوة فتجاهل هذه الرسالة.',
  },
  fr: {
    subject: 'Votre invitation à l’application TapMaroc',
    hi: 'Bonjour {name},',
    body: 'Vous avez été ajouté(e) à l’équipe TapMaroc. Téléchargez l’application avec le bouton ci-dessous, activez votre compte et choisissez votre mot de passe.',
    button: 'Télécharger l’application et activer',
    code: 'Code d’activation',
    steps: ['Ouvrez le lien sur votre téléphone Android, téléchargez et installez l’application.', 'Revenez sur la page et touchez « Activer le compte », ou ouvrez l’application, choisissez « J’ai une invitation » et saisissez votre e-mail et le code.', 'Choisissez votre mot de passe. Le compte fonctionne uniquement sur ce téléphone.'],
    expire: 'Le lien est valable 24 heures et une seule fois.',
    ignore: 'Si vous n’attendiez pas cette invitation, ignorez ce message.',
  },
  en: {
    subject: 'Your invitation to the TapMaroc app',
    hi: 'Hello {name},',
    body: 'You have been added to the TapMaroc team. Download the app with the button below, activate your account and choose your own password.',
    button: 'Download the app and activate',
    code: 'Activation code',
    steps: ['Open the link on your Android phone, download and install the app.', 'Come back to the page and tap “Activate account”, or open the app, choose “I have an invitation” and type your e-mail and the code.', 'Choose your password. The account works on this phone only.'],
    expire: 'The link is valid for 24 hours and can be used once.',
    ignore: 'If you were not expecting this invitation, ignore this e-mail.',
  },
  it: {
    subject: 'Il tuo invito all’app TapMaroc',
    hi: 'Ciao {name},',
    body: 'Sei stato aggiunto al team TapMaroc. Scarica l’app con il pulsante qui sotto, attiva il tuo account e scegli la tua password.',
    button: 'Scarica l’app e attiva',
    code: 'Codice di attivazione',
    steps: ['Apri il link dal tuo telefono Android, scarica e installa l’app.', 'Torna alla pagina e tocca «Attiva account», oppure apri l’app, scegli «Ho un invito» e scrivi la tua e-mail e il codice.', 'Scegli la tua password. L’account funziona solo su questo telefono.'],
    expire: 'Il link è valido 24 ore e una sola volta.',
    ignore: 'Se non aspettavi questo invito, ignora questa e-mail.',
  },
};

const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'}[c]!));

export function inviteEmail(lang: string, name: string, link: string, code: string) {
  const t = T[lang] ?? T.ar;
  const rtl = lang === 'ar';
  const hi = t.hi.replace('{name}', name || '');
  const html = `<!doctype html><html lang="${lang}" dir="${rtl ? 'rtl' : 'ltr'}"><body style="margin:0;background:#0b0f19;padding:24px 12px;font-family:Arial,Helvetica,sans-serif">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr><td align="center">
<table role="presentation" width="100%" style="max-width:520px;background:#121826;border-radius:18px;border:1px solid #23304a" cellspacing="0" cellpadding="0">
<tr><td style="padding:26px 26px 6px;text-align:${rtl ? 'right' : 'left'}">
<img src="https://tapmaroc.com/icon-192.png" width="56" height="56" alt="TapMaroc" style="border-radius:14px;display:block">
<h1 style="color:#fff;font-size:20px;margin:18px 0 6px">${esc(hi)}</h1>
<p style="color:#c5cde0;font-size:15px;line-height:1.6;margin:0 0 18px">${esc(t.body)}</p>
<a href="${link}" style="display:inline-block;background:#22b45a;color:#04150b;font-weight:bold;text-decoration:none;padding:14px 22px;border-radius:999px;font-size:15px">${esc(t.button)}</a>
<p style="color:#8f9ab3;font-size:13px;margin:22px 0 6px">${esc(t.code)}</p>
<p dir="ltr" style="color:#fff;font-size:26px;font-weight:bold;letter-spacing:4px;margin:0 0 18px;font-family:monospace;text-align:${rtl ? 'right' : 'left'}">${code}</p>
<ol style="color:#c5cde0;font-size:14px;line-height:1.6;padding-${rtl ? 'right' : 'left'}:18px;margin:0 0 16px">${t.steps.map((s) => `<li>${esc(s)}</li>`).join('')}</ol>
<p style="color:#f5b041;font-size:13px;margin:0 0 6px">⏱ ${esc(t.expire)}</p>
<p style="color:#6f7a93;font-size:12px;margin:0 0 22px">${esc(t.ignore)}</p>
</td></tr></table>
<p style="color:#56607a;font-size:11px;margin:14px 0 0">TapMaroc · tapmaroc.com</p>
</td></tr></table></body></html>`;
  const text = `${hi}\n\n${t.body}\n\n${link}\n\n${t.code}: ${code}\n\n${t.steps.map((s, i) => `${i + 1}. ${s}`).join('\n')}\n\n${t.expire}\n${t.ignore}`;
  return {subject: t.subject, html, text};
}
