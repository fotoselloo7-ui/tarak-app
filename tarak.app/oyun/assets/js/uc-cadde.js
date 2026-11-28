/* OpenStreetMap'ten gelen gerçek cadde verisiyle 3D öğeler: dükkân tabelaları (gerçek tür ve yerel dükkân adı),
 * sokak ağızları (gerçek sokak adı), önemli yapılar (cami, park, okul, hastane, müze…).
 * Yuva yerel koordinatı: yol -x yönünde, bina alanı x 0.2..4.2, z -3.3..3.3.  Veri © OpenStreetMap katkıcıları (ODbL). */
(function () {
  'use strict';
  var T = window.THREE, MD = window.TarakModel, Y = window.TarakYerler;
  var mc = {};
  function m(renk, ek) { var k = renk + JSON.stringify(ek || {}); if (!mc[k]) { var o = { color: renk, roughness: 0.7, metalness: 0 }; for (var a in ek) o[a] = ek[a]; mc[k] = new T.MeshStandardMaterial(o); } return mc[k]; }
  function ek(g, geo, mat, x, y, z) { var o = new T.Mesh(geo, mat); o.position.set(x || 0, y || 0, z || 0); g.add(o); return o; }
  function kut(w, h, d) { return new T.BoxGeometry(w, h, d); }
  function sil(r1, r2, h, n) { return new T.CylinderGeometry(r1, r2, h, n || 14); }

  var TABELA = { berber: ['BERBER', '#1c2023'], guzellik: ['GÜZELLİK SALONU', '#c2185b'], firin: ['FIRIN', '#d9822b'], pastane: ['PASTANE', '#b5546e'],
    market: ['MARKET', '#2e8b57'], manav: ['MANAV', '#4c9a3f'], kasap: ['KASAP', '#b71c1c'], giyim: ['GİYİM', '#37474f'], ayakkabi: ['AYAKKABI', '#5d4037'],
    kuyumcu: ['KUYUMCU', '#8d6e00'], kitap: ['KİTABEVİ', '#283593'], kirtasiye: ['KIRTASİYE', '#3949ab'], telefon: ['TELEFON', '#1565c0'],
    elektronik: ['ELEKTRONİK', '#0d47a1'], cicekci: ['ÇİÇEKÇİ', '#689f38'], optik: ['OPTİK', '#00838f'], hirdavat: ['HIRDAVAT', '#6d4c41'],
    mobilya: ['MOBİLYA', '#795548'], bufe: ['BÜFE', '#ef6c00'], hediyelik: ['HEDİYELİK', '#8e24aa'], kozmetik: ['KOZMETİK', '#d81b60'], oto: ['OTO SERVİS', '#455a64'],
    cay: ['ÇAY EVİ', '#a0522d'], kahve: ['KAHVECİ', '#6d4c41'], terzi: ['TERZİ', '#5e35b1'], kundura: ['KUNDURACI', '#4e342e'], eczane: ['ECZANE', '#d32f2f'],
    banka: ['BANKA', '#1a237e'], kafe: ['KAFE', '#795548'], lokanta: ['LOKANTA', '#c62828'], dondurma: ['DONDURMA', '#ec407a'], ptt: ['PTT', '#f9a825'],
    karakol: ['POLİS', '#1565c0'], akaryakit: ['AKARYAKIT', '#e53935'], sinema: ['SİNEMA', '#311b92'], tiyatro: ['TİYATRO', '#4a148c'], dis: ['DİŞ HEKİMİ', '#0277bd'],
    saglik: ['SAĞLIK', '#00897b'], kutuphane: ['KÜTÜPHANE', '#283593'], pazar: ['PAZAR YERİ', '#f57f17'], otel: ['OTEL', '#004d40'], dukkan: ['DÜKKAN', '#455a64'] };
  var tabelaC = {};
  function dukkanTabelaMat(tur, ad) {
    var k = tur + '|' + (ad || '');
    if (tabelaC[k]) return tabelaC[k];
    var tb = TABELA[tur] || TABELA.dukkan;
    var d = MD.tuvalDoku(512, 90, function (c, w, h) {
      c.fillStyle = tb[1]; c.fillRect(0, 0, w, h);
      c.fillStyle = 'rgba(255,255,255,.18)'; c.fillRect(0, 0, w, 6);
      var x0 = 14;
      if (tur === 'eczane') { c.fillStyle = '#fff'; c.fillRect(10, 10, 70, 70); c.fillStyle = '#d32f2f'; c.font = '900 64px system-ui, sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText('E', 45, 48); x0 = 96; }
      c.textAlign = 'left'; c.textBaseline = 'middle'; c.fillStyle = '#ffffff';
      if (ad) {
        c.font = '900 34px system-ui, sans-serif'; c.fillText(ad.toLocaleUpperCase('tr-TR'), x0, 34, w - x0 - 12);
        c.font = '800 22px system-ui, sans-serif'; c.fillStyle = tur === 'ptt' ? '#1c2023' : '#ffd96a'; c.fillText(tb[0], x0, 70, w - x0 - 12);
      } else { c.font = '900 44px system-ui, sans-serif'; c.fillStyle = tur === 'ptt' ? '#1c2023' : '#ffffff'; c.fillText(tb[0], x0, 47, w - x0 - 12); }
    });
    return (tabelaC[k] = new T.MeshBasicMaterial({ map: d, toneMapped: false }));
  }
  // Çıkma tabela: cepheden yola doğru uzanır, koşucuya döner (iki yüzlü, iki yandan da düz okunur)
  var bayrakC = {};
  function bayrakMat(tur, ad) {
    var k = tur + '|' + (ad || '');
    if (bayrakC[k]) return bayrakC[k];
    var tb = TABELA[tur] || TABELA.dukkan;
    var d = MD.tuvalDoku(320, 160, function (c, w, h) {
      c.fillStyle = '#ffffff'; c.fillRect(0, 0, w, h);
      c.fillStyle = tb[1]; c.fillRect(6, 6, w - 12, h - 12);
      c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillStyle = tur === 'ptt' ? '#1c2023' : '#ffffff';
      if (ad) {
        c.font = '900 40px system-ui, sans-serif'; c.fillText(ad.toLocaleUpperCase('tr-TR'), w / 2, 62, w - 28);
        c.font = '800 28px system-ui, sans-serif'; c.fillStyle = tur === 'ptt' ? '#1c2023' : '#ffd96a'; c.fillText(tb[0], w / 2, 116, w - 28);
      } else { c.font = '900 50px system-ui, sans-serif'; c.fillText(tb[0], w / 2, h / 2 + 3, w - 28); }
    });
    return (bayrakC[k] = new T.MeshBasicMaterial({ map: d, toneMapped: false }));
  }
  var bosMat = null, tabelaGeo = null, bayrakGeo = null, kolGeo = null;
  function dukkanTabelasi(tur, ad) {
    var mt = tur ? dukkanTabelaMat(tur, ad) : (bosMat || (bosMat = new T.MeshStandardMaterial({ color: 0x3a3d45, roughness: 0.6 })));
    var p = new T.Mesh(tabelaGeo || (tabelaGeo = new T.PlaneGeometry(4.6, 0.8)), mt);
    p.position.set(0.07, 2.55, 0); p.rotation.y = -Math.PI / 2;
    if (!tur) return p;
    var g = new T.Group(); g.add(p);
    var bm = bayrakMat(tur, ad), bg = bayrakGeo || (bayrakGeo = new T.PlaneGeometry(2.0, 1.0));
    var on = new T.Mesh(bg, bm); on.position.set(-1.05, 3.55, 2.62); g.add(on);
    var arka = new T.Mesh(bg, bm); arka.position.set(-1.05, 3.55, 2.58); arka.rotation.y = Math.PI; g.add(arka);
    ek(g, kolGeo || (kolGeo = kut(2.2, 0.07, 0.07)), m(0x2b2e35, { metalness: 0.5 }), -0.95, 4.1, 2.6);
    return g;
  }

  var plakaC = {};
  function adPlakasi(metin, zemin) {
    var k = metin + zemin;
    var mt = plakaC[k] || (plakaC[k] = new T.MeshBasicMaterial({ toneMapped: false, map: MD.tuvalDoku(512, 96, function (c, w, h) {
      c.fillStyle = zemin; c.fillRect(0, 0, w, h); c.fillStyle = '#fff'; c.textAlign = 'center'; c.textBaseline = 'middle';
      c.font = '900 40px system-ui, sans-serif'; c.fillText(metin.toLocaleUpperCase('tr-TR'), w / 2, h / 2 + 2, w - 24);
    }) }));
    var p = new T.Mesh(new T.PlaneGeometry(3.6, 0.68), mt); p.rotation.y = -Math.PI / 2; return p;
  }

  var YAPI = {
    cami: function (g) {
      ek(g, kut(0.3, 1.0, 6.4), m(0xe8dcc4), 0.25, 0.5, 0);
      ek(g, kut(3.6, 3.4, 4.6), m(0xf0e6d2), 2.3, 1.7, -0.6);
      ek(g, sil(1.7, 1.7, 0.5, 20), m(0xe0d4bc), 2.3, 3.6, -0.6);
      ek(g, new T.SphereGeometry(1.65, 20, 10, 0, Math.PI * 2, 0, Math.PI / 2), m(0x7d8a96), 2.3, 3.85, -0.6);
      ek(g, sil(0.05, 0.05, 0.8, 6), m(0xd9b44a, { metalness: 0.6 }), 2.3, 5.8, -0.6);
      ek(g, sil(0.28, 0.32, 9.5, 12), m(0xf0e6d2), 1.0, 4.75, 2.4);
      ek(g, sil(0.45, 0.35, 0.3, 12), m(0xe0d4bc), 1.0, 7.4, 2.4);
      ek(g, new T.ConeGeometry(0.32, 1.6, 12), m(0x7d8a96), 1.0, 10.3, 2.4);
      return '#6f5a3a';
    },
    ibadet: function (g) {
      ek(g, kut(3.6, 4, 5), m(0xd9c9a8), 2.3, 2, -0.4);
      var cati = ek(g, new T.CylinderGeometry(2.0, 2.0, 5.1, 3), m(0x8a4a3a), 2.3, 4.6, -0.4); cati.rotation.x = Math.PI / 2; cati.rotation.y = Math.PI / 2; cati.scale.set(1, 1, 0.55);
      ek(g, kut(1.4, 7, 1.4), m(0xd9c9a8), 1.4, 3.5, 2.6); ek(g, new T.ConeGeometry(1.0, 2, 4), m(0x8a4a3a), 1.4, 8, 2.6);
      return '#6a4a3a';
    },
    park: function (g) {
      var cim = ek(g, new T.PlaneGeometry(4.2, 7.2), m(0x5aa83a), 2.2, 0.14, 0); cim.rotation.x = -Math.PI / 2;
      for (var z = -3; z <= 3; z += 1) ek(g, kut(0.06, 0.5, 0.06), m(0x2f4a2a), 0.15, 0.4, z);
      ek(g, kut(0.05, 0.05, 7), m(0x2f4a2a), 0.15, 0.62, 0);
      [[1.6, -2], [3.2, 1.5], [1.8, 2.4]].forEach(function (p, i) { var a = MD.agacYaprakli(0.75 + i * 0.1, [0x3f8a34, 0x4b9a3f, 0x356b32]); a.position.set(p[0], 0.14, p[1]); g.add(a); });
      ek(g, kut(0.45, 0.08, 1.6), m(0x9a6a3a), 0.9, 0.5, 0); ek(g, kut(0.08, 0.45, 1.6), m(0x9a6a3a), 1.1, 0.72, 0);
      return '#2f6a2a';
    },
    okul: function (g) {
      ek(g, kut(3.8, 7, 6.4), m(0xf2d38a), 2.3, 3.5, 0);
      for (var k = 0; k < 2; k++) ek(g, kut(0.05, 1.2, 5.6), m(0x2f6fae, { roughness: 0.2 }), 0.39, 2.4 + k * 2.8, 0);
      ek(g, sil(0.05, 0.05, 8, 6), m(0xcccccc), 0.4, 4, -3); var b = ek(g, new T.PlaneGeometry(1.4, 0.9), m(0xe30a17, { side: T.DoubleSide }), 0.4, 7.4, -2.25); b.rotation.y = Math.PI / 2;
      return '#8a6a1a';
    },
    hastane: function (g) {
      ek(g, kut(3.8, 10, 6.4), m(0xf4f6f8), 2.3, 5, 0);
      for (var k = 0; k < 3; k++) ek(g, kut(0.05, 1.1, 5.6), m(0x6aa0c8, { roughness: 0.2 }), 0.39, 2.4 + k * 2.7, 0);
      var h = MD.tuvalDoku(64, 64, function (c) { c.fillStyle = '#d32f2f'; c.fillRect(0, 0, 64, 64); c.fillStyle = '#fff'; c.font = '900 52px system-ui'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText('H', 32, 35); });
      var hp = ek(g, new T.PlaneGeometry(1.4, 1.4), new T.MeshBasicMaterial({ map: h, toneMapped: false }), 0.36, 9, 0); hp.rotation.y = -Math.PI / 2;
      return '#b71c1c';
    },
    muze: function (g) {
      ek(g, kut(3.6, 0.5, 6.6), m(0xe8e2d4), 2.2, 0.25, 0);
      ek(g, kut(3.0, 4.6, 6.2), m(0xeee8da), 2.6, 2.8, 0);
      for (var z = -2.6; z <= 2.6; z += 1.04) ek(g, sil(0.22, 0.25, 4.2, 12), m(0xf6f2e8), 0.75, 2.6, z);
      var al = ek(g, new T.CylinderGeometry(1.2, 1.2, 6.4, 3), m(0xeee8da), 1.4, 5.5, 0); al.rotation.x = Math.PI / 2; al.rotation.y = Math.PI / 2; al.scale.set(1, 1, 0.45);
      return '#5d4a2a';
    },
    belediye: function (g) {
      ek(g, kut(3.8, 8, 6.4), m(0xd8d2c4), 2.3, 4, 0);
      for (var k = 0; k < 2; k++) ek(g, kut(0.05, 1.3, 5.6), m(0x4a6a8a, { roughness: 0.2 }), 0.39, 2.6 + k * 2.9, 0);
      ek(g, sil(0.05, 0.05, 4, 6), m(0xcccccc), 2.3, 10, 0); var b = ek(g, new T.PlaneGeometry(1.6, 1), m(0xe30a17, { side: T.DoubleSide }), 2.3, 11.4, 0.85); b.rotation.y = Math.PI / 2;
      return '#1a237e';
    },
    anit: function (g) {
      var cim = ek(g, new T.PlaneGeometry(4.2, 7.2), m(0x6aa83f), 2.2, 0.14, 0); cim.rotation.x = -Math.PI / 2;
      ek(g, kut(1.6, 1.2, 1.6), m(0xbfb6a6), 2.2, 0.75, 0); ek(g, kut(0.9, 5, 0.9), m(0xd8d2c4), 2.2, 3.8, 0);
      ek(g, new T.ConeGeometry(0.64, 1.2, 4), m(0xd8d2c4), 2.2, 6.9, 0).rotation.y = Math.PI / 4;
      return '#5d4a2a';
    }
  };
  YAPI.kale = YAPI.kule = YAPI.yapi = YAPI.anit; YAPI.stadyum = YAPI.otogar = YAPI.belediye;
  var AD = { cami: 'CAMİ', ibadet: 'İBADETHANE', park: 'PARK', okul: 'OKUL', hastane: 'HASTANE', muze: 'MÜZE', belediye: 'BELEDİYE', stadyum: 'STADYUM', otogar: 'OTOGAR', anit: 'ANIT', kale: 'KALE', kule: 'KULE', yapi: 'TARİHİ YAPI' };
  var yapiC = {};
  function yapiYuvasi(tip, ad) {
    var k = tip + '|' + ad;
    if (!yapiC[k]) {
      var g = new T.Group(), renk = (YAPI[tip] || YAPI.anit)(g);
      var acik = tip === 'park' || tip === 'anit' || tip === 'kale' || tip === 'kule' || tip === 'yapi';
      var pl = adPlakasi(ad || AD[tip] || 'YAPI', renk); pl.position.set(acik ? -0.05 : 0.05, acik ? 1.05 : 1.35, acik ? 1.6 : 0); g.add(pl);
      yapiC[k] = g;
    }
    return yapiC[k].clone();
  }

  var sokakC = {};
  // aci: sokağın caddeyle gerçek açısı (90 dik; küçükse ileri doğru, büyükse geriye doğru sapar)
  function sokakAgzi(ad, aci, yan) {
    var g = new T.Group(), yolG = new T.Group(); g.add(yolG);
    if (aci && aci !== 90) yolG.rotation.y = (yan > 0 ? 1 : -1) * (90 - aci) * Math.PI / 180;
    // Asfalt kaldırımı keserek caddeye bağlanır; yaya geçidi çizgileri kavşağı belli eder
    var asf = ek(yolG, new T.PlaneGeometry(41.3, 5.2, 16, 1), m(0x4a5066, { roughness: 0.9, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 }), 19.35, 0.14, 0); asf.rotation.x = -Math.PI / 2;
    for (var zc = -2.1; zc <= 2.11; zc += 0.7) { var c = ek(g, new T.PlaneGeometry(1.2, 0.38), m(0xf2f2f2, { roughness: 0.6, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4 }), -0.55, 0.15, zc); c.rotation.x = -Math.PI / 2; }
    [-2.6, 2.6].forEach(function (z) { ek(yolG, new T.BoxGeometry(40, 0.16, 0.25, 16, 1, 1), m(0xd9cbb2), 20.6, 0.08, z); });
    var tb = sokakC[ad] || (sokakC[ad] = Y.tabela(ad.toLocaleUpperCase('tr-TR')));
    var t = tb.clone(); t.position.set(-1.5, 0.12, -3.0); g.add(t);
    return g;
  }

  // ---------- Sokak eşyası (OSM'deki gerçek konumlarında) ----------
  // Yerel eksen: -x yol tarafı; nesne kaldırımda durur, yüzü yola bakar.
  var bayrakDoku = null;
  function turkBayragi() {
    return bayrakDoku || (bayrakDoku = MD.tuvalDoku(192, 128, function (c, w, h) {
      c.fillStyle = '#e30a17'; c.fillRect(0, 0, w, h);
      c.fillStyle = '#fff'; c.beginPath(); c.arc(68, 64, 32, 0, Math.PI * 2); c.fill();
      c.fillStyle = '#e30a17'; c.beginPath(); c.arc(76, 64, 25.6, 0, Math.PI * 2); c.fill();
      c.fillStyle = '#fff'; c.beginPath();
      for (var i = 0; i < 10; i++) { var r = i % 2 ? 6.4 : 16, a = -Math.PI / 2 + i * Math.PI / 5; c.lineTo(112 + Math.cos(a) * r * 0.95 + 0, 64 + Math.sin(a) * r * 0.95); }
      c.closePath(); c.fill();
    }));
  }
  var ESYA = {
    cop: function (g) { ek(g, sil(0.24, 0.2, 0.75, 12), m(0x2e7d32), 0, 0.5, 0); ek(g, sil(0.26, 0.26, 0.06, 12), m(0x1b5e20), 0, 0.9, 0); ek(g, sil(0.03, 0.03, 0.9, 6), m(0x3a3d45), 0.28, 0.45, 0); },
    geridonusum: function (g) { [0x1565c0, 0xf9a825, 0x2e7d32].forEach(function (r, i) { ek(g, kut(0.55, 1.1, 0.55), m(r), 0.1, 0.68, (i - 1) * 0.6); }); },
    bank: function (g) { ek(g, kut(0.45, 0.07, 1.7), m(0x8d5a2b), 0, 0.55, 0); ek(g, kut(0.07, 0.4, 1.7), m(0x8d5a2b), 0.22, 0.8, 0); [-0.7, 0.7].forEach(function (z) { ek(g, kut(0.45, 0.45, 0.06), m(0x2b2e35), 0, 0.33, z); }); },
    cesme: function (g) { ek(g, kut(0.5, 1.3, 1.0), m(0xd8d0bf), 0.1, 0.77, 0); ek(g, kut(0.2, 0.2, 0.9), m(0xc2b8a3), -0.2, 1.45, 0); ek(g, sil(0.03, 0.03, 0.2, 6), m(0xb0b4bb, { metalness: 0.8 }), -0.22, 0.95, 0); ek(g, kut(0.35, 0.1, 0.8), m(0xa8a090), -0.15, 0.25, 0); },
    lamba: function (g) { ek(g, sil(0.06, 0.09, 4.4, 8), m(0x2f3238), 0, 2.32, 0); ek(g, kut(0.9, 0.06, 0.06), m(0x2f3238), -0.4, 4.5, 0); ek(g, kut(0.34, 0.1, 0.22), m(0xfff3c4, { emissive: 0x7a6a30 }), -0.82, 4.43, 0); },
    durak: function (g) {
      ek(g, kut(1.3, 0.08, 3.2), m(0x37474f), 0.25, 2.5, 0); [-1.5, 1.5].forEach(function (z) { ek(g, kut(0.06, 2.4, 0.06), m(0x546e7a), 0.85, 1.3, z); ek(g, kut(0.06, 2.4, 0.06), m(0x546e7a), -0.3, 1.3, z); });
      ek(g, kut(0.04, 1.8, 3.0), m(0xb3e5fc, { transparent: true, opacity: 0.4, roughness: 0.1 }), 0.86, 1.3, 0); ek(g, kut(0.35, 0.06, 2.4), m(0x8d5a2b), 0.6, 0.5, 0);
      var tb = ek(g, new T.PlaneGeometry(0.5, 0.5), new T.MeshBasicMaterial({ map: MD.tuvalDoku(64, 64, function (c) { c.fillStyle = '#1565c0'; c.fillRect(0, 0, 64, 64); c.fillStyle = '#fff'; c.font = '900 42px system-ui'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText('D', 32, 35); }), toneMapped: false, side: T.DoubleSide }), -0.3, 2.85, 1.5); tb.rotation.y = Math.PI / 2;
    },
    isik: function (g) { ek(g, sil(0.06, 0.07, 3.0, 8), m(0x2b2e35), -0.2, 1.5, 0); ek(g, kut(0.3, 0.9, 0.3), m(0x1c1f24), -0.2, 3.1, 0); [[0xe53935, 3.38], [0xfdd835, 3.1], [0x43a047, 2.82]].forEach(function (l) { ek(g, new T.SphereGeometry(0.09, 10, 8), m(l[0], { emissive: l[0], emissiveIntensity: 0.8 }), -0.36, l[1], 0); }); },
    agac: function (g) { var a = MD.agacYaprakli(0.75, [0x3f7d34, 0x4b8c3f, 0x356b32]); g.add(a); ek(g, kut(0.9, 0.06, 0.9), m(0x6b5a44), 0, 0.03, 0); },
    bayrak: function (g) {
      ek(g, sil(0.05, 0.07, 7, 10), m(0xd9dce1, { metalness: 0.7, roughness: 0.3 }), 0, 3.5, 0); ek(g, new T.SphereGeometry(0.1, 10, 8), m(0xd9b44a, { metalness: 0.7 }), 0, 7.05, 0);
      var b = ek(g, new T.PlaneGeometry(2.1, 1.4, 6, 1), new T.MeshStandardMaterial({ map: turkBayragi(), side: T.DoubleSide, roughness: 0.8 }), 0, 6.15, 1.08); b.rotation.y = Math.PI / 2;
      var p = b.geometry.attributes.position; for (var i = 0; i < p.count; i++) p.setZ(i, Math.sin((p.getX(i) + 1.05) * 2.6) * 0.12 * (p.getX(i) + 1.05) / 2.1); p.needsUpdate = true;
    },
    kamera: function (g) { ek(g, sil(0.05, 0.05, 3.6, 6), m(0x9ea4ab), 0, 1.8, 0); ek(g, kut(0.3, 0.16, 0.16), m(0xeceff1), -0.15, 3.6, 0); },
    kabin: function (g) { ek(g, kut(0.4, 1.1, 0.7), m(0x9e9e9e), 0.1, 0.55, 0); },
    baba: function (g) { [-0.6, 0, 0.6].forEach(function (z) { ek(g, sil(0.08, 0.08, 0.7, 10), m(0x37474f), -0.2, 0.35, z); ek(g, sil(0.085, 0.085, 0.06, 10), m(0xffc400), -0.2, 0.6, z); }); },
    heykel: function (g) { ek(g, kut(0.9, 0.9, 0.9), m(0xbdb6a8), 0.1, 0.45, 0); ek(g, sil(0.18, 0.25, 1.5, 10), m(0x6d6a5f, { metalness: 0.5 }), 0.1, 1.65, 0); ek(g, new T.SphereGeometry(0.2, 10, 8), m(0x6d6a5f, { metalness: 0.5 }), 0.1, 2.55, 0); },
    anit: function (g) { ek(g, kut(1.2, 0.5, 1.2), m(0xbfb6a6), 0.2, 0.25, 0); ek(g, kut(0.5, 3.2, 0.5), m(0xd8d2c4), 0.2, 2.1, 0); },
    postakutusu: function (g) { ek(g, kut(0.45, 0.9, 0.45), m(0xf9a825), 0, 0.85, 0); ek(g, sil(0.05, 0.05, 0.45, 6), m(0x3a3d45), 0, 0.2, 0); },
    telefon: function (g) { ek(g, kut(0.6, 2.1, 0.6), m(0x1565c0), 0.1, 1.05, 0); },
    otomat: function (g) { ek(g, kut(0.6, 1.8, 0.9), m(0xc62828), 0.15, 0.9, 0); ek(g, kut(0.02, 1.0, 0.6), m(0xcfeefa, { emissive: 0x223844 }), -0.16, 1.1, 0); },
    bisiklet: function (g) { for (var z = -0.9; z <= 0.9; z += 0.6) { var h = ek(g, new T.TorusGeometry(0.35, 0.03, 6, 12, Math.PI), m(0x90a4ae, { metalness: 0.6 }), 0, 0.05, z); h.rotation.y = Math.PI / 2; } },
    saat: function (g) { ek(g, sil(0.08, 0.1, 3.2, 8), m(0x263238), 0, 1.6, 0); var y = ek(g, sil(0.4, 0.4, 0.15, 16), m(0xffffff), 0, 3.4, 0); y.rotation.z = Math.PI / 2; },
    atm: function (g) { ek(g, kut(0.5, 1.6, 0.8), m(0x37474f), 0.15, 0.8, 0); ek(g, kut(0.02, 0.4, 0.5), m(0x4fc3f7, { emissive: 0x0d3b4f }), -0.11, 1.25, 0); },
    wc: function (g) { ek(g, kut(1.4, 2.3, 1.4), m(0x607d8b), 0.4, 1.15, 0); },
    masa: function (g) { ek(g, kut(0.8, 0.06, 1.6), m(0x8d5a2b), 0, 0.75, 0); ek(g, kut(0.3, 0.05, 1.6), m(0x8d5a2b), 0.6, 0.45, 0); ek(g, kut(0.3, 0.05, 1.6), m(0x8d5a2b), -0.6, 0.45, 0); },
    zebra: function (g) { for (var x = -2.0; x >= -7.0; x -= 0.9) { var b = ek(g, new T.PlaneGeometry(0.5, 2.6), m(0xf4f4f4, { roughness: 0.6, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4 }), x, 0.02, 0); b.rotation.x = -Math.PI / 2; } },
    reklam: function (g) { ek(g, sil(0.45, 0.45, 2.6, 16), m(0x2e7d32), 0, 1.3, 0); ek(g, sil(0.5, 0.5, 0.15, 16), m(0x1b5e20), 0, 2.65, 0); }
  };
  var esyaC = {};
  function esyaYap(tip) {
    if (!ESYA[tip]) return null;
    if (!esyaC[tip]) { var g = new T.Group(); ESYA[tip](g); g.traverse(function (o) { if (o.isMesh) o.castShadow = true; }); esyaC[tip] = g; }
    return esyaC[tip].clone();
  }

  // İlçe verisi (il başına bir dosya, ilk kullanımda yüklenir; file:// için XHR)
  var veri = {}, bekleyen = {};
  function yukle(plaka, bitti) {
    if (veri[plaka] !== undefined) { bitti(veri[plaka]); return; }
    (bekleyen[plaka] = bekleyen[plaka] || []).push(bitti);
    if (bekleyen[plaka].length > 1) return;
    var x = new XMLHttpRequest();
    x.open('GET', 'assets/veri/ilce/' + (plaka < 10 ? '0' : '') + plaka + '.json');
    x.onload = function () { try { veri[plaka] = x.responseText ? JSON.parse(x.responseText) : null; } catch (e) { veri[plaka] = null; } bekleyen[plaka].forEach(function (f) { f(veri[plaka]); }); bekleyen[plaka] = []; };
    x.onerror = function () { veri[plaka] = null; bekleyen[plaka].forEach(function (f) { f(null); }); bekleyen[plaka] = []; };
    try { x.send(); } catch (e) { x.onerror(); }
  }

  // Yüklenmiş ilçe verisi (yoksa undefined: henüz yüklenmedi, null: dosya yok)
  function hazir(plaka, sira) { var v = veri[plaka]; return v === undefined ? undefined : (v && v[sira]) || null; }
  window.TarakCadde = { dukkanTabelasi: dukkanTabelasi, yapiYuvasi: yapiYuvasi, sokakAgzi: sokakAgzi, esyaYap: esyaYap, yukle: yukle, hazir: hazir };
})();
