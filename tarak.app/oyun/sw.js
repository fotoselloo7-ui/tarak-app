/* Çevrimdışı oynanabilsin diye oyun dosyalarını önbelleğe alır. Önce ağ, olmazsa önbellek. */
const AD = 'tarak-oyun-v8';
const DOSYALAR = ['./', 'index.html', 'assets/css/game.css', 'assets/js/ayar.js', 'assets/js/core.js', 'assets/js/render.js',
  'assets/js/audio.js', 'assets/js/main.js', 'assets/js/odul.js', 'assets/js/vendor/three.bundle.js',
  'assets/js/uc-core.js', 'assets/js/uc-maskot.js', 'assets/js/uc-modeller.js', 'assets/js/uc-sahne.js', 'assets/js/uc-oyun.js', 'assets/img/k-govde.png', 'assets/img/k-eldiven.png', 'assets/img/k-ayakkabi.png',
  'assets/img/logo-acik.svg', 'assets/img/foto-yuruyus.jpg', 'assets/img/ikon-192.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(AD).then(c => c.addAll(DOSYALAR))); self.skipWaiting(); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== AD).map(k => caches.delete(k))))); self.clients.claim(); });
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin || /\/(api|admin)\//.test(u.pathname)) return;
  e.respondWith(fetch(e.request).then(r => {
    if (r.ok) { const kopya = r.clone(); caches.open(AD).then(c => c.put(e.request, kopya)); }
    return r;
  }).catch(() => caches.match(e.request)));
});
