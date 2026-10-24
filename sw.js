/**
 * Usman Engineer Portfolio - Service Worker
 * PWA Offline support and caching strategy
 */

const CACHE_NAME = 'usman-pwa-v1';

const PRECACHE_ASSETS = [
  '/',
  '/index.html',
  '/subpage.css',
  '/track.js',
  '/favicon.svg',
  '/icon-192.png',
  '/icon-512.png',
  '/apple-touch-icon.png',
  '/photo.jpg',
  '/og-image.png',
  '/thumb-plant-layout.jpg',
  '/thumb-esp.png',
  '/dft-zeolite.jpg',
  '/plant-layout/',
  '/plant-layout/index.html',
  '/plant-layout/favicon.svg',
  '/plant-layout/icon-192.png',
  '/plant-layout/icon-512.png',
  '/plant-layout/og-image.jpg',
  '/esp/',
  '/esp/index.html',
  '/esp/favicon.svg',
  '/esp/icon-192.png',
  '/esp/icon-512.png'
];

// Install: precache essential shell assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(PRECACHE_ASSETS).catch((err) => {
        console.warn('Pre-cache non-critical item failed:', err);
      });
    }).then(() => self.skipWaiting())
  );
});

// Activate: clean up outdated caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch: Strategy routing
self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);

  // Never cache API endpoints
  if (url.pathname.startsWith('/api/')) {
    return;
  }

  // Non-GET requests should proceed to network
  if (req.method !== 'GET') {
    return;
  }

  // HTML Navigation: Network-first with cache fallback
  if (req.mode === 'navigate' || req.headers.get('accept')?.includes('text/html')) {
    event.respondWith(
      fetch(req)
        .then((networkRes) => {
          if (networkRes && networkRes.status === 200) {
            const clone = networkRes.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(req, clone));
          }
          return networkRes;
        })
        .catch(async () => {
          const cached = await caches.match(req);
          if (cached) return cached;
          const rootCached = await caches.match('/');
          if (rootCached) return rootCached;
          return new Response('<h1>Offline</h1><p>Please check your internet connection.</p>', {
            headers: { 'Content-Type': 'text/html' }
          });
        })
    );
    return;
  }

  // Static Assets (Images, CSS, JS, Fonts): Stale-While-Revalidate
  event.respondWith(
    caches.match(req).then((cachedRes) => {
      const fetchPromise = fetch(req)
        .then((networkRes) => {
          if (networkRes && networkRes.status === 200) {
            const clone = networkRes.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(req, clone));
          }
          return networkRes;
        })
        .catch(() => cachedRes);

      return cachedRes || fetchPromise;
    })
  );
});
