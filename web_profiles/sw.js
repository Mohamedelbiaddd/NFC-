// Minimal service worker: lets Android offer the one-tap "Install" window for
// shop pages. Every request still goes to the network (always fresh data).
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(fetch(e.request));
});
