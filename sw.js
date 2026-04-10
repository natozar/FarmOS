const CACHE_NAME = 'agruai-v1';
const STATIC_ASSETS = [
  './',
  './index.html',
  './manifest.json',
  './icons/icon-192x192.png',
  './icons/icon-512x512.png',
  './icons/apple-touch-icon-180x180.png',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
  'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js'
];

const FONT_CACHE = 'agruai-fonts-v1';
const MAP_CACHE = 'agruai-maps-v1';
const MAP_CACHE_LIMIT = 500;

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(STATIC_ASSETS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys.filter(k => k !== CACHE_NAME && k !== FONT_CACHE && k !== MAP_CACHE)
          .map(k => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const url = e.request.url;

  // Map tiles: cache-first with limit
  if (url.includes('basemaps.cartocdn.com')) {
    e.respondWith(
      caches.open(MAP_CACHE).then(cache =>
        cache.match(e.request).then(cached => {
          if (cached) return cached;
          return fetch(e.request).then(res => {
            if (res.ok) {
              cache.put(e.request, res.clone());
              // Limpar cache antigo se exceder limite
              cache.keys().then(keys => {
                if (keys.length > MAP_CACHE_LIMIT) {
                  keys.slice(0, keys.length - MAP_CACHE_LIMIT).forEach(k => cache.delete(k));
                }
              });
            }
            return res;
          }).catch(() => cached || new Response('', { status: 408 }));
        })
      )
    );
    return;
  }

  // Google Fonts: cache-first
  if (url.includes('fonts.googleapis.com') || url.includes('fonts.gstatic.com')) {
    e.respondWith(
      caches.open(FONT_CACHE).then(cache =>
        cache.match(e.request).then(cached =>
          cached || fetch(e.request).then(res => {
            if (res.ok) cache.put(e.request, res.clone());
            return res;
          })
        )
      )
    );
    return;
  }

  // Static assets: cache-first, network fallback
  if (e.request.destination === 'image' || url.includes('icons/')) {
    e.respondWith(
      caches.match(e.request).then(cached =>
        cached || fetch(e.request).then(res => {
          if (res.ok) {
            caches.open(CACHE_NAME).then(c => c.put(e.request, res.clone()));
          }
          return res;
        })
      )
    );
    return;
  }

  // HTML: network-first, cache fallback (always get latest)
  if (e.request.mode === 'navigate') {
    e.respondWith(
      fetch(e.request).then(res => {
        if (res.ok) {
          caches.open(CACHE_NAME).then(c => c.put(e.request, res.clone()));
        }
        return res;
      }).catch(() => caches.match(e.request).then(c => c || caches.match('./index.html')))
    );
    return;
  }

  // Everything else: cache-first
  e.respondWith(
    caches.match(e.request).then(cached => cached || fetch(e.request))
  );
});