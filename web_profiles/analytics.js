// Google Tag Manager for the public pages (home, /start, /qr, privacy, terms),
// loaded only after the visitor accepts measurement cookies (GDPR: Italy/EU).
// Never included on customers' pages (/p, /c, /s, /k).
// Served from our own domain because the site's security policy refuses
// inline scripts; the snippet Google gives is reproduced here.
(() => {
  const GTM_ID = 'GTM-NSRTNL67';
  const KEY = 'tm_consent'; // 'yes' | 'no'
  let choice = null;
  try { choice = localStorage.getItem(KEY); } catch { /* private mode */ }

  window.dataLayer = window.dataLayer || [];
  function gtag() { window.dataLayer.push(arguments); }
  window.gtag = window.gtag || gtag;
  // Consent Mode v2: nothing is stored until the visitor says yes.
  gtag('consent', 'default', {
    ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied',
    analytics_storage: 'denied', wait_for_update: 500,
  });

  let loaded = false;
  function loadGtm() {
    if (loaded) return;
    loaded = true;
    gtag('consent', 'update', {
      ad_storage: 'granted', ad_user_data: 'granted', ad_personalization: 'granted', analytics_storage: 'granted',
    });
    gtag('js', new Date());
    window.dataLayer.push({'gtm.start': Date.now(), event: 'gtm.js'});
    const s = document.createElement('script');
    s.async = true;
    s.src = `https://www.googletagmanager.com/gtm.js?id=${GTM_ID}`;
    document.head.append(s);
  }

  if (choice === 'yes') { loadGtm(); return; }
  if (choice === 'no') return;

  const TEXT = {
    ar: ['نستعمل ملفات تعريف الارتباط لقياس زيارات الموقع وتحسينه.', 'موافق', 'لا، شكراً', 'الخصوصية'],
    fr: ['Nous utilisons des cookies pour mesurer l’audience et améliorer le site.', 'Accepter', 'Refuser', 'Confidentialité'],
    en: ['We use cookies to measure visits and improve the site.', 'Accept', 'Decline', 'Privacy'],
    it: ['Usiamo i cookie per misurare le visite e migliorare il sito.', 'Accetta', 'Rifiuta', 'Privacy'],
  };

  function show() {
    const lang = (document.documentElement.lang || 'ar').slice(0, 2);
    const [msg, yes, no, more] = TEXT[lang] ?? TEXT.en;
    const bar = document.createElement('div');
    bar.setAttribute('role', 'dialog');
    bar.setAttribute('aria-live', 'polite');
    bar.setAttribute('aria-label', more);
    bar.style.cssText = 'position:fixed;z-index:9999;inset-inline:12px;bottom:12px;max-width:560px;margin-inline:auto;'
      + 'background:#11151f;color:#eef1f8;border:1px solid #ffffff22;border-radius:16px;padding:14px 16px;'
      + 'box-shadow:0 18px 40px -12px #000c;font:14px/1.5 system-ui,sans-serif;display:flex;flex-wrap:wrap;gap:10px;align-items:center';
    const p = document.createElement('p');
    p.style.cssText = 'margin:0;flex:1 1 240px';
    p.textContent = msg + ' ';
    const a = document.createElement('a');
    a.href = '/privacy';
    a.textContent = more;
    a.style.color = '#7fd3a5';
    p.append(a);
    const btn = (label, primary) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = label;
      b.style.cssText = 'min-height:40px;padding:8px 16px;border-radius:99px;font:inherit;font-weight:700;cursor:pointer;'
        + (primary ? 'background:#22b45a;color:#04150b;border:0' : 'background:transparent;color:#eef1f8;border:1px solid #ffffff44');
      return b;
    };
    const ok = btn(yes, true), nope = btn(no, false);
    const done = (v) => {
      try { localStorage.setItem(KEY, v); } catch { /* ignore */ }
      bar.remove();
      if (v === 'yes') loadGtm();
    };
    ok.addEventListener('click', () => done('yes'));
    nope.addEventListener('click', () => done('no'));
    bar.append(p, nope, ok);
    document.body.append(bar);
  }

  // Wait for the page (and its language switch) before asking.
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', () => setTimeout(show, 600));
  else setTimeout(show, 600);
})();
