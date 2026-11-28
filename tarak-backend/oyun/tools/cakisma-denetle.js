/* Tarayıcı konsolunda (yerel test sayfasında) çalışır: görünen ekrandaki öğelerin üst üste binmesini ve taşmasını bulur.
 * Kullanım: window.cakismaDenetle()  ->  [{ a, b, alan }] ve taşan öğeler */
(function () {
  function gorunur(el) {
    if (!el.getClientRects().length) return false;
    var s = getComputedStyle(el);
    return s.visibility !== 'hidden' && s.display !== 'none' && +s.opacity > 0.05;
  }
  function ad(el) {
    var t = (el.innerText || el.getAttribute('aria-label') || el.alt || '').trim().replace(/\s+/g, ' ').slice(0, 28);
    return el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (el.className && typeof el.className === 'string' ? '.' + el.className.split(' ')[0] : '') + (t ? ' "' + t + '"' : '');
  }
  window.cakismaDenetle = function (kok) {
    kok = kok || document;
    var secici = 'button, a, h1, h2, p, .rozet, .cuzdan, .seviye-rozet, .karakter-cip, .menu-tost, .duyuru, #hud-bolum, #hud-guc span, #hud-sponsor, .serit-dugme, .kumanda, .urun, .bolum, .rota-kart, .sonuc-foto, #sonuc-tablo div, .kart > *';
    var els = Array.prototype.filter.call(kok.querySelectorAll(secici), function (e) {
      if (!gorunur(e)) return false;
      var r = e.getBoundingClientRect();
      return r.width > 2 && r.height > 2;
    });
    // Kaydırılan listelerin içindekiler yalnızca kendi aralarında karşılaştırılmaz (taşma denetlenir)
    var cakisan = [], tasan = [], W = innerWidth, H = innerHeight;
    els.forEach(function (e) {
      var r = e.getBoundingClientRect(), kayan = e.closest('.kaydir, #rota-liste, #magaza-liste, .bolumler');
      if (!kayan && (r.left < -1 || r.right > W + 1 || r.top < -1 || r.bottom > H + 1)) tasan.push(ad(e));
    });
    for (var i = 0; i < els.length; i++) for (var j = i + 1; j < els.length; j++) {
      var a = els[i], b = els[j];
      if (a.contains(b) || b.contains(a)) continue;
      var ra = a.getBoundingClientRect(), rb = b.getBoundingClientRect();
      var x = Math.min(ra.right, rb.right) - Math.max(ra.left, rb.left), y = Math.min(ra.bottom, rb.bottom) - Math.max(ra.top, rb.top);
      if (x > 3 && y > 3) {
        var ka = a.closest('.kaydir, #rota-liste, #magaza-liste'), kb = b.closest('.kaydir, #rota-liste, #magaza-liste');
        var gizliA = ka && (ra.bottom < ka.getBoundingClientRect().top || ra.top > ka.getBoundingClientRect().bottom);
        var gizliB = kb && (rb.bottom < kb.getBoundingClientRect().top || rb.top > kb.getBoundingClientRect().bottom);
        if (!gizliA && !gizliB) cakisan.push({ a: ad(a), b: ad(b), alan: Math.round(x * y) });
      }
    }
    return { cakisan: cakisan, tasan: tasan };
  };
})();
