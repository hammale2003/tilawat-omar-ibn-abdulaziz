/* App shell only. Audio is never cached here: downloaded recitations live as
 * Blobs in IndexedDB, so the browser gets a whole file and seeking works
 * without hand-rolling HTTP Range replies — which is what breaks media
 * playback through a service worker on iOS. */

const CACHE = 'tilawa-shell-v1';

const SHELL = [
  './',
  'index.html',
  'app.css',
  'app.js',
  'privacy.html',
  'manifest.webmanifest',
  'catalog.json',
  'art.png',
  'surahs.json',
  'fonts/tajawal-regular.woff2',
  'fonts/tajawal-bold.woff2',
  'fonts/amiri-regular.woff2',
  'fonts/amiri-bold.woff2',
  'icons/icon-192.png',
  'icons/icon-512.png',
  'icons/apple-touch-icon.png',
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE)
      .then((c) => Promise.allSettled(SHELL.map((u) => c.add(u))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  // Audio lives on archive.org. Leave every cross-origin request alone so
  // range requests reach the network untouched.
  if (url.origin !== self.location.origin) return;

  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
          return res;
        })
        .catch(() => caches.match(req).then((r) => r || caches.match('index.html')))
    );
    return;
  }

  e.respondWith(
    caches.match(req).then((hit) => {
      if (hit) return hit;
      return fetch(req).then((res) => {
        if (res && res.ok && res.type === 'basic') {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
        }
        return res;
      });
    })
  );
});
