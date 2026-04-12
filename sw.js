const CACHE_NAME = 'agruai-v6';
const STATIC_ASSETS = [
  './',
  './painel.html',
  './manifest.json',
  './icons/icon-192x192.png',
  './icons/icon-512x512.png',
  './icons/apple-touch-icon-180x180.png',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
  'https://api.mapbox.com/mapbox-gl-js/v3.4.0/mapbox-gl.js',
  'https://api.mapbox.com/mapbox-gl-js/v3.4.0/mapbox-gl.css',
  'https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-draw/v1.4.3/mapbox-gl-draw.js',
  'https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-draw/v1.4.3/mapbox-gl-draw.css',
  'https://cdn.jsdelivr.net/npm/@turf/turf@7/turf.min.js',
  'https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.2/jspdf.umd.min.js'
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

  // Skip non-GET for Supabase API calls — let the app handle offline logic
  if (e.request.method !== 'GET') return;

  // Map tiles: cache-first with limit
  if (url.includes('basemaps.cartocdn.com') || url.includes('api.mapbox.com/v4') || url.includes('tiles.mapbox.com')) {
    e.respondWith(
      caches.open(MAP_CACHE).then(cache =>
        cache.match(e.request).then(cached => {
          if (cached) return cached;
          return fetch(e.request).then(res => {
            if (res.ok) {
              cache.put(e.request, res.clone());
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

  // Supabase API / RPC calls: network-only (offline handled by app IndexedDB)
  if (url.includes('supabase.co')) return;

  // Static assets (images, icons): cache-first
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

  // HTML pages: network-first, cache fallback (always get latest when online)
  if (e.request.mode === 'navigate') {
    e.respondWith(
      fetch(e.request).then(res => {
        if (res.ok) {
          caches.open(CACHE_NAME).then(c => c.put(e.request, res.clone()));
        }
        return res;
      }).catch(() => caches.match(e.request).then(c => c || caches.match('./painel.html')))
    );
    return;
  }

  // JS/CSS libs: cache-first (CDN assets don't change often)
  if (url.includes('cdn.jsdelivr.net') || url.includes('api.mapbox.com')) {
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

  // Everything else: cache-first
  e.respondWith(
    caches.match(e.request).then(cached => cached || fetch(e.request))
  );
});
