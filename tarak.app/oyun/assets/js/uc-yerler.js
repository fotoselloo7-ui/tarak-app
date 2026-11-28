/* Türkiye'nin şehir ve mahallelerine özgü 3D öğeler: ufuktaki simgeler (Galata Kulesi, Saat Kulesi, Atakule…),
 * sahil/göl kenarı, peri bacaları, sıcak hava balonları, tramvay ve lacivert cadde tabelaları.
 * Gerçek yapıların oyunun çizgi film tarzında, kodla üretilmiş sadeleştirilmiş halleridir. */
(function () {
  'use strict';
  var T = window.THREE, MD = window.TarakModel;
  var mc = {};
  // Uzak simgeler sisten etkilenmez (ufukta net görünsün); hafif mat
  function um(renk, ek) {
    var k = renk + '|' + JSON.stringify(ek || {});
    if (!mc[k]) { var o = { color: renk, roughness: 0.75, metalness: 0, fog: false }; for (var a in ek) o[a] = ek[a]; mc[k] = new T.MeshStandardMaterial(o); }
    return mc[k];
  }
  function m(renk, ek) {   // yakın öğeler (sisli)
    var k = 'y' + renk + '|' + JSON.stringify(ek || {});
    if (!mc[k]) { var o = { color: renk, roughness: 0.7, metalness: 0 }; for (var a in ek) o[a] = ek[a]; mc[k] = new T.MeshStandardMaterial(o); }
    return mc[k];
  }
  function ek(g, geo, mat, x, y, z) { var o = new T.Mesh(geo, mat); o.position.set(x || 0, y || 0, z || 0); g.add(o); return o; }
  function sil(r1, r2, h, n) { return new T.CylinderGeometry(r1, r2, h, n || 16); }
  function kut(w, h, d) { return new T.BoxGeometry(w, h, d); }
  function kur(r, n) { return new T.SphereGeometry(r, n || 16, Math.max(8, (n || 16) - 4)); }
  function yarimKure(r) { return new T.SphereGeometry(r, 20, 10, 0, Math.PI * 2, 0, Math.PI / 2); }

  var TAS = 0xe9dcc2, KURSUN = 0x7d8a96, BEYAZ = 0xf4f1ea;

  function minare(g, x, z, h, renk, r) {
    r = r || 0.7;
    ek(g, sil(r * 1.25, r * 1.4, 2, 12), um(renk), x, 1, z);
    ek(g, sil(r, r * 1.1, h, 12), um(renk), x, h / 2 + 2, z);
    [0.62, 0.86].forEach(function (k) { ek(g, sil(r * 1.6, r * 1.2, 0.6, 12), um(renk), x, 2 + h * k, z); });
    ek(g, sil(r * 0.8, r * 0.8, 2.4, 12), um(renk), x, h + 3.2, z);
    ek(g, new T.ConeGeometry(r * 1.05, r * 6, 12), um(KURSUN), x, h + 4.4 + r * 3, z);
  }
  function kubbe(g, x, y, z, r, renk) { ek(g, sil(r, r, r * 0.35, 20), um(renk || TAS), x, y, z); ek(g, yarimKure(r), um(KURSUN), x, y + r * 0.17, z); ek(g, sil(0.12, 0.12, r * 0.5, 6), um(0xd9b44a, { metalness: 0.6 }), x, y + r * 1.2, z); }

  // ---------- Ufuktaki simgeler ----------
  var SIMGE = {
    galata: function (g) {   // Galata Kulesi
      ek(g, sil(5.2, 5.6, 6, 24), um(0xcdb48c), 0, 3, 0);
      ek(g, sil(4.4, 4.8, 30, 24), um(0xd9c39a), 0, 21, 0);
      for (var i = 0; i < 4; i++) ek(g, sil(4.55, 4.55, 0.5, 24), um(0xbfa47a), 0, 10 + i * 6, 0);
      ek(g, sil(5.4, 5.4, 1, 24), um(0xbfa47a), 0, 36.5, 0);
      ek(g, sil(4.3, 4.3, 4, 24), um(0xe6d6b4), 0, 39, 0);
      ek(g, new T.ConeGeometry(5, 13, 24), um(0x5a6774), 0, 47.5, 0);
      ek(g, sil(0.12, 0.12, 4, 6), um(0xd9b44a), 0, 55.5, 0);
    },
    kizkulesi: function (g) {   // Kız Kulesi (denizin içinde)
      var ada = ek(g, kur(9, 14), um(0x8a8270), 0, -5.5, 0); ada.scale.set(1.4, 0.75, 1);
      ek(g, kut(12, 5, 9), um(BEYAZ), 0, 2.5, 0);
      ek(g, sil(2.6, 2.8, 14, 16), um(BEYAZ), 1.5, 9, 0);
      ek(g, sil(3, 3, 0.6, 16), um(0xcfc8b8), 1.5, 16, 0);
      ek(g, yarimKure(2.4), um(KURSUN), 1.5, 16.4, 0);
      ek(g, sil(0.25, 0.25, 3, 6), um(0xd9b44a), 1.5, 20, 0);
      ek(g, kur(0.6, 8), um(0xfff3a0, { emissive: 0xfff3a0, emissiveIntensity: 1.5 }), 1.5, 21.6, 0);
    },
    saatkulesi: function (g) {   // İzmir Saat Kulesi
      ek(g, sil(5, 5.4, 2, 8), um(0xe8dcc6), 0, 1, 0);
      ek(g, sil(3.2, 3.6, 9, 8), um(0xf2e8d4), 0, 6.5, 0);
      ek(g, sil(2.7, 3, 7, 8), um(0xf2e8d4), 0, 14.5, 0);
      ek(g, sil(2.2, 2.5, 6, 8), um(0xf2e8d4), 0, 21, 0);
      for (var i = 0; i < 4; i++) { var a = i * Math.PI / 2, s = ek(g, new T.CircleGeometry(1.3, 20), um(0xffffff, { emissive: 0xffffff, emissiveIntensity: 0.4, side: T.DoubleSide }), Math.sin(a) * 2.6, 21, Math.cos(a) * 2.6); s.rotation.y = a; }
      ek(g, yarimKure(2.3), um(0x6f8fa8), 0, 24, 0);
      ek(g, sil(0.12, 0.12, 3, 6), um(0xd9b44a), 0, 27, 0);
      [-1, 1].forEach(function (y) { [-1, 1].forEach(function (x) { ek(g, sil(0.5, 0.5, 9, 8), um(0xe0d2b8), x * 3.4, 6.5, y * 3.4); }); });
    },
    atakule: function (g) {   // Atakule
      ek(g, sil(5, 6, 6, 20), um(0xd7dbe0), 0, 3, 0);
      ek(g, sil(2.2, 2.6, 66, 16), um(0xeef0f2), 0, 39, 0);
      var top = ek(g, kur(7, 20), um(0x3f7fb8, { roughness: 0.2, metalness: 0.4 }), 0, 76, 0); top.scale.y = 0.75;
      ek(g, sil(7.4, 7.4, 1, 24), um(0xd7dbe0), 0, 74, 0);
      ek(g, sil(0.3, 0.5, 14, 6), um(0xd7dbe0), 0, 88, 0);
    },
    camlica: function (g) {   // Çamlıca Kulesi
      ek(g, sil(2.4, 6, 90, 16), um(0xf1f3f5), 0, 45, 0);
      for (var i = 0; i < 4; i++) ek(g, sil(4.2 - i * 0.4, 3.2 - i * 0.4, 6, 16), um(i % 2 ? 0x8fb8d8 : 0xf1f3f5, { roughness: 0.3 }), 0, 92 + i * 6, 0);
      ek(g, sil(0.4, 0.8, 28, 8), um(0xf1f3f5), 0, 130, 0);
    },
    cami: function (g) {   // Ulu cami silueti
      ek(g, kut(26, 10, 22), um(TAS), 0, 5, 0);
      kubbe(g, 0, 10, 0, 9);
      [-8, 8].forEach(function (x) { kubbe(g, x, 10, 7, 3.2); kubbe(g, x, 10, -7, 3.2); });
      [[-14, -12], [14, -12]].forEach(function (p) { minare(g, p[0], p[1], 30, TAS); });
    },
    ulucami: function (g) {   // Bursa Ulu Camii: 20 kubbe
      ek(g, kut(34, 10, 28), um(0xe2d4b6), 0, 5, 0);
      for (var x = 0; x < 5; x++) for (var z = 0; z < 4; z++) kubbe(g, -13.6 + x * 6.8, 10, -10.5 + z * 7, 2.9, 0xe2d4b6);
      [[-18, -15], [18, -15]].forEach(function (p) { minare(g, p[0], p[1], 32, 0xe2d4b6); });
      var dag = ek(g, kur(80, 18), um(0xe9eef3), 20, -40, -120); dag.scale.set(1.6, 0.9, 0.6);
    },
    mevlana: function (g) {   // Mevlana Türbesi: yivli turkuaz kubbe
      ek(g, kut(26, 9, 16), um(0xe6dcc8), 0, 4.5, 0);
      kubbe(g, -7, 9, 0, 4); kubbe(g, 0, 9, 0, 4);
      ek(g, sil(3.2, 3.4, 10, 16), um(0x2ea89a), 9, 14, 0);
      ek(g, new T.ConeGeometry(3.6, 9, 16), um(0x2ea89a), 9, 23.5, 0);
      for (var i = 0; i < 16; i++) { var a = i / 16 * Math.PI * 2; ek(g, kut(0.3, 10, 0.3), um(0x1f8a7e), 9 + Math.cos(a) * 3.35, 14, Math.sin(a) * 3.35); }
      minare(g, -14, -4, 26, 0xe6dcc8);
    },
    yivliminare: function (g) {   // Antalya Yivli Minare
      ek(g, kut(10, 6, 10), um(0xc98b5a), -6, 3, 0);
      kubbe(g, -6, 6, 0, 4, 0xc98b5a);
      ek(g, kut(6, 6, 6), um(0xd8b07a), 4, 3, 0);
      ek(g, sil(2.6, 3, 34, 16), um(0xb4552f), 4, 23, 0);
      for (var i = 0; i < 8; i++) { var a = i / 8 * Math.PI * 2; ek(g, kut(0.9, 34, 0.9), um(0xa24a26), 4 + Math.cos(a) * 2.7, 23, Math.sin(a) * 2.7); }
      ek(g, sil(3.6, 3, 1, 16), um(0xd8b07a), 4, 40, 0);
      ek(g, new T.ConeGeometry(2.2, 6, 12), um(KURSUN), 4, 44, 0);
    },
    ciftminare: function (g) {   // Erzurum Çifte Minareli Medrese
      ek(g, kut(20, 14, 8), um(0xb88d68), 0, 7, 0);
      ek(g, kut(7, 11, 1), um(0x8a6243), 0, 6, 4.2);
      [-7, 7].forEach(function (x) {
        ek(g, sil(2, 2.3, 26, 12), um(0xa5512f), x, 27, 0);
        for (var i = 0; i < 6; i++) ek(g, sil(2.05, 2.05, 0.6, 12), um(0x3f8fb0), x, 18 + i * 4, 0);
      });
    },
    balikligol: function (g) {   // Balıklıgöl: taş cami, havuz
      var su = ek(g, new T.PlaneGeometry(40, 14), um(0x3d8fb0, { roughness: 0.15, metalness: 0.2 }), 0, 0.3, 14); su.rotation.x = -Math.PI / 2;
      ek(g, kut(22, 8, 12), um(0xe2c79a), 0, 4, 0);
      kubbe(g, -5, 8, 0, 4, 0xe2c79a); kubbe(g, 5, 8, 0, 4, 0xe2c79a);
      minare(g, 12, -3, 24, 0xe2c79a);
      var tepe = ek(g, kur(30, 14), um(0xc9a46e), -10, -14, -30); tepe.scale.set(1.6, 1, 0.8);
    },
    uzungol: function (g) {   // Uzungöl: göl kenarında küçük cami, yeşil dağlar
      ek(g, kut(10, 6, 8), um(BEYAZ), 0, 3, 0);
      kubbe(g, 0, 6, 0, 3.4, BEYAZ);
      [-5, 5].forEach(function (x) { minare(g, x, -3, 16, BEYAZ, 0.45); });
      [[-40, 0.9], [30, 1.1], [0, 1.4]].forEach(function (p, i) { var d = ek(g, kur(45, 14), um([0x2f6f3a, 0x3d8044, 0x285c32][i]), p[0], -18, -60 - i * 20); d.scale.set(1, p[1], 0.8); });
    },
    kale: function (g) {   // Tepedeki kale (Gaziantep, Kars, Bodrum, Çeşme)
      var tepe = ek(g, kur(30, 16), um(0x9a8a62), 0, -16, 0); tepe.scale.set(1.5, 0.75, 1);
      ek(g, kut(40, 8, 3), um(0xc9b58c), 0, 9, 10);
      for (var i = 0; i < 14; i++) ek(g, kut(1.6, 1.6, 3), um(0xc9b58c), -19 + i * 2.9, 13.8, 10);
      [-20, 0, 20].forEach(function (x, j) {
        ek(g, kut(7, 18 + j % 2 * 6, 7), um(0xbfa97e), x, 9 + j % 2 * 3, 6);
        for (var c = 0; c < 4; c++) ek(g, kut(1.4, 1.6, 1.4), um(0xbfa97e), x - 2.6 + c * 1.75, 19 + j % 2 * 6, 2.6);
      });
      ek(g, sil(0.15, 0.15, 6, 6), um(0x555555), 0, 25, 6);
      var bayrak = ek(g, new T.PlaneGeometry(4, 2.6), um(0xe30a17, { side: T.DoubleSide }), 2, 26.5, 6);
      bayrak.userData.bayrak = true;
    },
    kopru: function (g) {   // Boğaziçi Köprüsü kuleleri ve ana kablolar
      [-16, 16].forEach(function (x) {
        [-1, 1].forEach(function (k) { ek(g, kut(2.6, 70, 2.6), um(0xd8dde2), x + k * 0, 35, k * 4); });
        [20, 45, 68].forEach(function (y) { ek(g, kut(2, 2, 8), um(0xd8dde2), x, y, 0); });
      });
      [-1, 1].forEach(function (k) {
        var e = new T.QuadraticBezierCurve3(new T.Vector3(-16 * k, 70, 4), new T.Vector3(-6 * k, 20, 60), new T.Vector3(-3.5 * k, 8, 120));
        ek(g, new T.TubeGeometry(e, 24, 0.5, 6, false), um(0xcfd5db));
      });
    },
    boga: function (g) {   // Kadıköy Boğası (Altıyol)
      ek(g, sil(7, 7.5, 3, 24), um(0xbfb6a6), 0, 1.5, 0);
      ek(g, sil(4, 4.4, 3, 20), um(0x9c9384), 0, 4.5, 0);
      var bronz = um(0x6b4a2a, { metalness: 0.6, roughness: 0.45 });
      var gov = ek(g, kur(3, 16), bronz, 0, 10, 0); gov.scale.set(1.9, 1.05, 1);
      var bas = ek(g, kur(1.6, 12), bronz, 5, 10.2, 0); bas.scale.set(1.2, 1, 0.9);
      [-1, 1].forEach(function (z) { var b = ek(g, new T.ConeGeometry(0.35, 2.2, 8), bronz, 5.6, 11.8, z * 1.1); b.rotation.z = -0.9; b.rotation.x = z * 0.5; });
      [[-3, -1], [-3, 1], [3, -1], [3, 1]].forEach(function (p) { ek(g, sil(0.55, 0.45, 3.5, 8), bronz, p[0], 7, p[1]); });
    },
    mardin: function (g) {   // Mardin: yamaçta basamak basamak taş evler ve Ulu Cami minaresi
      var tepe = ek(g, kur(50, 16), um(0xb79a6a), 0, -30, -20); tepe.scale.set(1.6, 0.8, 0.7);
      for (var k = 0; k < 5; k++) for (var i = 0; i < 9; i++) {
        var x = -36 + i * 9 + (k % 2) * 4, y = k * 6.5, z = -k * 7;
        ek(g, kut(8, 6, 6), um(k % 2 ? 0xe2c79a : 0xd7b884), x, y + 3, z);
        ek(g, kut(1.4, 2, 0.2), um(0x5a3b24), x, y + 2.4, z + 3.05);
      }
      minare(g, 6, -14, 26, 0xd7b884);
    },
    balon: function () { /* balonlar ayrı grup */ }
  };
  // Simgenin ufukta nerede duracağı: x kayması ve ölçek
  var YER = { galata: [3, 0.72], kizkulesi: [34, 1], saatkulesi: [-2, 1], atakule: [2, 1], camlica: [-3, 0.9], cami: [0, 1],
    ulucami: [0, 1], mevlana: [0, 1], yivliminare: [2, 1], ciftminare: [0, 1.1], balikligol: [0, 1], uzungol: [14, 1],
    kale: [0, 1.2], kopru: [0, 1], boga: [0, 0.55], mardin: [0, 1] };

  function simge(tip) {
    if (!SIMGE[tip] || tip === 'balon') return null;
    var g = new T.Group(); SIMGE[tip](g);
    var y = YER[tip] || [0, 1]; g.scale.setScalar(y[1]); g.userData.x = y[0];
    g.traverse(function (o) { if (o.isMesh) { o.castShadow = false; o.receiveShadow = false; } });
    return g;
  }

  // ---------- Sahil / göl kenarı (yol kenarı yuvası, yerel x: yola doğru eksi) ----------
  function palmiye(g, x, z, h) {
    var gov = m(0x8a6a44);
    for (var i = 0; i < 6; i++) ek(g, sil(0.16 - i * 0.012, 0.18 - i * 0.012, h / 6, 7), gov, x + Math.sin(i * 0.25) * 0.25, h / 12 + i * h / 6, z);
    for (var y = 0; y < 7; y++) {
      var a = y / 7 * Math.PI * 2, yp = ek(g, new T.ConeGeometry(0.22, 1.7, 4), m(0x2f9a3c), x + Math.cos(a) * 0.75, h + 0.05, z + Math.sin(a) * 0.75);
      yp.rotation.z = Math.cos(a) * 1.25; yp.rotation.x = -Math.sin(a) * 1.25; yp.scale.z = 0.3;
    }
  }
  function sahil(gol) {
    var g = new T.Group();
    var su = ek(g, new T.PlaneGeometry(46, 7.8), m(gol ? 0x2f86a8 : 0x2f8fd8, { roughness: 0.12, metalness: 0.25 }), 23.5, 0.04, 0); su.rotation.x = -Math.PI / 2;
    if (gol) {
      for (var i = 0; i < 6; i++) ek(g, sil(0.03, 0.04, 1.1, 4), m(0x6f8f3a), 0.4 + (i % 3) * 0.3, 0.3, -3 + i * 1.1);
      var kiyi = ek(g, new T.PlaneGeometry(1.4, 7.8), m(0x6aa83f), 0.7, 0.06, 0); kiyi.rotation.x = -Math.PI / 2;
    } else {
      for (var p = -3.5; p <= 3.5; p += 1) ek(g, kut(0.08, 0.9, 0.08), m(0xf2f2f0), 0.3, 0.45, p);
      ek(g, kut(0.1, 0.08, 7.8), m(0xf2f2f0), 0.3, 0.9, 0);
      palmiye(g, -0.9, 1.6, 4.6);
      ek(g, kut(0.5, 0.08, 1.6), m(0x9a6a3a), -0.6, 0.48, -2.2); ek(g, kut(0.08, 0.5, 1.6), m(0x9a6a3a), -0.35, 0.72, -2.2);
    }
    // uzakta karşı kıyı silueti
    var kiyi2 = ek(g, kur(18, 10), m(gol ? 0x2f6f3a : 0x6f8a6a), 44, -10, 0); kiyi2.scale.set(0.6, 0.8, 0.6);
    return g;
  }
  // Köprü: su + korkuluk + askı kabloları
  function kopruYuvasi() {
    var g = sahil(false);
    for (var z = -3; z <= 3; z += 3) ek(g, sil(0.05, 0.05, 9, 5), m(0xcfd5db), 0.1, 4.8, z);
    ek(g, kut(0.5, 0.5, 7.8), m(0xd8dde2), 0.1, 9.4, 0);
    return g;
  }

  // ---------- Peri bacaları ----------
  function periYuvasi(tohum) {
    var g = new T.Group(), ten = [0xd9b88a, 0xe2c69a, 0xcfa978];
    for (var i = 0; i < 4; i++) {
      var x = 2.5 + i * 2.6 + (tohum % 3), z = -3 + ((i * 37 + tohum * 11) % 7), h = 4 + ((i + tohum) % 3) * 2.2;
      ek(g, new T.ConeGeometry(1.1 + (i % 2) * 0.4, h, 10), m(ten[i % 3]), x, h / 2, z);
      var sapka = ek(g, kur(0.9, 10), m(0x8a6a4a), x, h + 0.1, z); sapka.scale.set(1.2, 0.6, 1.2);
      ek(g, new T.CircleGeometry(0.22, 10), m(0x3a2a1a), x - 1, h * 0.45, z).rotation.y = -Math.PI / 2;
    }
    return g;
  }

  // ---------- Sıcak hava balonları ----------
  function balonlar() {
    var g = new T.Group(), renk = [0xe30a17, 0xffc400, 0x2f8fff, 0xff6fa5, 0x23a35a, 0xff8a1f, 0x8d45d6, 0xffffff, 0x14a3a3, 0xd94f2a];
    for (var i = 0; i < 12; i++) {
      var b = new T.Group(), r = 2.4 + (i % 3) * 0.6;
      var top = ek(b, kur(r, 14), um(renk[i % renk.length], { roughness: 0.5 })); top.scale.y = 1.2;
      ek(b, new T.ConeGeometry(r * 0.7, r * 1.3, 12), um(renk[(i + 3) % renk.length]), 0, -r * 1.25, 0).rotation.x = Math.PI;
      ek(b, kut(r * 0.45, r * 0.35, r * 0.45), um(0x8a5a2a), 0, -r * 2.3, 0);
      b.position.set((i % 2 ? 1 : -1) * (14 + (i * 13) % 40), 22 + (i * 7) % 26, -40 - (i * 17) % 90);
      b.userData = { faz: i * 1.3, y0: b.position.y };
      g.add(b);
    }
    return g;
  }

  // ---------- Tramvay (nostaljik / modern) ----------
  function tramvay(boy, modern) {
    var g = new T.Group(), L = boy, W = 1.9;
    var alt = m(modern ? 0xffc400 : 0xc8102e, { roughness: 0.4 }), ust = m(modern ? 0xf4f4f2 : 0xf3e7cf, { roughness: 0.5 }), cam = m(0x1d3550, { roughness: 0.1, metalness: 0.3 });
    var gv = new T.Group(); gv.position.z = -L / 2; g.add(gv);
    ek(gv, new T.RoundedBoxGeometry(W, 1.2, L, 3, 0.2), alt, 0, 0.95, 0);
    ek(gv, new T.RoundedBoxGeometry(W, 1.3, L, 3, 0.2), ust, 0, 2.2, 0);
    ek(gv, new T.RoundedBoxGeometry(W + 0.04, 0.8, L - 0.8, 2, 0.1), cam, 0, 2.25, 0);
    ek(gv, new T.RoundedBoxGeometry(W - 0.2, 0.2, L - 0.4, 2, 0.08), alt, 0, 2.95, 0);
    ek(gv, kut(W - 0.5, 0.8, 0.04), cam, 0, 2.25, L / 2 + 0.01);
    ek(gv, kut(0.04, 1.4, 0.04), m(0x222222), 0, 3.7, 0);
    ek(gv, kut(1.2, 0.04, 0.04), m(0x222222), 0, 4.4, 0);
    [-0.6, 0.6].forEach(function (x) { ek(gv, kut(0.25, 0.15, 0.06), m(0xfff3d8, { emissive: 0xfff3d8, emissiveIntensity: 1.2 }), x, 0.8, L / 2 + 0.02); });
    var lev = MD.yaziMat(modern ? 'OTOGAR' : 'TÜNEL – TAKSİM', '#1c2023', '#ffc400', 1.4, 0.3);
    var p = new T.Mesh(new T.PlaneGeometry(1.4, 0.3), lev); p.position.set(0, 2.82, L / 2 + 0.02); gv.add(p);
    [-L / 2 + 0.9, L / 2 - 0.9].forEach(function (z) { [-1, 1].forEach(function (s) { var t = ek(gv, sil(0.32, 0.32, 0.15, 14), m(0x1c1c1c), s * 0.75, 0.32, z); t.rotation.z = Math.PI / 2; }); });
    g.userData.tekerler = []; g.userData.r = 0.32;
    return g;
  }

  // ---------- Lacivert cadde tabelası ----------
  var tabelaC = {};
  function tabela(metin) {
    var g = new T.Group();
    ek(g, sil(0.05, 0.06, 3.1, 8), m(0x3a3d45), 0, 1.55, 0);
    var mt = tabelaC[metin] || (tabelaC[metin] = new T.MeshBasicMaterial({ map: MD.tuvalDoku(512, 112, function (c, w, h) {
      c.fillStyle = '#ffffff'; c.fillRect(0, 0, w, h); c.fillStyle = '#123a8c'; c.fillRect(6, 6, w - 12, h - 12);
      c.fillStyle = '#ffffff'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.font = '800 46px system-ui, sans-serif'; c.fillText(metin, w / 2, h / 2 + 2, w - 40);
    }), side: T.DoubleSide, toneMapped: false }));
    var p = new T.Mesh(new T.PlaneGeometry(1.9, 0.42), mt); p.position.set(0, 3.0, 0); p.rotation.y = Math.PI / 2; g.add(p);
    return g;
  }

  window.TarakYerler = { simge: simge, sahil: sahil, kopruYuvasi: kopruYuvasi, periYuvasi: periYuvasi, balonlar: balonlar, tramvay: tramvay, tabela: tabela };
})();
