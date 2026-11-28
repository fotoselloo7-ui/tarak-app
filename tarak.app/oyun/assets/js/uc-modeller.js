/* 3D modeller: gerçek oranlı arabalar, tır, safari cipi, aslan, ağaç ve kayalar.
 * Hepsi kodla üretilir (dışarıdan model dosyası yok). Ölçüler metre. Modeller -z yönüne bakar. */
(function () {
  'use strict';
  var T = window.THREE;

  // ---------- Malzeme ve geometri önbellekleri ----------
  var mC = {};
  function std(renk, puruz, metal) {
    var k = 's' + renk + '|' + puruz + '|' + metal;
    return mC[k] || (mC[k] = new T.MeshStandardMaterial({ color: renk, roughness: puruz, metalness: metal || 0 }));
  }
  function isik(renk, guc) {
    var k = 'i' + renk + '|' + guc;
    return mC[k] || (mC[k] = new T.MeshStandardMaterial({ color: renk, emissive: renk, emissiveIntensity: guc, roughness: 0.3 }));
  }
  function lam(renk) { var k = 'l' + renk; return mC[k] || (mC[k] = new T.MeshStandardMaterial({ color: renk, roughness: 0.9, metalness: 0 })); }
  // Ağaç kabuğu: fotoğraf dokusu sahne tarafından sonradan bağlanır (birleştirmeye girmez)
  function kabukMat() {
    if (!mC.kabuk) { mC.kabuk = new T.MeshStandardMaterial({ color: 0x8a6a50, roughness: 0.95, metalness: 0 }); mC.kabuk.userData.foto = true; }
    return mC.kabuk;
  }
  // Gerçek araba boyası: metalik taban ve üstte parlak cila katmanı
  function boyaMat(renk) {
    var k = 'boya' + renk;
    return mC[k] || (mC[k] = new T.MeshPhysicalMaterial({ color: renk, roughness: 0.38, metalness: 0.55, clearcoat: 1, clearcoatRoughness: 0.05 }));
  }
  function kurkMat(renk) {
    var k = 'kurk' + renk;
    if (mC[k]) return mC[k];
    var d = tuvalDoku(256, 256, function (g) {
      g.fillStyle = '#dcdcdc'; g.fillRect(0, 0, 256, 256);
      for (var i = 0; i < 6000; i++) {
        var x = Math.random() * 256, y = Math.random() * 256, l = Math.round(150 + Math.random() * 105);
        g.strokeStyle = 'rgba(' + l + ',' + l + ',' + l + ',.6)'; g.lineWidth = 1;
        g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.random() * 2 - 1, y + 4 + Math.random() * 7); g.stroke();
      }
    });
    d.wrapS = d.wrapT = T.RepeatWrapping; d.repeat.set(3, 3);
    return (mC[k] = new T.MeshStandardMaterial({ color: renk, roughness: 0.96, metalness: 0, map: d }));
  }
  function cam() {
    return mC.cam || (mC.cam = new T.MeshStandardMaterial({ color: 0x16212c, roughness: 0.05, metalness: 0.85, side: T.DoubleSide, envMapIntensity: 1.6 }));
  }
  function golgeMat() {
    return mC.golge || (mC.golge = new T.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.32, depthWrite: false }));
  }

  var gC = {};
  function geo(k, yap) { return gC[k] || (gC[k] = yap()); }
  function kutu(w, h, d) { return geo('b' + w + '|' + h + '|' + d, function () { return new T.BoxGeometry(w, h, d); }); }
  function silindir(r1, r2, h, n) { return geo('c' + r1 + '|' + r2 + '|' + h + '|' + n, function () { return new T.CylinderGeometry(r1, r2, h, n || 14); }); }
  function kure(r, n) { return geo('s' + r + '|' + n, function () { return new T.SphereGeometry(r, n || 14, Math.max(6, (n || 14) - 4)); }); }
  function kapsul(r, l) { return geo('k' + r + '|' + l, function () { return new T.CapsuleGeometry(r, l, 4, 10); }); }
  function ekle(e, g, m, x, y, z) { var o = new T.Mesh(g, m); o.position.set(x || 0, y || 0, z || 0); e.add(o); return o; }

  function tuvalDoku(w, h, ciz) {
    var c = document.createElement('canvas'); c.width = w; c.height = h;
    ciz(c.getContext('2d'), w, h);
    var d = new T.CanvasTexture(c); d.colorSpace = T.SRGBColorSpace; d.anisotropy = 4;
    return d;
  }
  var yaziC = {};
  function yaziMat(metin, zemin, renk, en, boy) {
    var k = metin + '|' + zemin + '|' + renk + '|' + en + '|' + boy;
    if (yaziC[k]) return yaziC[k];
    var pw = 256, ph = Math.max(16, Math.round(pw * boy / en));
    var d = tuvalDoku(pw, ph, function (c) {
      c.fillStyle = zemin; c.fillRect(0, 0, pw, ph);
      c.fillStyle = renk; c.textAlign = 'center'; c.textBaseline = 'middle';
      var s = metin.split('\n');
      s.forEach(function (t, i) { c.font = '900 ' + Math.round(ph * 0.62 / s.length) + 'px system-ui, sans-serif'; c.fillText(t, pw / 2, ph * (i + 0.52) / s.length, pw * 0.92); });
    });
    return (yaziC[k] = new T.MeshBasicMaterial({ map: d, toneMapped: false }));
  }
  // Gerçek tarak.app logosu (beyaz yazı + altın K). Yüklenince tüm logo dokuları yeniden çizilir.
  var LOGO = new Image(), logoDokular = [], logoC = {};
  LOGO.onload = function () { logoDokular.forEach(function (l) { var cv = l.d.image; l.ciz(cv.getContext('2d'), cv.width, cv.height); l.d.needsUpdate = true; }); };
  LOGO.src = 'assets/img/logo-acik.svg';
  function logoMat(zemin, en, boy, alt, altRenk) {
    var k = zemin + '|' + en + '|' + boy + '|' + (alt || '');
    if (logoC[k]) return logoC[k];
    var pw = 512, ph = Math.max(32, Math.round(pw * boy / en));
    function ciz(c, cw, ch) {
      c.fillStyle = zemin; c.fillRect(0, 0, cw, ch);
      var altH = alt ? ch * 0.27 : 0, oran = 980 / 440;
      var w = Math.min(cw * 0.84, (ch - altH) * 0.82 * oran), h = w / oran, y = (ch - altH - h) / 2 + (alt ? ch * 0.03 : 0);
      if (LOGO.complete && LOGO.width) c.drawImage(LOGO, (cw - w) / 2, y, w, h);
      else { c.fillStyle = '#ffffff'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.font = '900 ' + Math.round(h * 0.7) + 'px system-ui, sans-serif'; c.fillText('tarak.app', cw / 2, y + h / 2, cw * 0.9); }
      if (alt) { c.fillStyle = altRenk || '#ffc400'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.font = '800 ' + Math.round(altH * 0.6) + 'px system-ui, sans-serif'; c.fillText(alt, cw / 2, ch - altH * 0.58, cw * 0.92); }
    }
    var d = tuvalDoku(pw, ph, ciz);
    logoDokular.push({ d: d, ciz: ciz });
    return (logoC[k] = new T.MeshBasicMaterial({ map: d, toneMapped: false }));
  }
  function logoPlaka(e, zemin, en, boy, alt, x, y, z, ry) {
    var m = new T.Mesh(geo('p' + en + '|' + boy, function () { return new T.PlaneGeometry(en, boy); }), logoMat(zemin, en, boy, alt));
    m.position.set(x, y, z); m.rotation.y = ry || 0; e.add(m); return m;
  }
  function plaka(e, metin, zemin, renk, en, boy, x, y, z, ry) {
    var m = new T.Mesh(geo('p' + en + '|' + boy, function () { return new T.PlaneGeometry(en, boy); }), yaziMat(metin, zemin, renk, en, boy));
    m.position.set(x, y, z); m.rotation.y = ry || 0; e.add(m);
    return m;
  }
  function damaMat() {
    return mC.dama || (mC.dama = new T.MeshBasicMaterial({ toneMapped: false, map: tuvalDoku(256, 16, function (c) {
      for (var i = 0; i < 32; i++) for (var j = 0; j < 2; j++) { c.fillStyle = (i + j) % 2 ? '#111' : '#f2c200'; c.fillRect(i * 8, j * 8, 8, 8); }
    }) }));
  }

  // Bir gruptaki parçaları malzemeye göre birleştirir: araba başına birkaç çizim çağrısı kalır.
  function birlestirMat(kok) {
    kok.updateMatrixWorld(true);
    var gruplar = new Map();
    kok.traverse(function (m) {
      if (!m.isMesh) return;
      var g = m.geometry.index ? m.geometry.toNonIndexed() : m.geometry.clone();
      g.applyMatrix4(m.matrixWorld);
      Object.keys(g.attributes).forEach(function (a) { if (a !== 'position' && a !== 'normal' && a !== 'uv') g.deleteAttribute(a); });
      if (!g.attributes.uv) g.setAttribute('uv', new T.BufferAttribute(new Float32Array(g.attributes.position.count * 2), 2));
      if (!g.attributes.normal) g.computeVertexNormals();
      g.morphAttributes = {};
      g.clearGroups();
      var l = gruplar.get(m.material);
      if (!l) { l = []; gruplar.set(m.material, l); }
      l.push(g);
    });
    var yeni = new T.Group();
    gruplar.forEach(function (l, malz) {
      var me = new T.Mesh(l.length > 1 ? T.mergeGeometries(l, false) : l[0], malz);
      me.castShadow = !malz.transparent;
      yeni.add(me);
    });
    return yeni;
  }

  // Organik şekiller için pürüzlü yüzey (yaprak, yele, kaya). Aynı noktadaki köşeler aynı oranda itilir.
  function hash3(x, y, z) { var h = Math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453; return h - Math.floor(h); }
  function puruzlu(g, guc) {
    var gg = g.index ? g.toNonIndexed() : g;
    var p = gg.attributes.position;
    for (var i = 0; i < p.count; i++) {
      var x = p.getX(i), y = p.getY(i), z = p.getZ(i);
      var k = 1 + (hash3(Math.round(x * 40), Math.round(y * 40), Math.round(z * 40)) - 0.5) * guc;
      p.setXYZ(i, x * k, y * k, z * k);
    }
    gg.computeVertexNormals();
    return gg;
  }

  // ---------- Arabalar ----------
  // Yan profil: x = arkadan öne uzunluk, y = yükseklik
  var PROFIL = {
    sedan:   { L: 4.45, W: 1.8, alt: 0.3, r: 0.33, teker: [0.95, 3.52], burun: 0.62, farY: 0.56, stopY: 0.72,
               arka: [[0, 0.42], [0, 0.8], [0.1, 0.93], [0.3, 0.99]], ust: [[1.12, 1.0], [3.02, 0.99], [3.8, 0.92]],
               kabin: [[1.12, 1.0], [1.78, 1.43], [2.62, 1.45], [3.1, 0.99]] },
    hatch:   { L: 3.95, W: 1.76, alt: 0.3, r: 0.32, teker: [0.72, 3.18], burun: 0.62, farY: 0.56, stopY: 0.8,
               arka: [[0, 0.42], [0, 0.92], [0.03, 1.02]], ust: [[0.1, 1.03], [2.66, 1.0], [3.38, 0.92]],
               kabin: [[0.1, 1.02], [0.32, 1.47], [2.05, 1.48], [2.66, 1.0]] },
    suv:     { L: 4.6, W: 1.9, alt: 0.38, r: 0.38, teker: [0.95, 3.68], burun: 0.8, farY: 0.74, stopY: 0.94,
               arka: [[0, 0.5], [0, 1.05], [0.06, 1.13]], ust: [[0.14, 1.14], [3.35, 1.12], [4.1, 1.05]],
               kabin: [[0.14, 1.13], [0.3, 1.73], [3.0, 1.75], [3.45, 1.12]] },
    minibus: { L: 4.6, W: 1.95, alt: 0.36, r: 0.36, teker: [0.9, 3.75], burun: 0.72, farY: 0.66, stopY: 0.98,
               arka: [[0, 0.46], [0, 1.12]], ust: [[0.04, 1.16], [3.95, 1.14], [4.35, 1.0]],
               kabin: [[0.05, 1.15], [0.1, 2.02], [3.75, 2.05], [4.28, 1.15]] },
    cip:     { L: 4.3, W: 1.9, alt: 0.46, r: 0.42, teker: [0.85, 3.45], burun: 0.88, farY: 0.82, stopY: 0.94,
               arka: [[0, 0.55], [0, 1.08]], ust: [[0.04, 1.1], [3.25, 1.1], [3.95, 1.04]],
               kabin: [[0.05, 1.09], [0.12, 1.74], [2.95, 1.76], [3.22, 1.09]] }
  };
  // Canlı oyuncak boyaları
  var BOYALAR = [0xff4747, 0x2f8fff, 0x2ec46b, 0xff9a1f, 0x9b5cff, 0x18c3c3, 0xff6fb5, 0xf6f6f2];

  function govdeSekli(p) {
    var s = new T.Shape(), a = p.alt, R = p.r + 0.07;
    s.moveTo(0.02, a);
    p.arka.forEach(function (q) { s.lineTo(q[0], q[1]); });
    p.ust.forEach(function (q) { s.lineTo(q[0], q[1]); });
    var son = p.ust[p.ust.length - 1];
    s.quadraticCurveTo(p.L, son[1], p.L, p.burun);
    s.lineTo(p.L - 0.02, a);
    s.lineTo(p.teker[1] + R, a);
    s.absarc(p.teker[1], a, R, 0, Math.PI, false);
    s.lineTo(p.teker[0] + R, a);
    s.absarc(p.teker[0], a, R, 0, Math.PI, false);
    s.lineTo(0.02, a);
    return s;
  }
  function cokgenSekli(k) {
    var s = new T.Shape();
    s.moveTo(k[0][0], k[0][1]);
    for (var i = 1; i < k.length; i++) s.lineTo(k[i][0], k[i][1]);
    s.lineTo(k[0][0], k[0][1]);
    return s;
  }
  function extr(shape, en, bevel) {
    var g = new T.ExtrudeGeometry(shape, { depth: Math.max(0.01, en - bevel * 2), bevelEnabled: true, bevelThickness: bevel, bevelSize: bevel, bevelOffset: -bevel, bevelSegments: 3, curveSegments: 12 });
    g.translate(0, 0, -(en - bevel * 2) / 2);
    return g;
  }
  // Profil uzayından araba uzayına: arka +z (kameraya), ön -z
  function yerlestir(g, L) { g.rotateY(Math.PI / 2); g.translate(0, 0, L / 2); return g; }

  // a -> b arasında uzanan eğik cam (ön/arka cam)
  function camPanel(e, a, b, en, L) {
    var dy = b[1] - a[1], za = L / 2 - a[0], zb = L / 2 - b[0];
    var uz = Math.hypot(zb - za, dy), th = Math.atan2(zb - za, dy), s = Math.sin(th), c = Math.cos(th);
    var ny, nz;
    if (-s > 0) { ny = -s; nz = c; } else { ny = s; nz = -c; }
    var m = new T.Mesh(new T.PlaneGeometry(en, uz), cam());
    m.rotation.x = th;
    m.position.set(0, (a[1] + b[1]) / 2 + ny * 0.012, (za + zb) / 2 + nz * 0.012);
    e.add(m);
  }
  function yanCam(e, pts, x, L) {
    var g = new T.ShapeGeometry(cokgenSekli(pts));
    g.rotateY(Math.PI / 2); g.translate(x, 0, L / 2);
    e.add(new T.Mesh(g, cam()));
  }

  var tekerC = {};
  function teker(r) {
    if (!tekerC[r]) {
      var gp = new T.Group();
      var l = new T.CylinderGeometry(r, r, 0.23, 26); l.rotateZ(Math.PI / 2); ekle(gp, l, std(0x18181a, 0.9, 0));
      var j = new T.CylinderGeometry(r * 0.64, r * 0.64, 0.236, 22); j.rotateZ(Math.PI / 2); ekle(gp, j, std(0x9ba1a9, 0.3, 0.9));
      var ic = new T.CylinderGeometry(r * 0.5, r * 0.5, 0.242, 22); ic.rotateZ(Math.PI / 2); ekle(gp, ic, std(0x18181a, 0.9, 0));
      for (var i = 0; i < 5; i++) { var k = ekle(gp, new T.BoxGeometry(0.246, r * 0.98, 0.065), std(0xcfd2d8, 0.22, 1)); k.rotation.x = i / 5 * Math.PI; k.material = std(0x9ba1a9, 0.3, 0.9); }
      var gb = new T.CylinderGeometry(r * 0.15, r * 0.15, 0.25, 12); gb.rotateZ(Math.PI / 2); ekle(gp, gb, std(0x9ba1a9, 0.3, 0.9));
      tekerC[r] = birlestirMat(gp);
    }
    return tekerC[r].clone();
  }

  /* tip: sedan | hatch | suv | taksi | minibus | cip ; durum: fren | ileri | gelen | park */
  function araba(tip, renk, durum) {
    var p = PROFIL[tip === 'taksi' ? 'sedan' : tip] || PROFIL.sedan;
    var L = p.L, W = p.W, k = p.kabin, parca = new T.Group();
    var boya = tip === 'cip' ? std(renk, 0.62, 0.12) : boyaMat(renk);
    var siyah = std(0x141518, 0.55, 0.15), plastik = std(0x2b2d32, 0.8, 0), krom = std(0xd9dce1, 0.18, 1);
    ekle(parca, yerlestir(extr(govdeSekli(p), W, 0.07), L), boya);
    var Wc = W - 0.18;
    ekle(parca, yerlestir(extr(cokgenSekli(k), Wc, 0.045), L), boya);
    camPanel(parca, k[3], k[2], Wc - 0.14, L);
    camPanel(parca, k[0], k[1], Wc - 0.18, L);

    var y0 = k[0][1] + 0.07, ust = Math.min(k[1][1], k[2][1]) - 0.07, orta = (k[1][0] + k[2][0]) / 2;
    var P1 = [k[0][0] + (k[1][0] - k[0][0]) * 0.15 + 0.1, y0], P2 = [k[0][0] + (k[1][0] - k[0][0]) * 0.88 + 0.06, ust];
    var Q1 = [k[3][0] - (k[3][0] - k[2][0]) * 0.15 - 0.12, y0], Q2 = [k[3][0] - (k[3][0] - k[2][0]) * 0.88 - 0.06, ust];
    var R = p.r + 0.07, etekBoy = (p.teker[1] - R) - (p.teker[0] + R), etekZ = L / 2 - (p.teker[0] + p.teker[1]) / 2;
    [-1, 1].forEach(function (yon) {
      var x = yon * (Wc / 2 + 0.006);
      yanCam(parca, [P1, P2, [orta - 0.05, ust], [orta - 0.05, y0]], x, L);
      yanCam(parca, [[orta + 0.05, y0], [orta + 0.05, ust], Q2, Q1], x, L);
      ekle(parca, kutu(0.035, 0.035, 0.15), krom, yon * (W / 2 - 0.004), k[0][1] - 0.12, L / 2 - orta + 0.45);
      ekle(parca, kutu(0.035, 0.035, 0.15), krom, yon * (W / 2 - 0.004), k[0][1] - 0.12, L / 2 - orta - 0.5);
      ekle(parca, kutu(0.14, 0.1, 0.17), boya, yon * (Wc / 2 + 0.1), k[3][1] + 0.08, L / 2 - k[3][0] + 0.3);
      ekle(parca, kutu(0.03, 0.1, etekBoy), siyah, yon * (W / 2 - 0.01), p.alt + 0.06, etekZ);
      ekle(parca, kutu(0.34, 0.12, 0.08), isik(0xfff3d8, durum === 'gelen' ? 2.8 : 0.5), yon * (W / 2 - 0.32), p.farY, -L / 2 + 0.035);
      ekle(parca, kutu(0.34, 0.13, 0.06), isik(0xff1f1f, durum === 'fren' ? 3.2 : 0.75), yon * (W / 2 - 0.26), p.stopY, L / 2 - 0.012);
    });
    ekle(parca, kutu(W - 0.9, 0.15, 0.06), siyah, 0, p.farY - 0.02, -L / 2 + 0.02);
    ekle(parca, kutu(W - 0.04, 0.2, 0.2), plastik, 0, p.alt + 0.1, -L / 2 + 0.08);
    ekle(parca, kutu(W - 0.04, 0.2, 0.2), plastik, 0, p.alt + 0.1, L / 2 - 0.08);
    plaka(parca, '07 TRK 07', '#ffffff', '#1c2023', 0.52, 0.12, 0, p.alt + 0.12, L / 2 + 0.022, 0);
    plaka(parca, '07 TRK 07', '#ffffff', '#1c2023', 0.52, 0.12, 0, p.alt + 0.12, -L / 2 - 0.022, Math.PI);
    var eg = new T.CylinderGeometry(0.04, 0.04, 0.16, 10); eg.rotateX(Math.PI / 2);
    ekle(parca, eg, krom, -(W / 2 - 0.38), p.alt + 0.02, L / 2 + 0.02);

    var tavan = Math.max(k[1][1], k[2][1]), tz = L / 2 - orta;
    if (tip === 'taksi') {
      ekle(parca, kutu(0.6, 0.17, 0.24), isik(0xffd000, 0.9), 0, tavan + 0.11, tz);
      plaka(parca, 'TAKSİ', '#1c2023', '#ffd000', 0.5, 0.12, 0, tavan + 0.11, tz + 0.122, 0);
      plaka(parca, 'TAKSİ', '#1c2023', '#ffd000', 0.5, 0.12, 0, tavan + 0.11, tz - 0.122, Math.PI);
      [-1, 1].forEach(function (yon) {
        var c = new T.Mesh(new T.PlaneGeometry(L - 1.7, 0.1), damaMat());
        c.position.set(yon * (W / 2 + 0.003), k[0][1] - 0.24, etekZ); c.rotation.y = yon * Math.PI / 2; parca.add(c);
      });
    } else if (tip === 'minibus') {
      [-1, 1].forEach(function (yon) {
        logoPlaka(parca, '#1c2023', 2.4, 0.42, 'Berber Kuaför Çağır', yon * (W / 2 + 0.004), 0.8, etekZ, yon * Math.PI / 2);
        ekle(parca, kutu(0.012, 0.08, L - 0.7), std(0xf2b705, 0.35, 0.3), yon * (W / 2 + 0.002), 0.57, 0);
      });
    } else if (tip === 'cip') {
      var lastikG = new T.CylinderGeometry(0.36, 0.36, 0.22, 22); lastikG.rotateX(Math.PI / 2);
      ekle(parca, lastikG, std(0x18181a, 0.9, 0), 0, 0.85, L / 2 + 0.13);
      var jantG = new T.CylinderGeometry(0.22, 0.22, 0.23, 18); jantG.rotateX(Math.PI / 2);
      ekle(parca, jantG, std(0x6b6e74, 0.4, 0.7), 0, 0.85, L / 2 + 0.13);
      for (var r = 0; r < 4; r++) ekle(parca, kutu(Wc - 0.1, 0.04, 0.05), siyah, 0, tavan + 0.12, tz - 1.0 + r * 0.66);
      [-1, 1].forEach(function (yon) {
        ekle(parca, kutu(0.05, 0.05, 2.1), siyah, yon * (Wc / 2 - 0.05), tavan + 0.08, tz);
        plaka(parca, 'SAFARİ', '#00000000', '#3b2a14', 1.3, 0.28, yon * (W / 2 + 0.004), 0.84, etekZ, yon * Math.PI / 2);
        ekle(parca, kutu(0.06, 0.5, 0.06), krom, yon * 0.55, p.alt + 0.42, -L / 2 - 0.12);
      });
      ekle(parca, kutu(1.25, 0.06, 0.06), krom, 0, p.alt + 0.62, -L / 2 - 0.12);
      ekle(parca, kutu(1.25, 0.06, 0.06), krom, 0, p.alt + 0.3, -L / 2 - 0.12);
    }
    var gp = new T.PlaneGeometry(W + 0.3, L + 0.35); gp.rotateX(-Math.PI / 2);
    ekle(parca, gp, golgeMat(), 0, 0.015, 0);

    var kok = new T.Group();
    kok.add(birlestirMat(parca));
    var tekerler = [];
    p.teker.forEach(function (tzz) {
      [-1, 1].forEach(function (yon) {
        var t = teker(p.r); t.position.set(yon * (W / 2 - 0.12), p.r, L / 2 - tzz); kok.add(t); tekerler.push(t);
      });
    });
    kok.userData.tekerler = tekerler; kok.userData.r = p.r;
    return kok;
  }

  // Tır: dorse kameraya bakar (arka kapılar), kabin ileride
  function kamyon(boy) {
    var p = new T.Group(), W = 2.05, dorse = boy - 2.7, arka = boy / 2;
    var beyaz = std(0x23262d, 0.4, 0.2), sari = std(0xffc400, 0.3, 0.3), siyah = std(0x151619, 0.7, 0.1);
    ekle(p, new T.RoundedBoxGeometry(W, 2.55, dorse, 3, 0.14), beyaz, 0, 2.3, arka - dorse / 2);
    ekle(p, kutu(W + 0.02, 0.3, dorse), sari, 0, 1.18, arka - dorse / 2);
    ekle(p, kutu(1.2, 0.3, boy - 0.4), siyah, 0, 0.82, 0);
    logoPlaka(p, '#23262d', W - 0.3, 1.5, 'Berber Kuaför Çağır', 0, 2.35, arka + 0.006, 0);
    ekle(p, kutu(0.03, 2.4, 0.02), siyah, 0, 2.3, arka + 0.012);
    [-1, 1].forEach(function (yon) {
      ekle(p, kutu(0.3, 0.12, 0.05), isik(0xff2a2a, 1.3), yon * (W / 2 - 0.25), 0.95, arka + 0.02);
      logoPlaka(p, '#23262d', Math.min(dorse * 0.8, 4.2), 1.5, 'Tarak Mobil · Berber Kuaför Çağır', yon * (W / 2 + 0.006), 2.4, arka - dorse / 2, yon * Math.PI / 2);
      ekle(p, kutu(0.02, 0.55, 0.8), cam(), yon * (W / 2 + 0.003), 2.62, -arka + 1.0);
      ekle(p, kutu(0.3, 0.14, 0.06), isik(0xfff3d8, 1.4), yon * (W / 2 - 0.3), 1.05, -arka + 0.12);
    });
    ekle(p, kutu(W - 0.2, 0.12, 0.12), siyah, 0, 0.55, arka - 0.1);
    var kz = -arka + 1.25;
    ekle(p, new T.RoundedBoxGeometry(W, 1.6, 2.3, 3, 0.16), sari, 0, 1.55, kz + 0.05);
    ekle(p, new T.RoundedBoxGeometry(W - 0.04, 0.75, 1.9, 3, 0.16), sari, 0, 2.72, kz + 0.25);
    ekle(p, kutu(W - 0.2, 0.68, 0.05), cam(), 0, 2.66, kz - 0.72);
    ekle(p, kutu(W - 0.6, 0.6, 0.06), siyah, 0, 1.35, kz - 1.12);
    ekle(p, kutu(W, 0.22, 0.2), siyah, 0, 0.78, kz - 1.12);
    var kok = new T.Group();
    kok.add(birlestirMat(p));
    var tekerler = [], r = 0.5;
    [[arka - 1.0, [W / 2 - 0.16, W / 2 - 0.42]], [arka - 2.3, [W / 2 - 0.16, W / 2 - 0.42]], [kz - 0.3, [W / 2 - 0.16]]].forEach(function (aks) {
      aks[1].forEach(function (xx) {
        [-1, 1].forEach(function (yon) { var t = teker(r); t.position.set(yon * xx, r, aks[0]); kok.add(t); tekerler.push(t); });
      });
    });
    kok.userData.tekerler = tekerler; kok.userData.r = r;
    return kok;
  }

  // ---------- Aslan ----------
  function aslan(disi) {
    var kurk = kurkMat(0xdba25a), acik = kurkMat(0xf2d29c), koyu = std(0x231710, 0.7, 0);
    var yele1 = kurkMat(0x7c4319), yele2 = kurkMat(0xab6026), goz = std(0x1a120a, 0.3, 0), agizM = std(0x7a1f1a, 0.6, 0);
    var kok = new T.Group();
    var govde = new T.Group(); govde.position.y = 0.92; kok.add(govde);
    var tp = new T.Group(), en = disi ? 0.86 : 1;
    var tg = new T.CapsuleGeometry(0.36, 1.0, 6, 14); tg.rotateX(Math.PI / 2);
    ekle(tp, tg, kurk).scale.set(en, 0.98, 1);
    ekle(tp, kure(0.4, 16), kurk, 0, 0.04, -0.52).scale.set(en, 1, 1);
    ekle(tp, kure(0.38, 16), kurk, 0, 0.02, 0.55).scale.set(en, 1, 1);
    var gb = new T.CapsuleGeometry(0.27, 0.8, 4, 10); gb.rotateX(Math.PI / 2);
    ekle(tp, gb, acik, 0, -0.14, 0).scale.set(en, 1, 1);
    if (!disi) ekle(tp, puruzlu(new T.IcosahedronGeometry(0.5, 2), 0.35), yele1, 0, 0.12, -0.62).scale.set(1, 1.05, 0.85);
    govde.add(birlestirMat(tp));

    var bas = new T.Group(); bas.position.set(0, 0.3, -0.98); govde.add(bas);
    var bp = new T.Group();
    if (!disi) ekle(bp, puruzlu(new T.IcosahedronGeometry(0.47, 2), 0.42), yele2, 0, 0.02, 0.1).scale.set(1.05, 1.1, 0.75);
    ekle(bp, kure(0.25, 16), kurk, 0, 0, -0.08).scale.set(1, 0.95, 1.05);
    ekle(bp, kure(0.15, 12), acik, 0, -0.08, -0.29).scale.set(1.1, 0.75, 1.05);
    ekle(bp, kure(0.055, 8), koyu, 0, -0.02, -0.43).scale.set(1.3, 0.8, 0.8);
    [-1, 1].forEach(function (yon) {
      ekle(bp, kure(0.035, 8), goz, yon * 0.1, 0.07, -0.27);
      ekle(bp, kure(0.075, 10), kurk, yon * 0.17, 0.2, -0.02).scale.set(1, 1, 0.45);
    });
    bas.add(birlestirMat(bp));
    var cene = new T.Group(); cene.position.set(0, -0.13, -0.18); bas.add(cene);
    var cp = new T.Group();
    ekle(cp, kure(0.12, 10), acik, 0, -0.02, -0.12).scale.set(1, 0.5, 1.15);
    ekle(cp, kure(0.09, 10), agizM, 0, 0.03, -0.12).scale.set(1, 0.4, 1.1);
    cene.add(birlestirMat(cp));

    var bacaklar = [[-0.2, -0.6], [0.2, -0.6], [-0.2, 0.6], [0.2, 0.6]].map(function (q, i) {
      var kalca = new T.Group(); kalca.position.set(q[0] * en, -0.12, q[1]); govde.add(kalca);
      var lp = new T.Group(); ekle(lp, kapsul(0.12, 0.34), kurk, 0, -0.2, 0); kalca.add(birlestirMat(lp));
      var diz = new T.Group(); diz.position.y = -0.42; kalca.add(diz);
      var dp = new T.Group();
      ekle(dp, kapsul(0.085, 0.24), kurk, 0, -0.15, 0);
      ekle(dp, kure(0.11, 10), acik, 0, -0.33, -0.04).scale.set(1, 0.55, 1.25);
      diz.add(birlestirMat(dp));
      return { kalca: kalca, diz: diz, on: q[1] < 0, faz: [0, Math.PI, Math.PI, 0][i] };
    });

    var kuyruk = new T.Group(); kuyruk.position.set(0, 0.1, 0.88); govde.add(kuyruk);
    var kp = new T.Group();
    var egri = new T.CatmullRomCurve3([new T.Vector3(0, 0, 0), new T.Vector3(0, -0.15, 0.25), new T.Vector3(0, -0.45, 0.4), new T.Vector3(0, -0.6, 0.62)]);
    ekle(kp, new T.TubeGeometry(egri, 12, 0.035, 6, false), kurk);
    ekle(kp, puruzlu(new T.IcosahedronGeometry(0.08, 1), 0.4), koyu, 0, -0.62, 0.66);
    kuyruk.add(birlestirMat(kp));

    /* poz: yuru | kos | yat | otur | kukre */
    function guncelle(poz, faz) {
      govde.rotation.set(0, 0, 0); bas.rotation.set(0, 0, 0); cene.rotation.x = 0;
      kuyruk.rotation.set(0.2, Math.sin(faz * 0.6) * 0.35, 0);
      if (poz === 'yuru' || poz === 'kos') {
        var genlik = poz === 'kos' ? 0.75 : 0.42;
        govde.position.y = 0.92 + Math.abs(Math.cos(faz)) * (poz === 'kos' ? 0.06 : 0.02);
        bacaklar.forEach(function (b) {
          var a = Math.sin(faz + b.faz);
          b.kalca.rotation.x = a * genlik;
          b.diz.rotation.x = (b.on ? 1 : -1) * Math.max(0, -a) * genlik * 1.1;
        });
        bas.rotation.x = Math.sin(faz * 2) * 0.04;
      } else if (poz === 'yat') {
        govde.position.y = 0.42;
        bacaklar.forEach(function (b) {
          if (b.on) { b.kalca.rotation.x = -1.45; b.diz.rotation.x = 0.1; } else { b.kalca.rotation.x = 1.1; b.diz.rotation.x = -2.0; }
        });
        kuyruk.rotation.set(1.1, Math.sin(faz * 0.5) * 0.4, 0);
        bas.rotation.y = Math.sin(faz * 0.25) * 0.35;
      } else {
        govde.position.y = 0.74; govde.rotation.x = 0.42;
        bacaklar.forEach(function (b) {
          if (b.on) { b.kalca.rotation.x = -0.42; b.diz.rotation.x = 0; } else { b.kalca.rotation.x = 0.9; b.diz.rotation.x = -1.9; }
        });
        if (poz === 'kukre') { bas.rotation.x = 0.35; cene.rotation.x = -0.45 - 0.12 * Math.sin(faz * 9); }
        else bas.rotation.y = Math.sin(faz * 0.3) * 0.4;
      }
    }
    guncelle('yuru', 0);
    return { kok: kok, guncelle: guncelle };
  }

  // ---------- Doğa parçaları (Lambert; sahnede tek geometriye birleştirilir) ----------
  function yaprak(r, guc) { return puruzlu(new T.IcosahedronGeometry(r, 1), guc || 0.35); }
  function agacYaprakli(o, renkler) {
    var g = new T.Group();
    ekle(g, silindir(0.16, 0.26, 2.6, 10), kabukMat(), 0, 1.3, 0);
    var dal = ekle(g, silindir(0.06, 0.1, 1.1, 6), kabukMat(), 0.35, 2.3, 0); dal.rotation.z = -0.7;
    [[0, 3.3, 0, 1.25], [0.75, 2.85, 0.3, 0.9], [-0.7, 2.9, -0.25, 0.95], [0.1, 3.95, -0.2, 0.8]].forEach(function (q, i) {
      ekle(g, yaprak(q[3]), lam(renkler[i % renkler.length]), q[0], q[1], q[2]);
    });
    g.scale.setScalar(o);
    return g;
  }
  function agacCam(o, renkler) {
    var g = new T.Group();
    ekle(g, silindir(0.14, 0.22, 1.6, 10), kabukMat(), 0, 0.8, 0);
    for (var k = 0; k < 4; k++) ekle(g, puruzlu(new T.ConeGeometry(1.45 - k * 0.3, 1.5, 9, 2), 0.18), lam(renkler[k % renkler.length]), 0, 1.7 + k * 0.85, 0);
    g.scale.setScalar(o);
    return g;
  }
  function akasya(o) {
    var g = new T.Group(), gv = lam(0x3d2418);
    ekle(g, silindir(0.12, 0.22, 2.6, 7), gv, 0, 1.3, 0).rotation.z = 0.08;
    var d1 = ekle(g, silindir(0.06, 0.1, 1.3, 6), gv, -0.45, 2.85, 0); d1.rotation.z = 0.75;
    var d2 = ekle(g, silindir(0.06, 0.1, 1.3, 6), gv, 0.5, 2.95, 0.1); d2.rotation.z = -0.7;
    [[-0.9, 3.35, 0, 1.4, 0x5c6b28], [0.9, 3.5, 0.2, 1.2, 0x6b7a30], [0, 3.7, -0.3, 1.0, 0x55642a]].forEach(function (q) {
      ekle(g, yaprak(q[3], 0.3), lam(q[4]), q[0], q[1], q[2]).scale.set(1.35, 0.32, 1.1);
    });
    g.scale.setScalar(o);
    return g;
  }
  function kaya(o, renk) {
    var m = new T.Mesh(puruzlu(new T.IcosahedronGeometry(0.7, 1), 0.45), lam(renk));
    m.scale.set(o * 1.25, o * 0.75, o); m.position.y = 0.2 * o;
    return m;
  }
  function cali(o, renk) {
    var m = new T.Mesh(yaprak(0.6, 0.4), lam(renk));
    m.scale.set(o * 1.2, o * 0.8, o); m.position.y = 0.35 * o;
    return m;
  }
  function cimTutam(renk, o) {
    var g = new T.Group();
    for (var i = 0; i < 6; i++) {
      var c = ekle(g, silindir(0.0, 0.035, 0.45 + (i % 3) * 0.12, 4), lam(renk), (i - 2.5) * 0.06, 0.25, (i % 2) * 0.05);
      c.rotation.z = (i - 2.5) * 0.14;
    }
    g.scale.setScalar(o || 1);
    return g;
  }

  window.TarakModel = {
    std: std, isik: isik, lam: lam, cam: cam, kutu: kutu, silindir: silindir, kure: kure, ekle: ekle,
    tuvalDoku: tuvalDoku, yaziMat: yaziMat, plaka: plaka, logoMat: logoMat, logoPlaka: logoPlaka, birlestirMat: birlestirMat, puruzlu: puruzlu,
    kabukMat: kabukMat, araba: araba, kamyon: kamyon, aslan: aslan, agacYaprakli: agacYaprakli, agacCam: agacCam, akasya: akasya,
    kaya: kaya, cali: cali, cimTutam: cimTutam, BOYALAR: BOYALAR
  };
})();
