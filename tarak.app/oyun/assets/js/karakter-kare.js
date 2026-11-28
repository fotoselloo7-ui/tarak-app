/* Karakter resimleri: 3D karakterden üretilir (tek kaynak).
 *  - portre(id, kiyafet, w, h): seçim ekranı ve menü için yüzü dönük resim (dataURL)
 *  - kareler(id, kiyafet): 2D oyun için yandan (3/4) koşma, zıplama, kayma, durma, sevinç kareleri (canvas)
 * Ayrı küçük bir WebGL çizicisi kullanır; oyunun ana sahnesine dokunmaz. */
(function () {
  'use strict';
  var T = window.THREE;
  var cizici = null, sahne, kamera, model = {}, KR = function () { return window.TarakKarakterler; };
  var KARE_W = 220, KARE_H = 260;

  function hazirla() {
    if (cizici) return true;
    if (!T) return false;
    try {
      var tv = document.createElement('canvas'); tv.width = KARE_W; tv.height = KARE_H;
      cizici = new T.WebGLRenderer({ canvas: tv, alpha: true, antialias: true, preserveDrawingBuffer: true });
      cizici.setClearColor(0x000000, 0);
      if (T.SRGBColorSpace) cizici.outputColorSpace = T.SRGBColorSpace;
    } catch (e) { cizici = null; return false; }
    sahne = new T.Scene();
    sahne.add(new T.HemisphereLight(0xffffff, 0x7a7f8c, 2.2));
    var g = new T.DirectionalLight(0xffffff, 2.4); g.position.set(-2, 4, -3); sahne.add(g);
    var a = new T.DirectionalLight(0xffe6c8, 1.1); a.position.set(3, 2, 3); sahne.add(a);
    kamera = new T.PerspectiveCamera(30, KARE_W / KARE_H, 0.1, 30);
    return true;
  }
  function modelAl(id) {
    var t = KR() && KR().bul(id);
    if (!t) return null;
    if (model[id]) return model[id];
    var m;
    if (t.tur === 'insan') m = window.TarakInsan3D.olustur(t);
    else { m = window.TarakMaskot3D.olustur(); m.kadin(t.cins === 'k'); }
    return (model[id] = m);
  }
  function hazirlaModel(id, kiyafet) {
    var m = modelAl(id); if (!m) return null;
    sahne.children.filter(function (c) { return c.userData.karakter; }).forEach(function (c) { sahne.remove(c); });
    m.kok.userData.karakter = true; sahne.add(m.kok);
    m.kusan(kiyafet || {});
    return m;
  }
  function boyut(w, h) { if (cizici.domElement.width !== w || cizici.domElement.height !== h) { cizici.setSize(w, h, false); kamera.aspect = w / h; kamera.updateProjectionMatrix(); } }

  // yakin: yalnız baş ve omuzlar (küçük menü çipi için)
  function portre(id, kiyafet, w, h, yakin) {
    if (!hazirla()) return null;
    w = w || 240; h = h || 300;
    var m = hazirlaModel(id, kiyafet); if (!m) return null;
    boyut(w, h);
    m.yuzOn(true); m.kok.position.set(0, 0, 0); m.kok.rotation.set(0, Math.PI + (yakin ? 0.15 : 0.3), 0);
    m.canlandir('dur', 1.2, {});
    if (yakin) { kamera.position.set(0, 1.62, 1.9); kamera.lookAt(0, 1.5, 0); }
    else { kamera.position.set(0, 1.22, 4.1); kamera.lookAt(0, 1.08, 0); }
    cizici.render(sahne, kamera);
    return cizici.domElement.toDataURL('image/png');
  }

  // 2D kareleri: karakter sağa koşar (2D oyun yan görünüm), hafif 3/4 açı
  var POZ = [['kos', 8], ['zipla', 2], ['kay', 1], ['dur', 2], ['sevinc', 2], ['dusus', 1]];
  function kareler(id, kiyafet) {
    if (!hazirla()) return null;
    var t = KR() && KR().bul(id);
    if (!t || t.tur !== 'insan') return null;            // maskot 2D'de kendi resimleriyle çizilir
    var m = hazirlaModel(id, kiyafet); if (!m) return null;
    boyut(KARE_W, KARE_H);
    m.yuzOn(false); m.kok.position.set(0, 0, 0);
    kamera.position.set(0, 1.05, 5.2); kamera.lookAt(0, 0.95, 0);
    var sonuc = {};
    POZ.forEach(function (pz) {
      var l = [];
      for (var i = 0; i < pz[1]; i++) {
        m.kok.rotation.set(0, Math.PI / 2 + 0.55, 0);      // sağa bakar, biraz kameraya dönük
        var faz = pz[0] === 'kos' ? i / pz[1] * Math.PI * 2 : i * 2.2;
        m.canlandir(pz[0], faz, {});
        cizici.render(sahne, kamera);
        var c = document.createElement('canvas'); c.width = KARE_W; c.height = KARE_H;
        c.getContext('2d').drawImage(cizici.domElement, 0, 0);
        l.push(c);
      }
      sonuc[pz[0]] = l;
    });
    // Ayak tabanı ve boy: durma karesindeki dolu piksellerden ölçülür (2D'de doğru yere oturtmak için)
    var d = sonuc.dur[0].getContext('2d').getImageData(0, 0, KARE_W, KARE_H).data, ust = KARE_H, alt = 0;
    for (var y = 0; y < KARE_H; y++) for (var x = 0; x < KARE_W; x += 2) if (d[(y * KARE_W + x) * 4 + 3] > 40) { if (y < ust) ust = y; if (y > alt) alt = y; }
    sonuc.taban = alt || KARE_H * 0.86; sonuc.boy = Math.max(40, (alt - ust) || KARE_H * 0.66);
    return sonuc;
  }

  window.TarakKare = { portre: portre, kareler: kareler };
})();
