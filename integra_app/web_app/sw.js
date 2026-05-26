// ============================================================
// Integra Del Centro, S.C.
// sw.js — Service Worker
// Permite que la Web App funcione sin internet después de
// la primera visita. Cachea todos los recursos necesarios.
// ============================================================

const CACHE = 'integra-v2';
const ARCHIVOS = [
  './',
  './index.html',
  './manifest.json',
  'https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js',
  'https://cdnjs.cloudflare.com/ajax/libs/jspdf-autotable/3.8.2/jspdf.plugin.autotable.min.js',
];

// Instalar: guarda todos los recursos en caché
self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(cache => cache.addAll(ARCHIVOS))
  );
  self.skipWaiting();
});

// Activar: limpia cachés viejos
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// Fetch: responde desde caché si está disponible, si no va a red
self.addEventListener('fetch', e => {
  e.respondWith(
    caches.match(e.request).then(cached => {
      if (cached) return cached;
      return fetch(e.request).then(response => {
        // Solo cachear respuestas válidas
        if (!response || response.status !== 200) return response;
        const copia = response.clone();
        caches.open(CACHE).then(cache => cache.put(e.request, copia));
        return response;
      }).catch(() => cached);
    })
  );
});
