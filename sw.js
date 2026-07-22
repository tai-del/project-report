// Service Worker – פיקוח בנייה תמ"א 38
const CACHE_NAME = 'pikuach-v6';
const PRECACHE = ['./', './index.html', './manifest.json'];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE_NAME).then(c => c.addAll(PRECACHE)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  // Skip Supabase API/auth/storage calls — always go to network
  if (e.request.url.includes('supabase.co')) return;

  // The app shell (page navigations + index.html) is network-first so a new
  // deploy is picked up immediately; falls back to cache only when offline.
  // cache:'no-store' bypasses the browser's own HTTP cache too — GitHub
  // Pages sends Cache-Control: max-age=600, which without this would let a
  // stale response win for up to 10 minutes even with this "network-first"
  // logic in place.
  if (e.request.mode === 'navigate' || e.request.url.endsWith('index.html')) {
    e.respondWith(
      fetch(e.request, { cache: 'no-store' }).then(resp => {
        const clone = resp.clone();
        caches.open(CACHE_NAME).then(c => c.put(e.request, clone));
        return resp;
      }).catch(() => caches.match(e.request).then(c => c || caches.match('./index.html')))
    );
    return;
  }

  e.respondWith(
    caches.match(e.request).then(cached => {
      if (cached) return cached;
      return fetch(e.request).then(resp => {
        if (!resp || resp.status !== 200 || resp.type === 'opaque') return resp;
        const clone = resp.clone();
        caches.open(CACHE_NAME).then(c => c.put(e.request, clone));
        return resp;
      }).catch(() => caches.match('./index.html'));
    })
  );
});
