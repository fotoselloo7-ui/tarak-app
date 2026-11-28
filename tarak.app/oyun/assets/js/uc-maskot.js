/* Maskot K'nin 3D modeli. Gövde hatları orijinal görselden izlenen noktalarla üretilir.
 * Model -z yönüne koşar. Kamera arkadayken K doğru okunur; öne döndüğünde yuzOn() gövdeyi aynalar,
 * böylece yüz tarafında da K kolu (görseldeki gibi) sağda kalır. */
(function () {
  'use strict';
  var T = window.THREE;

  // 2x büyütülmüş referans kırpımındaki noktalar
  var DIS = [355,1247, 300,1225, 222,1140, 170,990, 135,850, 108,660, 96,470, 100,330, 135,225, 200,155, 300,98, 420,73, 515,96, 585,165, 625,250, 631,380, 630,461, 700,434, 800,415, 915,426, 959,475, 945,535, 850,680, 769,829, 829,846, 900,955, 977,1110, 975,1170, 920,1208, 770,1229, 680,1205, 625,1235, 500,1252];
  var IC_GOVDE = [265,420, 275,290, 305,205, 355,158, 420,141, 500,152, 555,195, 585,260, 592,360, 586,480, 600,620, 612,720, 628,860, 645,1000, 650,1110, 625,1165, 570,1190, 490,1192, 425,1170, 378,1110, 330,980, 296,850, 272,700, 262,540];
  var IC_KOL = [800,466, 905,466, 920,490, 908,530, 850,615, 770,730, 718,805, 713,850, 728,880, 790,888, 832,902, 885,990, 942,1100, 944,1135, 915,1160, 795,1172, 755,1158, 700,1075, 640,975, 605,880, 604,745, 635,690, 700,590, 765,500];
  var DISLER = [[657, 820, 950], [708, 865, 1028], [757, 910, 1106]];

  var OLCEK = 1.2 / 1180, MX = 520, ALT = 1252;
  function nx(px) { return (px - MX) * OLCEK; }
  function ny(py) { return (ALT - py) * OLCEK; }

  function sekil(noktalar) {
    var v = [];
    for (var i = 0; i < noktalar.length; i += 2) v.push(new T.Vector2(nx(noktalar[i]), ny(noktalar[i + 1])));
    var s = new T.Shape();
    s.moveTo(v[0].x, v[0].y);
    s.splineThru(v.slice(1).concat([v[0]]));
    return s;
  }
  function kapsulSekli(x1, x2, y, kalinlik) {
    var r = kalinlik / 2, s = new T.Shape();
    s.moveTo(x1 + r, y - r); s.lineTo(x2 - r, y - r);
    s.absarc(x2 - r, y, r, -Math.PI / 2, Math.PI / 2, false);
    s.lineTo(x1 + r, y + r);
    s.absarc(x1 + r, y, r, Math.PI / 2, Math.PI * 1.5, false);
    return s;
  }

  function malzeme(renk, puruz, metal, ek) {
    return new T.MeshStandardMaterial({ color: renk, roughness: puruz === undefined ? 0.45 : puruz, metalness: metal || 0, emissive: ek || 0x000000 });
  }

  function agac(ebeveyn, geo, mat, x, y, z) {
    var m = new T.Mesh(geo, mat); m.position.set(x || 0, y || 0, z || 0); ebeveyn.add(m); return m;
  }

  function tup(ebeveyn, noktalar, kalinlik, mat, z) {
    var pts = [];
    for (var i = 0; i < noktalar.length; i += 2) pts.push(new T.Vector3(nx(noktalar[i]), ny(noktalar[i + 1]), z));
    var egri = new T.CatmullRomCurve3(pts);
    agac(ebeveyn, new T.TubeGeometry(egri, 18, kalinlik, 8, false), mat);
    var uc = new T.SphereGeometry(kalinlik, 8, 6);
    agac(ebeveyn, uc, mat, pts[0].x, pts[0].y, pts[0].z);
    var son = pts[pts.length - 1];
    agac(ebeveyn, uc, mat, son.x, son.y, son.z);
  }

  function olustur() {
    var M = {
      sari: malzeme(0xffbf0a, 0.34, 0.05, 0x2a1c00),
      koyu: malzeme(0x1b1c20, 0.5),
      uzuv: malzeme(0x17181b, 0.38),
      beyaz: malzeme(0xf6f4ee, 0.5, 0, 0x161616),
      agiz: malzeme(0x5c1606, 0.8),
      dil: malzeme(0xff6a12, 0.6, 0, 0x331000),
      taban: malzeme(0xffbf0a, 0.5),
      eldiven: malzeme(0xf6f4ee, 0.55, 0, 0x181818)
    };

    var kok = new T.Group();          // ayak hizası (0)
    var takla = new T.Group();        // zıplama/kayma dönüşleri (kalça çevresi)
    takla.position.y = 0.78; kok.add(takla);
    var ic = new T.Group(); ic.position.y = -0.78; takla.add(ic);

    // ---------- Gövde ----------
    var govde = new T.Group(); govde.position.y = 0.66; ic.add(govde);
    var ayna = new T.Group(); govde.add(ayna);
    var disGeo = new T.ExtrudeGeometry(sekil(DIS), { depth: 0.2, bevelEnabled: true, bevelThickness: 0.07, bevelSize: 0.035, bevelOffset: -0.035, bevelSegments: 4, curveSegments: 6 });
    disGeo.translate(0, 0, -0.1);
    agac(ayna, disGeo, M.sari);
    [1, -1].forEach(function (yon) {       // +1 arka yüz (kameraya), -1 ön yüz
      [IC_GOVDE, IC_KOL].forEach(function (n) {
        var g = new T.ExtrudeGeometry(sekil(n), { depth: 0.018, bevelEnabled: true, bevelThickness: 0.008, bevelSize: 0.006, bevelOffset: -0.006, bevelSegments: 2, curveSegments: 6 });
        g.translate(0, 0, -0.009);
        agac(ayna, g, M.koyu, 0, 0, yon * 0.172);
      });
      DISLER.forEach(function (d) {
        var g = new T.ExtrudeGeometry(kapsulSekli(nx(d[0]), nx(d[1]), ny(d[2]), 56 * OLCEK), { depth: 0.018, bevelEnabled: true, bevelThickness: 0.008, bevelSize: 0.006, bevelOffset: -0.006, bevelSegments: 2 });
        g.translate(0, 0, -0.009);
        agac(ayna, g, M.sari, 0, 0, yon * 0.195);
      });
    });

    // ---------- Yüz (ön tarafta) ----------
    var yuz = new T.Group(); ayna.add(yuz);
    var zy = -0.198;
    tup(yuz, [330,615, 366,578, 418,592], 0.0125, M.sari, zy);
    tup(yuz, [502,590, 540,568, 578,604], 0.0125, M.sari, zy);
    tup(yuz, [346,712, 362,668, 390,653, 420,670, 433,706], 0.0165, M.beyaz, zy);
    tup(yuz, [506,700, 516,662, 540,645, 568,656, 584,696], 0.0165, M.beyaz, zy);
    var agiz = new T.Shape();
    agiz.moveTo(nx(388), ny(752)); agiz.quadraticCurveTo(nx(470), ny(782), nx(556), ny(734));
    agiz.bezierCurveTo(nx(552), ny(850), nx(510), ny(862), nx(470), ny(862));
    agiz.bezierCurveTo(nx(426), ny(862), nx(392), ny(820), nx(388), ny(752));
    agac(yuz, new T.ShapeGeometry(agiz), M.agiz, 0, 0, zy - 0.004).material.side = T.DoubleSide;
    tup(yuz, [394,756, 470,774, 550,740], 0.013, M.beyaz, zy - 0.006);
    var dil = agac(yuz, new T.SphereGeometry(0.05, 14, 10), M.dil, nx(476), ny(832), zy + 0.004);
    dil.scale.set(1.2, 0.55, 0.22);

    // ---------- Aksesuarlar ----------
    var aks = {};
    function aksGrubu(ad, ebeveyn) { var g = new T.Group(); g.visible = false; ebeveyn.add(g); aks[ad] = g; return g; }
    var tepeX = nx(400), tepeY = ny(95);
    var sap = aksGrubu('sapka', ayna);
    agac(sap, new T.CylinderGeometry(0.2, 0.215, 0.15, 24), M.beyaz, tepeX, tepeY + 0.055, 0);
    agac(sap, new T.CylinderGeometry(0.225, 0.225, 0.045, 24), M.beyaz, tepeX, tepeY + 0.01, 0);
    var tac = aksGrubu('tac', ayna);
    var altin = malzeme(0xffd23f, 0.22, 0.7, 0x4a3200);
    agac(tac, new T.CylinderGeometry(0.19, 0.17, 0.1, 24, 1, true), altin, tepeX, tepeY + 0.05, 0).material.side = T.DoubleSide;
    for (var i = 0; i < 7; i++) {
      var a = i / 7 * Math.PI * 2;
      agac(tac, new T.ConeGeometry(0.045, 0.13, 8), altin, tepeX + Math.cos(a) * 0.175, tepeY + 0.15, Math.sin(a) * 0.175);
      agac(tac, new T.SphereGeometry(0.022, 8, 6), malzeme(i % 2 ? 0xe6395a : 0x2f9bff, 0.2, 0.1), tepeX + Math.cos(a) * 0.19, tepeY + 0.055, Math.sin(a) * 0.19);
    }
    var kasket = aksGrubu('kasket', ayna);
    var kirmizi = malzeme(0xd23a32, 0.6);
    var kubbe = agac(kasket, new T.SphereGeometry(0.2, 20, 10, 0, Math.PI * 2, 0, Math.PI / 2), kirmizi, tepeX, tepeY, 0);
    kubbe.scale.y = 0.75;
    agac(kasket, new T.BoxGeometry(0.22, 0.025, 0.17), kirmizi, tepeX, tepeY + 0.015, 0.23);   // ters takılı siper

    var gozluk = aksGrubu('gozluk', ayna);
    var cam = malzeme(0x2f86d8, 0.08, 0.55, 0x0b2a4a);
    [[390, 680], [545, 672]].forEach(function (p) {
      var c = agac(gozluk, new T.SphereGeometry(0.082, 16, 12), cam, nx(p[0]), ny(p[1]), zy - 0.03); c.scale.set(1.05, 0.74, 0.25);
    });
    tup(gozluk, [330,660, 390,640, 468,668, 545,632, 605,650], 0.009, altin, zy - 0.04);
    var biyik = aksGrubu('biyik', ayna);
    tup(biyik, [470,728, 425,748, 385,742, 362,712], 0.026, M.uzuv, zy - 0.03);
    tup(biyik, [474,728, 520,742, 562,728, 580,696], 0.026, M.uzuv, zy - 0.03);
    var papyon = aksGrubu('papyon', ayna);
    var kumas = malzeme(0xb3122e, 0.5);
    [-1, 1].forEach(function (y) { var k = agac(papyon, new T.ConeGeometry(0.09, 0.17, 12), kumas, nx(470) + y * 0.085, ny(960), zy - 0.035); k.rotation.z = y * Math.PI / 2; });
    agac(papyon, new T.SphereGeometry(0.045, 10, 8), kumas, nx(470), ny(960), zy - 0.045);

    // ---------- Kutlama ve seviye kıyafetleri ----------
    var hareketli = {};
    var beyazTuy = malzeme(0xffffff, 0.85, 0, 0x2a2a2a);
    var noel = malzeme(0xd6202c, 0.6, 0, 0x1c0000);

    var yb = aksGrubu('yilbasi', ayna);
    agac(yb, new T.TorusGeometry(0.2, 0.052, 10, 26), beyazTuy, tepeX, tepeY + 0.02, 0).rotation.x = Math.PI / 2;
    agac(yb, new T.CylinderGeometry(0.12, 0.2, 0.2, 22), noel, tepeX, tepeY + 0.12, 0);
    var ucu = agac(yb, new T.ConeGeometry(0.122, 0.28, 22), noel, tepeX + 0.075, tepeY + 0.32, 0); ucu.rotation.z = -0.62;
    agac(yb, new T.SphereGeometry(0.075, 14, 10), beyazTuy, tepeX + 0.17, tepeY + 0.43, 0);

    var parti = aksGrubu('parti', ayna);
    var renkler = [0xff3b8d, 0x2fb6ff, 0xffd23f, 0x7b5cff, 0x35d07f];
    for (var pk = 0; pk < 5; pk++) {
      agac(parti, new T.CylinderGeometry(0.16 - (pk + 1) * 0.03, 0.16 - pk * 0.03, 0.085, 20), malzeme(renkler[pk], 0.45, 0.1, 0x141414), tepeX, tepeY + 0.06 + pk * 0.083, 0);
    }
    agac(parti, new T.SphereGeometry(0.055, 12, 10), beyazTuy, tepeX, tepeY + 0.5, 0);

    var kulak = aksGrubu('kulaklik', ayna);
    var plastik = malzeme(0x22242b, 0.35, 0.4), halka = malzeme(0x2fb6ff, 0.3, 0.3, 0x0a3550);
    var kSol = nx(108), kSag = nx(622), kY = ny(330);
    agac(kulak, new T.TorusGeometry((kSag - kSol) / 2 + 0.02, 0.028, 10, 36, Math.PI), plastik, (kSol + kSag) / 2, kY, 0);
    [kSol - 0.03, kSag + 0.03].forEach(function (x) {
      agac(kulak, new T.CylinderGeometry(0.135, 0.135, 0.09, 22), plastik, x, kY, 0).rotation.z = Math.PI / 2;
      agac(kulak, new T.TorusGeometry(0.07, 0.016, 8, 22), halka, x + (x < kSol ? -0.042 : 0.042), kY, 0).rotation.y = Math.PI / 2;
    });

    var kovboy = aksGrubu('kovboy', ayna);
    var deri = malzeme(0x8a5427, 0.7);
    var kenar = agac(kovboy, new T.CylinderGeometry(0.36, 0.36, 0.032, 30), deri, tepeX, tepeY + 0.01, 0); kenar.scale.z = 0.85;
    agac(kovboy, new T.CylinderGeometry(0.14, 0.19, 0.2, 22), deri, tepeX, tepeY + 0.12, 0);
    agac(kovboy, new T.CylinderGeometry(0.182, 0.193, 0.05, 22), malzeme(0x2a180c, 0.6), tepeX, tepeY + 0.055, 0);

    var silindir = aksGrubu('silindir', ayna);
    var kadife = malzeme(0x15131c, 0.4, 0.15);
    agac(silindir, new T.CylinderGeometry(0.28, 0.28, 0.035, 28), kadife, tepeX, tepeY + 0.015, 0);
    agac(silindir, new T.CylinderGeometry(0.175, 0.165, 0.34, 26), kadife, tepeX, tepeY + 0.19, 0);
    agac(silindir, new T.CylinderGeometry(0.17, 0.168, 0.065, 26), malzeme(0x7b35c9, 0.4, 0.2, 0x1c0838), tepeX, tepeY + 0.075, 0);

    var yele = aksGrubu('yele', ayna);
    var tuy = [malzeme(0xc9781f, 0.9), malzeme(0x8a4a14, 0.9), malzeme(0xe29a35, 0.9)];
    var yelNokta = [108,600, 96,470, 102,330, 135,225, 205,150, 300,98, 420,73, 515,96, 585,165, 625,250, 631,360, 628,455];
    for (var yi = 0; yi < yelNokta.length; yi += 2) {
      for (var kat = 0; kat < 2; kat++) {
        var top = agac(yele, new T.SphereGeometry(0.095 - kat * 0.015, 9, 7), tuy[(yi / 2 + kat) % 3], nx(yelNokta[yi]), ny(yelNokta[yi + 1]), kat ? 0.1 : -0.06);
        top.scale.set(1, 1.15, 0.9);
      }
    }

    var sakal = aksGrubu('nsakal', ayna);
    [[390,880,0.075], [450,915,0.095], [525,900,0.085], [575,855,0.06], [370,815,0.055], [480,975,0.08], [425,962,0.065], [535,955,0.06], [480,1030,0.045]].forEach(function (p) {
      var b = agac(sakal, new T.SphereGeometry(p[2], 12, 9), beyazTuy, nx(p[0]), ny(p[1]), zy - 0.012); b.scale.z = 0.5;
    });
    tup(sakal, [470,730, 425,752, 380,742], 0.03, beyazTuy, zy - 0.035);
    tup(sakal, [478,730, 524,744, 566,722], 0.03, beyazTuy, zy - 0.035);

    // Atkı: gövdeyi saran bant ve arkada sallanan uç
    function atkiYap(ad, ana, serit) {
      var g = aksGrubu(ad, ayna);
      var mAna = malzeme(ana, 0.8, 0, 0x120800), mSerit = malzeme(serit, 0.8, 0, 0x101010);
      var gx = (nx(165) + nx(668)) / 2, gen = nx(668) - nx(165) + 0.05, yuk = ny(915);
      agac(g, new T.BoxGeometry(gen, 0.1, 0.46), mAna, gx, yuk, 0);
      agac(g, new T.BoxGeometry(gen + 0.006, 0.028, 0.466), mSerit, gx, yuk, 0);
      var uc = new T.Group(); uc.position.set(nx(240), yuk - 0.02, 0.25); g.add(uc);
      agac(uc, new T.BoxGeometry(0.13, 0.34, 0.04), mAna, 0, -0.16, 0);
      agac(uc, new T.BoxGeometry(0.132, 0.05, 0.042), mSerit, 0, -0.25, 0);
      hareketli[ad] = uc;
    }
    atkiYap('atki', 0xffc400, 0x1c2023);
    atkiYap('ylatki', 0xd6202c, 0xffffff);

    var canta = aksGrubu('canta', ayna);
    var cx = nx(330), cy = ny(870);
    agac(canta, new T.BoxGeometry(0.34, 0.3, 0.17), malzeme(0x17181c, 0.6), cx, cy, 0.29);
    agac(canta, new T.BoxGeometry(0.35, 0.035, 0.175), M.sari, cx, cy + 0.06, 0.29);
    agac(canta, new T.BoxGeometry(0.2, 0.05, 0.02), M.sari, cx, cy - 0.045, 0.385);
    for (var cd = 0; cd < 6; cd++) agac(canta, new T.BoxGeometry(0.018, 0.05, 0.02), M.sari, cx - 0.082 + cd * 0.033, cy - 0.09, 0.385);
    agac(canta, new T.TorusGeometry(0.075, 0.018, 8, 18, Math.PI), malzeme(0x17181c, 0.6), cx, cy + 0.15, 0.29);

    // Pelerin: omuzdan aşağı uzayan ve koşarken dalgalanan parçalar (K görünsün diye alttan başlar)
    var pelerin = aksGrubu('pelerin', ayna);
    var kumasP = malzeme(0xc81432, 0.7, 0, 0x240004); kumasP.side = T.DoubleSide;
    var halkalar = [], ust = pelerin;
    for (var pi = 0; pi < 5; pi++) {
      var boge = new T.Group();
      boge.position.set(pi ? 0 : nx(380), pi ? -0.175 : ny(300), pi ? 0 : 0.235);
      ust.add(boge);
      agac(boge, new T.BoxGeometry(0.46 + pi * 0.07, 0.185, 0.022), kumasP, 0, -0.088, 0);
      halkalar.push(boge); ust = boge;
    }
    agac(pelerin, new T.BoxGeometry(0.5, 0.05, 0.05), M.sari, nx(380), ny(300) + 0.01, 0.23);
    hareketli.pelerin = halkalar;

    // Şapkalar geniş kafaya göre büyütülür ve kubbeye biraz gömülür (tepe noktası çevresinde ölçeklenir)
    [['sapka', 1.35, 1.2, 1.05], ['tac', 1.3, 1.15, 1.05], ['kasket', 1.45, 1.3, 1.1], ['yilbasi', 1.25, 1.15, 1.05], ['parti', 1.15, 1.1, 1.05], ['kovboy', 1.05, 1.05, 1.0], ['silindir', 1.1, 1.05, 1.05]].forEach(function (s) {
      var g = aks[s[0]];
      g.scale.set(s[1], s[2], s[3]);
      g.position.set(tepeX * (1 - s[1]) - 0.02, tepeY * (1 - s[2]) - 0.085, 0);
    });

    var balon = aksGrubu('balon', ayna);
    var ipM = malzeme(0xf2f2f2, 0.9);
    var balonlar = [[-0.5, 1.62, 0xff3b5c], [-0.7, 1.34, 0x2fb6ff], [-0.33, 1.9, 0xffd23f]].map(function (b) {
      var g = new T.Group(); balon.add(g);
      var bas = new T.Vector3(nx(300), ny(700), 0.24), son = new T.Vector3(b[0], b[1] - 0.2, 0.3);
      agac(g, new T.TubeGeometry(new T.QuadraticBezierCurve3(bas, new T.Vector3((bas.x + son.x) / 2 + 0.08, (bas.y + son.y) / 2, 0.33), son), 12, 0.006, 5, false), ipM);
      var top = agac(g, new T.SphereGeometry(0.17, 18, 14), malzeme(b[2], 0.25, 0.15, 0x1a1a1a), son.x, son.y + 0.19, son.z); top.scale.y = 1.2;
      agac(g, new T.ConeGeometry(0.03, 0.05, 8), top.material, son.x, son.y - 0.015, son.z);
      return g;
    });
    hareketli.balon = balonlar;

    var kanat = aksGrubu('kanat', ayna);
    var tuyK = malzeme(0xffffff, 0.7, 0, 0x4a4a52); tuyK.side = T.DoubleSide;
    var kanatlar = [-1, 1].map(function (yon) {
      var g = new T.Group(); g.position.set(nx(430) + yon * 0.07, ny(760), 0.25); kanat.add(g);
      var k = new T.Shape();
      k.moveTo(0, 0.05); k.quadraticCurveTo(yon * 0.3, 0.52, yon * 0.78, 0.46);
      k.quadraticCurveTo(yon * 0.64, 0.33, yon * 0.74, 0.22); k.quadraticCurveTo(yon * 0.52, 0.17, yon * 0.58, 0.03);
      k.quadraticCurveTo(yon * 0.36, 0.03, yon * 0.38, -0.13); k.quadraticCurveTo(yon * 0.16, -0.06, 0, -0.1);
      agac(g, new T.ShapeGeometry(k, 10), tuyK);
      return { g: g, yon: yon };
    });
    hareketli.kanat = kanatlar;

    // ---------- Kadın görünümü (Kiki): at kuyruğu, fiyonk, kirpik, allık ----------
    var kadinG = new T.Group(); kadinG.visible = false; ayna.add(kadinG);
    var sacM = malzeme(0x5a2f1c, 0.55, 0.05, 0x120600), sacP = malzeme(0x7a4528, 0.5, 0.05, 0x140800);
    var pembeM = malzeme(0xff3d8b, 0.4, 0.05, 0x2a0010);
    var kuyruk = new T.Group(); kuyruk.position.set(nx(470), ny(150), 0.2); kadinG.add(kuyruk);
    [[0, 0.02, 0.0, 0.1], [0.01, -0.06, 0.08, 0.105], [0.02, -0.2, 0.13, 0.1], [0.02, -0.35, 0.15, 0.09], [0.01, -0.5, 0.14, 0.075], [0, -0.63, 0.11, 0.058], [-0.01, -0.73, 0.07, 0.04]].forEach(function (q, i) {
      var t = agac(kuyruk, new T.SphereGeometry(q[3], 14, 10), i % 2 ? sacP : sacM, q[0], q[1], q[2]); t.scale.set(1.15, 1.25, 0.9);
    });
    [-1, 1].forEach(function (y) { var k = agac(kadinG, new T.ConeGeometry(0.075, 0.15, 12), pembeM, nx(470) + y * 0.085, ny(150) + 0.03, 0.21); k.rotation.z = y * Math.PI / 2; });
    agac(kadinG, new T.SphereGeometry(0.045, 10, 8), pembeM, nx(470), ny(150) + 0.03, 0.24);
    // Ön tarafta kirpikler ve allık
    [[372,668, 360,646], [392,656, 394,632], [414,664, 424,642], [522,656, 512,634], [542,648, 542,624], [562,656, 572,634]].forEach(function (q) { tup(kadinG, q, 0.0085, M.uzuv, zy - 0.012); });
    [[352,770], [598,758]].forEach(function (p) { var b = agac(kadinG, new T.SphereGeometry(0.045, 12, 8), malzeme(0xff7aa8, 0.8, 0, 0x2a0812), nx(p[0]), ny(p[1]), zy - 0.006); b.scale.set(1.3, 0.75, 0.2); });
    hareketli.kuyruk = kuyruk;

    // Kadın kıyafetleri: fiyonk, çiçek tacı, kedi gözlük, inci kolye
    var fiyonk = aksGrubu('fiyonk', ayna);
    [-1, 1].forEach(function (y) { var k = agac(fiyonk, new T.ConeGeometry(0.11, 0.22, 14), pembeM, tepeX + 0.05 + y * 0.12, tepeY + 0.04, 0); k.rotation.z = y * Math.PI / 2; });
    agac(fiyonk, new T.SphereGeometry(0.06, 12, 10), malzeme(0xd81b60, 0.4), tepeX + 0.05, tepeY + 0.04, 0);
    var cicek = aksGrubu('cicektac', ayna);
    agac(cicek, new T.TorusGeometry(0.2, 0.018, 8, 30), malzeme(0x4f9a3a, 0.7), tepeX, tepeY - 0.02, 0).rotation.x = Math.PI / 2;
    [0xff6fa5, 0xffffff, 0xffd23f, 0xb784ff, 0xff8a65, 0xffffff, 0xff6fa5, 0xffd23f].forEach(function (rk, i) {
      var a = i / 8 * Math.PI * 2, cx = tepeX + Math.cos(a) * 0.2, cz = Math.sin(a) * 0.2 * 0.9;
      for (var y = 0; y < 5; y++) { var yp = agac(cicek, new T.SphereGeometry(0.03, 8, 6), malzeme(rk, 0.6), cx + Math.cos(y * 1.26) * 0.035, tepeY + 0.01, cz + Math.sin(y * 1.26) * 0.035); yp.scale.y = 0.6; }
      agac(cicek, new T.SphereGeometry(0.02, 8, 6), malzeme(0xffc400, 0.5), cx, tepeY + 0.025, cz);
    });
    var kedi = aksGrubu('kedigoz', ayna);
    [[390, 680, -1], [545, 672, 1]].forEach(function (p) {
      var c = agac(kedi, new T.SphereGeometry(0.085, 16, 12), malzeme(0x2a0b1c, 0.1, 0.4, 0x14020a), nx(p[0]), ny(p[1]), zy - 0.03); c.scale.set(1.15, 0.7, 0.25);
      var u = agac(kedi, new T.ConeGeometry(0.035, 0.09, 8), malzeme(0xff3d8b, 0.3, 0.3), nx(p[0]) + p[2] * 0.095, ny(p[1]) + 0.055, zy - 0.03); u.rotation.z = -p[2] * 0.9;
    });
    tup(kedi, [330,660, 390,640, 468,668, 545,632, 605,650], 0.01, pembeM, zy - 0.04);
    var inci = aksGrubu('inci', ayna);
    for (var ic2 = 0; ic2 < 15; ic2++) {
      var ia = ic2 / 14, ix = nx(250) + (nx(690) - nx(250)) * ia, iy = ny(930) - Math.sin(ia * Math.PI) * 0.09;
      agac(inci, new T.SphereGeometry(0.026, 10, 8), malzeme(0xfaf6f0, 0.2, 0.15, 0x1a1a1a), ix, iy, zy - 0.03);
    }

    // ---------- Bacaklar ----------
    function kapsul(ebeveyn, r, uzunluk, mat) {
      var m = agac(ebeveyn, new T.CapsuleGeometry(r, uzunluk, 4, 10), mat, 0, -uzunluk / 2, 0);
      return m;
    }
    function ayakkabi(ebeveyn) {
      var g = new T.Group(); ebeveyn.add(g);
      var ust = agac(g, new T.SphereGeometry(0.13, 18, 14), M.beyaz, 0, -0.02, -0.055); ust.scale.set(0.95, 0.72, 1.45);
      var burunTaban = agac(g, new T.CylinderGeometry(0.134, 0.14, 0.055, 22), M.taban, 0, -0.095, -0.06); burunTaban.scale.set(0.98, 1, 1.5);
      var bilek = agac(g, new T.CylinderGeometry(0.095, 0.105, 0.1, 18), M.beyaz, 0, 0.045, 0.02);
      agac(g, new T.TorusGeometry(0.09, 0.024, 8, 20), M.beyaz, 0, 0.098, 0.02).rotation.x = Math.PI / 2;
      for (var k = 0; k < 3; k++) agac(g, new T.BoxGeometry(0.12, 0.014, 0.022), M.taban, 0, 0.066 - k * 0.018, -0.1 - k * 0.045).rotation.x = -0.35;
      agac(g, new T.BoxGeometry(0.07, 0.07, 0.02), M.taban, 0, -0.02, 0.135);   // topuk şeridi (arkadan görünür)
      bilek.name = 'bilek';
      return g;
    }
    var bacaklar = [-1, 1].map(function (yon) {
      var kalca = new T.Group(); kalca.position.set(yon * 0.13 - 0.02, 0.72, 0); ic.add(kalca);
      kapsul(kalca, 0.072, 0.27, M.uzuv);
      var diz = new T.Group(); diz.position.y = -0.29; kalca.add(diz);
      kapsul(diz, 0.066, 0.26, M.uzuv);
      var ayak = new T.Group(); ayak.position.y = -0.3; diz.add(ayak);
      ayakkabi(ayak);
      return { yon: yon, kalca: kalca, diz: diz, ayak: ayak };
    });

    // ---------- Kollar ----------
    function eldiven(ebeveyn, yon) {
      var g = new T.Group(); ebeveyn.add(g);
      agac(g, new T.CylinderGeometry(0.082, 0.072, 0.07, 16), M.eldiven, 0, 0.005, 0);
      var avuc = agac(g, new T.SphereGeometry(0.1, 16, 12), M.eldiven, 0, -0.095, 0); avuc.scale.set(0.9, 1, 0.95);
      agac(g, new T.SphereGeometry(0.045, 10, 8), M.eldiven, -yon * 0.07, -0.075, -0.045);
      return g;
    }
    var kollar = [-1, 1].map(function (yon) {
      var omuz = new T.Group(); omuz.position.set(yon < 0 ? nx(150) + 0.03 : nx(830), 0.66 + (yon < 0 ? ny(820) : ny(850)), 0); ic.add(omuz);
      kapsul(omuz, 0.055, 0.22, M.uzuv);
      var dirsek = new T.Group(); dirsek.position.y = -0.25; omuz.add(dirsek);
      kapsul(dirsek, 0.05, 0.19, M.uzuv);
      var el = new T.Group(); el.position.y = -0.22; dirsek.add(el);
      eldiven(el, yon);
      return { yon: yon, omuz: omuz, dirsek: dirsek };
    });

    var aynali = false;
    function yuzOn(on) {            // true: kameraya yüzünü dönmüş
      if (on === aynali) return;
      aynali = on;
      ayna.scale.x = on ? -1 : 1;
    }

    /* poz: 'kos' | 'zipla' | 'kay' | 'dur' | 'sevinc' | 'dusus' */
    function canlandir(poz, faz, ek) {
      ek = ek || {};
      var s = Math.sin(faz), c = Math.cos(faz);
      var egim = -0.14, yukari = 0, dondur = 0, sek = 0;
      var bAci = [[0, 0], [0, 0]], kAci = [[0, 0, 0], [0, 0, 0]];   // [kalça, diz] ve [ileri, dirsek, yana]
      bacaklar.forEach(function (b, i) {
        var f = faz + (b.yon > 0 ? Math.PI : 0);
        if (poz === 'kos') bAci[i] = [Math.sin(f) * 0.95, -Math.max(0, Math.cos(f)) * 1.5 - 0.12];
        else if (poz === 'zipla') bAci[i] = b.yon < 0 ? [1.15, -1.8] : [0.35, -1.35];
        else if (poz === 'kay') bAci[i] = b.yon < 0 ? [1.55, -0.15] : [1.25, -0.9];
        else if (poz === 'sevinc') bAci[i] = [b.yon * 0.06, -0.05];
        else if (poz === 'dusus') bAci[i] = [1.35, -1.1];
        else bAci[i] = [0, 0];
      });
      kollar.forEach(function (k, i) {
        var f = faz + (k.yon > 0 ? 0 : Math.PI);
        if (poz === 'kos') kAci[i] = [Math.sin(f) * 0.9, 1.25, 0.42];
        else if (poz === 'zipla') kAci[i] = [-0.2, 0.7, 1.75];
        else if (poz === 'kay') kAci[i] = [-1.05, 0.35, 0.9];
        else if (poz === 'sevinc') kAci[i] = [0, 0.4, 2.35 + Math.sin(faz * 1.7 + i * 2) * 0.28];
        else if (poz === 'dusus') kAci[i] = [0.6, 0.9, 0.8];
        else kAci[i] = [Math.sin(faz * 0.4) * 0.06, 0.3, 0.38];
      });
      bacaklar.forEach(function (b, i) {
        b.kalca.rotation.x = bAci[i][0]; b.diz.rotation.x = bAci[i][1];
        b.ayak.rotation.x = poz === 'kos' ? -(bAci[i][0] + bAci[i][1]) * 0.55 : poz === 'kay' ? -0.2 : -(bAci[i][0] + bAci[i][1]) * 0.3;
      });
      kollar.forEach(function (k, i) { k.omuz.rotation.x = kAci[i][0]; k.dirsek.rotation.x = kAci[i][1]; k.omuz.rotation.z = k.yon * kAci[i][2]; });

      if (poz === 'kos') { sek = Math.abs(c) * 0.07; govde.rotation.z = s * 0.035; govde.rotation.y = s * 0.07; }
      else { govde.rotation.z = 0; govde.rotation.y = 0; }
      if (poz === 'zipla') { egim = -0.08; dondur = ek.takla || 0; }
      if (poz === 'kay') { egim = 1.08; yukari = -0.46; }
      if (poz === 'dur') { egim = 0; sek = Math.sin(faz * 0.5) * 0.015; }
      if (poz === 'sevinc') { egim = 0; sek = Math.abs(Math.sin(faz * 1.4)) * 0.14; }
      if (poz === 'dusus') { egim = 0.5; yukari = -0.38; }
      takla.rotation.x = egim - dondur;
      takla.position.y = 0.78 + sek + yukari;

      // Sallanan parçalar
      var an = performance.now() / 1000;
      var kosuyor = poz === 'kos' || poz === 'zipla' || poz === 'kay';
      hareketli.pelerin.forEach(function (h, i) { h.rotation.x = -(kosuyor ? (i ? 0.13 : 0.42) : (i ? 0.02 : 0.09)) - Math.sin(an * (kosuyor ? 13 : 2.5) - i * 0.9) * (kosuyor ? 0.11 : 0.025); });
      ['atki', 'ylatki'].forEach(function (a) { hareketli[a].rotation.x = -(kosuyor ? 0.75 : 0.08) - Math.sin(an * (kosuyor ? 14 : 2)) * 0.12; });
      hareketli.balon.forEach(function (g, i) { g.position.y = Math.sin(an * 3 + i * 2) * 0.035; g.rotation.z = Math.sin(an * 2.2 + i) * 0.05; });
      hareketli.kanat.forEach(function (k) { k.g.rotation.y = -k.yon * (0.25 + Math.sin(an * (kosuyor ? 11 : 3)) * (kosuyor ? 0.5 : 0.2)); });
      hareketli.kuyruk.rotation.x = (kosuyor ? 0.55 : 0.08) + Math.sin(an * (kosuyor ? 14 : 2.2)) * (kosuyor ? 0.16 : 0.04);
      hareketli.kuyruk.rotation.z = Math.sin(an * (kosuyor ? 7 : 1.5)) * (kosuyor ? 0.12 : 0.03);
    }

    function kusan(secim) {
      var yuva = { sapka: 'bas', tac: 'bas', kasket: 'bas', yilbasi: 'bas', parti: 'bas', kulaklik: 'bas', kovboy: 'bas', silindir: 'bas', yele: 'bas',
        gozluk: 'yuz', biyik: 'yuz', nsakal: 'yuz', papyon: 'boyun', atki: 'boyun', ylatki: 'boyun', canta: 'sirt', pelerin: 'sirt', balon: 'sirt', kanat: 'sirt',
        fiyonk: 'bas', cicektac: 'bas', kedigoz: 'yuz', inci: 'boyun' };
      sonSecim = secim;
      Object.keys(aks).forEach(function (a) { aks[a].visible = secim[yuva[a]] === a; });
      M.taban.color.set(secim.ayakkabi === 'kirmizi' ? 0xe0323c : secim.ayakkabi === 'neon' ? 0x39ff88 : secim.ayakkabi === 'pembe' ? 0xff4f9a : kadinMod ? 0xff7eb3 : 0xffbf0a);
      M.taban.emissive.set(secim.ayakkabi === 'neon' ? 0x0c6b32 : 0x000000);
      M.eldiven.color.set(secim.eldiven === 'altin' ? 0xffcf3a : 0xf6f4ee);
      M.eldiven.metalness = secim.eldiven === 'altin' ? 0.65 : 0;
      M.eldiven.roughness = secim.eldiven === 'altin' ? 0.28 : 0.55;
    }

    // Kadın modu: gövde gül pembesi, kirpik/allık/at kuyruğu görünür, ağız ruj tonunda
    var kadinMod = false, sonSecim = {};
    function kadin(k) {
      kadinMod = !!k; kadinG.visible = kadinMod;
      M.sari.color.setHex(kadinMod ? 0xff8cb8 : 0xffbf0a); M.sari.emissive.setHex(kadinMod ? 0x2a0816 : 0x2a1c00);
      M.agiz.color.setHex(kadinMod ? 0x8a0f3a : 0x5c1606); M.dil.color.setHex(kadinMod ? 0xff5c93 : 0xff6a12);
      kusan(sonSecim);
    }

    return { kok: kok, canlandir: canlandir, kusan: kusan, kadin: kadin, yuzOn: yuzOn, aksesuarlar: Object.keys(aks) };
  }

  window.TarakMaskot3D = { olustur: olustur };
})();
