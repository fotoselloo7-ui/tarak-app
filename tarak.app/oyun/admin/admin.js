(function () {
  'use strict';
  // Silme gibi geri alınamaz işlemler için onay
  document.querySelectorAll('form[data-onay]').forEach(function (f) {
    f.addEventListener('submit', function (e) { if (!window.confirm(f.getAttribute('data-onay'))) e.preventDefault(); });
  });
  // Grafik ipucu
  document.querySelectorAll('.grafik').forEach(function (kap) {
    var ipucu = kap.querySelector('.ipucu');
    kap.querySelectorAll('.isabet').forEach(function (r) {
      function goster() {
        var p = r.getAttribute('data-ipucu').split('|');
        ipucu.textContent = '';
        var tarih = document.createElement('span'); tarih.textContent = p[0];
        var deger = document.createElement('b'); deger.textContent = p[1];
        var alt = document.createElement('span'); alt.textContent = p[2];
        ipucu.append(tarih, deger, alt);
        ipucu.hidden = false;
        var a = kap.getBoundingClientRect(), b = r.getBoundingClientRect();
        var x = b.left - a.left + b.width / 2 + kap.scrollLeft;
        var yari = ipucu.offsetWidth / 2;
        ipucu.style.left = Math.max(yari, Math.min(kap.scrollWidth - yari, x)) + 'px';
        ipucu.style.top = (ipucu.offsetHeight + 6) + 'px';
      }
      function gizle() { ipucu.hidden = true; }
      r.addEventListener('pointerenter', goster); r.addEventListener('focus', goster);
      r.addEventListener('pointerleave', gizle); r.addEventListener('blur', gizle);
    });
  });
})();
