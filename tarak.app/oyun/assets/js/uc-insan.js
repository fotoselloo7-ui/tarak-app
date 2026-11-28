/* Tam vücutlu karakterler (3D). Kodla üretilir, dosya indirmez. Sevimli (büyük kafalı) oranlar.
 * Maskotla (uc-maskot.js) aynı iskelet ve aynı arayüz: { kok, canlandir(poz, faz, ek), kusan(secim), kadin(), yuzOn(), aksesuarlar }
 * Böylece koşu/zıplama/kayma animasyonları ve bütün kıyafetler aynen çalışır.
 * Ön yüz -z yönündedir (koşarken kamera arkadan bakar). Birimler metre, kok = ayak tabanı. */
(function () {
  'use strict';
  var T = window.THREE;
  var BAS_Y = 1.56, BAS_R = 0.27, BAS_OLCEK = 1.24;   // kafa merkezi, (ölçeklenmemiş) yarıçap, sevimli oran için büyütme

  function renk(h) { return typeof h === 'string' ? new T.Color(h) : new T.Color(h); }
  function mat(r, puruz, metal, isik) {
    var m = new T.MeshStandardMaterial({ color: renk(r), roughness: puruz == null ? 0.6 : puruz, metalness: metal || 0 });
    if (isik) { m.emissive = renk(isik); m.emissiveIntensity = 1; }
    return m;
  }
  function ek(eb, geo, m, x, y, z) { var o = new T.Mesh(geo, m); o.position.set(x || 0, y || 0, z || 0); eb.add(o); return o; }
  function kapsul(eb, r, uz, m) { return ek(eb, new T.CapsuleGeometry(r, uz, 4, 12), m, 0, -uz / 2, 0); }

  // Yüz düzlemi (x sağ, y yukarı; kafa merkezine göre) -> kafa yüzeyinde ön taraf noktası
  function yuzNoktasi(x, y, disari) {
    var r = BAS_R + (disari || 0.004), zz = r * r - x * x - y * y;
    return new T.Vector3(x, y, -Math.sqrt(Math.max(0.0004, zz)) * 0.95);
  }
  // Yüze çizgi (kaş, göz, ağız, bıyık): yüz düzleminde noktalar
  function cizgi(eb, nokta, kalinlik, m, disari) {
    var p = []; for (var i = 0; i < nokta.length; i += 2) p.push(yuzNoktasi(nokta[i], nokta[i + 1], disari));
    if (p.length === 2) p.splice(1, 0, p[0].clone().lerp(p[1], 0.5));
    var e = new T.CatmullRomCurve3(p);
    var o = new T.Mesh(new T.TubeGeometry(e, 10, kalinlik, 6, false), m); eb.add(o);
    [p[0], p[p.length - 1]].forEach(function (u) { ek(eb, new T.SphereGeometry(kalinlik, 8, 6), m, u.x, u.y, u.z); });
    return o;
  }
  function yuzeyde(eb, geo, m, x, y, disari) {
    var p = yuzNoktasi(x, y, disari), o = ek(eb, geo, m, p.x, p.y, p.z);
    o.lookAt(p.clone().multiplyScalar(2)); return o;
  }
  function aynala(nokta) { var a = []; for (var i = 0; i < nokta.length; i += 2) a.push(-nokta[i], nokta[i + 1]); return a; }

  // ---------- Yüz ifadeleri (şekil dili) ----------
  var KAS = {
    neseli: [[-0.15, 0.1, -0.095, 0.125, -0.045, 0.108], 0.011],
    huysuz: [[-0.155, 0.135, -0.04, 0.088], 0.017],
    kotu:   [[-0.165, 0.155, -0.035, 0.075], 0.016],
    zarif:  [[-0.145, 0.105, -0.095, 0.132, -0.045, 0.118], 0.0075],
    guzel:  [[-0.145, 0.112, -0.095, 0.135, -0.048, 0.124], 0.009]
  };
  function yuzYap(bas, t, M) {
    var g = new T.Group(); bas.add(g);
    var koyu = M.yuzKoyu, kadin = t.cins === 'k';
    // burun, kulaklar
    yuzeyde(g, new T.SphereGeometry(0.03, 10, 8), M.tenKoyu, 0, -0.035, -0.012);
    [-1, 1].forEach(function (y) { var k = ek(g, new T.SphereGeometry(0.055, 10, 8), M.ten, y * BAS_R * 0.98, 0.0, 0.01); k.scale.set(0.45, 1, 0.8); });
    // kaşlar
    var kas = KAS[t.yuz] || KAS.neseli;
    cizgi(g, kas[0], kas[1], M.kas, 0.006);
    var sagKas = aynala(kas[0]);
    if (t.tekKas) for (var i = 1; i < sagKas.length; i += 2) sagKas[i] += 0.035;   // karizmatik: tek kaş kalkık
    cizgi(g, sagKas, kas[1], M.kas, 0.006);
    // gözler
    [-1, 1].forEach(function (y) {
      var x = y * 0.09;
      if (t.yuz === 'neseli') cizgi(g, [x - 0.04, 0.005, x, 0.045, x + 0.04, 0.005], 0.011, koyu, 0.005);
      else if (t.yuz === 'huysuz') {
        yuzeyde(g, new T.SphereGeometry(0.03, 10, 8), koyu, x, 0.0, 0.0).scale.set(1, 1, 0.5);
        cizgi(g, [x - 0.045, 0.03 + y * -0.004, x + 0.045, 0.022 - y * -0.004], 0.011, M.ten, 0.012);   // yarı kapalı göz kapağı
        cizgi(g, [x - 0.045, 0.024, x + 0.045, 0.02], 0.006, koyu, 0.016);
      } else if (t.yuz === 'kotu') {
        cizgi(g, [x - y * 0.045, 0.035, x + y * 0.04, -0.002], 0.013, M.gozIsik, 0.008);
        cizgi(g, [x - y * 0.05, 0.052, x + y * 0.045, 0.012], 0.006, koyu, 0.012);
      } else if (t.yuz === 'zarif') {
        cizgi(g, [x - 0.04, 0.03, x, 0.004, x + 0.04, 0.03], 0.0075, koyu, 0.006);
      } else {   // güzel / karizmatik: iri parlak göz
        var b = yuzeyde(g, new T.SphereGeometry(0.052, 14, 10), M.gozBeyaz, x, 0.012, 0.004); b.scale.set(1, 1.15, 0.35);
        var ir = yuzeyde(g, new T.SphereGeometry(0.036, 12, 10), M.iris, x + 0.004, 0.006, 0.02); ir.scale.set(1, 1.1, 0.3);
        yuzeyde(g, new T.SphereGeometry(0.02, 10, 8), koyu, x + 0.004, 0.004, 0.028).scale.set(1, 1, 0.3);
        yuzeyde(g, new T.SphereGeometry(0.012, 8, 6), M.parilti, x - 0.012, 0.03, 0.034);
      }
      if (kadin) for (var l = 0; l < 3; l++) {   // kirpik
        var lx = x + y * (0.025 + l * 0.014), ly = (t.yuz === 'zarif' || t.yuz === 'neseli') ? 0.03 - l * 0.004 : 0.05 - l * 0.006;
        if (t.yuz === 'guzel') ly = 0.07 - l * 0.012;
        cizgi(g, [lx, ly, lx + y * 0.018, ly + 0.02], 0.005, koyu, 0.012);
      }
    });
    // ağız
    var dudak = kadin ? M.ruj : koyu;
    if (t.yuz === 'neseli') {
      // açık gülüş: yüzey eğrisine gömülmesin diye biraz dışarıda
      var a = yuzeyde(g, new T.CircleGeometry(0.066, 16, Math.PI, Math.PI), M.agiz, 0, -0.082, 0.016);
      yuzeyde(g, new T.CircleGeometry(0.03, 12, Math.PI, Math.PI), M.dil, 0.004, -0.118, 0.02);
      cizgi(g, [-0.064, -0.082, 0.064, -0.082], 0.007, M.dis, 0.02);
      if (kadin) cizgi(g, [-0.068, -0.08, 0, -0.075, 0.068, -0.08], 0.006, M.ruj, 0.024);
      void a;
    } else if (t.yuz === 'huysuz') cizgi(g, [-0.06, -0.125, 0, -0.098, 0.06, -0.125], 0.009, dudak, 0.004);
    else if (t.yuz === 'kotu') {
      cizgi(g, [-0.065, -0.1, -0.01, -0.112, 0.05, -0.098, 0.075, -0.078], 0.009, dudak, 0.004);
      yuzeyde(g, new T.ConeGeometry(0.009, 0.025, 6), M.dis, 0.035, -0.115, 0.006).rotation.z += Math.PI;
    } else if (t.yuz === 'zarif') cizgi(g, [-0.038, -0.1, 0, -0.112, 0.038, -0.1], 0.0075, dudak, 0.004);
    else cizgi(g, [-0.055, -0.095, 0, -0.122, 0.055, -0.095], 0.009, dudak, 0.004);
    // allık
    if (t.allik) [-1, 1].forEach(function (y) { yuzeyde(g, new T.CircleGeometry(0.034, 14), M.allik, y * 0.155, -0.05, 0.002).scale.set(1.25, 0.7, 1); });
    // bıyık / sakal / monokl
    if (t.biyik === 'gri') { cizgi(g, [-0.115, -0.085, -0.06, -0.06, -0.012, -0.068], 0.026, M.biyik, 0.02); cizgi(g, [0.115, -0.085, 0.06, -0.06, 0.012, -0.068], 0.026, M.biyik, 0.02); }
    if (t.biyik === 'burma') { cizgi(g, [-0.012, -0.066, -0.06, -0.07, -0.1, -0.06, -0.115, -0.035, -0.098, -0.03], 0.011, M.biyik, 0.012); cizgi(g, [0.012, -0.066, 0.06, -0.07, 0.1, -0.06, 0.115, -0.035, 0.098, -0.03], 0.011, M.biyik, 0.012); }
    if (t.biyik === 'ince') { cizgi(g, [-0.075, -0.074, -0.012, -0.064], 0.006, M.biyik, 0.01); cizgi(g, [0.075, -0.074, 0.012, -0.064], 0.006, M.biyik, 0.01); }
    if (t.sakal === 'keci') { var s = yuzeyde(g, new T.ConeGeometry(0.035, 0.1, 10), M.biyik, 0, -0.2, -0.01); s.rotation.x += Math.PI / 2 + Math.PI; }
    if (t.monokl) {
      var mk = yuzeyde(g, new T.TorusGeometry(0.052, 0.008, 8, 22), M.altin, 0.09, 0.012, 0.02); void mk;
      var c = yuzeyde(g, new T.CircleGeometry(0.048, 18), M.cam, 0.09, 0.012, 0.022); void c;
    }
    return g;
  }

  // ---------- Saç ----------
  function sacYap(bas, t, M) {
    var g = new T.Group(); bas.add(g);
    var tepe = new T.Group(); g.add(tepe);            // şapka takılınca gizlenecek kısım
    var r = BAS_R;
    // Saç kapağı arkaya yatık: önde saç çizgisi kaşların üstünde (alın ve gözler açık), arkada enseye iner
    function kep(olcek, alt) {
      var k = ek(tepe, new T.SphereGeometry(r * olcek, 26, 14, 0, Math.PI * 2, 0, Math.PI * (alt || 0.5)), M.sac, 0, 0.0, 0.0);
      k.rotation.x = 0.62;
      return k;
    }
    var model = t.sac;
    if (model === 'kel') {
      [-1, 1].forEach(function (y) { var k = ek(g, new T.SphereGeometry(0.1, 12, 10), M.sac, y * r * 0.88, -0.02, 0.08); k.scale.set(0.6, 1.1, 1.3); });
      var arka = ek(g, new T.SphereGeometry(0.16, 14, 10), M.sac, 0, -0.04, r * 0.82); arka.scale.set(1.5, 0.75, 0.6);
    } else if (model !== 'yok') {
      kep(1.045, model === 'uzun' || model === 'dalgali' ? 0.6 : 0.55);
      // kulak üstü favoriler
      [-1, 1].forEach(function (y) { var f = ek(tepe, new T.SphereGeometry(0.07, 10, 8), M.sac, y * r * 0.93, 0.07, 0.03); f.scale.set(0.45, 1.2, 1.2); });
    }
    if (model === 'percem') {
      var p = ek(tepe, new T.SphereGeometry(0.2, 18, 12), M.sac, 0.02, 0.2, -0.13); p.scale.set(1.25, 0.62, 1.05); p.rotation.x = -0.55; p.rotation.z = -0.15;
      var p2 = ek(tepe, new T.SphereGeometry(0.15, 14, 10), M.sac, -0.08, 0.24, 0.0); p2.scale.set(1.2, 0.6, 1.3);
    }
    if (model === 'geri') { var pk = ek(tepe, new T.ConeGeometry(0.05, 0.1, 8), M.sac, 0, 0.17, -0.22); pk.rotation.x = Math.PI + 0.5; }
    if (model === 'yan') { var ay = ek(tepe, new T.BoxGeometry(0.012, 0.02, 0.3), M.yuzKoyu, -0.08, 0.255, -0.02); ay.rotation.z = 0.3; }
    if (model === 'atKuyrugu') {
      var ak = new T.Group(); ak.position.set(0, 0.12, r * 0.95); g.add(ak);
      [[0, 0, 0.07], [0, -0.07, 0.075], [0, -0.17, 0.07], [0, -0.27, 0.06], [0, -0.36, 0.045]].forEach(function (q) { ek(ak, new T.SphereGeometry(q[2], 12, 10), M.sac, q[0], q[1], 0.03); });
      ek(ak, new T.TorusGeometry(0.05, 0.016, 8, 16), M.toka, 0, 0.0, 0.02);
      g.userData.kuyruk = ak;
    }
    if (model === 'topuz') {
      ek(tepe, new T.SphereGeometry(0.12, 16, 12), M.sac, 0, 0.27, 0.08);
      if (t.bigudi) [[-0.08, 0.2, -0.12], [0.08, 0.21, -0.12], [0, 0.25, -0.05], [-0.14, 0.12, 0.0], [0.14, 0.12, 0.0]].forEach(function (q) { var b = ek(tepe, new T.CylinderGeometry(0.034, 0.034, 0.09, 12), M.bigudi, q[0], q[1], q[2]); b.rotation.z = Math.PI / 2; });
      if (t.inciToka) for (var i = 0; i < 7; i++) { var a = i / 7 * Math.PI * 2; ek(tepe, new T.SphereGeometry(0.016, 8, 6), M.inci, Math.cos(a) * 0.12, 0.27 + Math.sin(a) * 0.02, 0.08 + Math.sin(a) * 0.12); }
    }
    if (model === 'uzun' || model === 'dalgali') {
      var perde = new T.Group(); perde.position.set(0, -0.05, 0.08); g.add(perde);
      var n = model === 'dalgali' ? 9 : 6;
      for (var j = 0; j < n; j++) {
        var u = j / (n - 1), x = (u - 0.5) * 0.5, dal = model === 'dalgali' ? Math.sin(j * 1.7) * 0.03 : 0;
        var tel = ek(perde, new T.CapsuleGeometry(0.075, 0.42, 4, 10), M.sac, x + dal, -0.2, 0.12 + Math.abs(u - 0.5) * -0.12);
        tel.rotation.z = (u - 0.5) * -0.35;
      }
      [-1, 1].forEach(function (y) { var yan = ek(perde, new T.CapsuleGeometry(0.06, 0.3, 4, 10), M.sac, y * 0.27, -0.12, -0.08); yan.rotation.z = y * 0.12; });
      if (t.tutam) { var tt = ek(perde, new T.CapsuleGeometry(0.035, 0.36, 4, 8), M.tutam, -0.25, -0.12, -0.13); tt.rotation.z = -0.1; }
      g.userData.perde = perde;
    }
    if (t.cicekToka) {
      [0xff6fa5, 0xffffff, 0xff6fa5, 0xffd23f, 0xff6fa5].forEach(function (rk, i) { var a = i / 5 * Math.PI * 2; ek(g, new T.SphereGeometry(0.03, 8, 6), mat(rk, 0.6), -0.22 + Math.cos(a) * 0.035, 0.16 + Math.sin(a) * 0.035, -0.1); });
      ek(g, new T.SphereGeometry(0.022, 8, 6), mat(0xffc400, 0.5), -0.22, 0.16, -0.12);
    }
    g.userData.tepe = tepe;
    return g;
  }

  // ---------- Kıyafet ----------
  function govdeYap(ic, t, M) {
    var govde = new T.Group(); govde.position.y = 0.66; ic.add(govde);   // maskotla aynı dönme merkezi
    var RB = T.RoundedBoxGeometry;
    var gen = t.gobek ? 0.5 : 0.42;
    var tors = ek(govde, RB ? new RB(gen, 0.44, t.gobek ? 0.33 : 0.27, 4, 0.08) : new T.BoxGeometry(gen, 0.44, 0.27), M.ust, 0, 0.34, 0);
    void tors;
    // kalça / şort
    ek(govde, RB ? new RB(0.38, 0.17, 0.26, 3, 0.06) : new T.BoxGeometry(0.38, 0.17, 0.26), M.alt, 0, 0.1, 0);
    if (t.etek) { var e = ek(govde, new T.CylinderGeometry(0.2, t.etek === 'uzun' ? 0.36 : 0.32, t.etek === 'uzun' ? 0.42 : 0.3, 22, 1, true), M.etek, 0, t.etek === 'uzun' ? -0.02 : 0.04, 0); e.material.side = T.DoubleSide; }
    // önlük (berber/kuaför) ve göğüste Tarak K rozeti
    if (t.onluk) {
      ek(govde, new T.BoxGeometry(0.32, 0.5, 0.02), M.onluk, 0, 0.26, -0.15);
      var roz = ek(govde, new T.CircleGeometry(0.045, 16), M.rozet, 0.08, 0.42, -0.162); roz.rotation.y = Math.PI;
      ek(govde, new T.BoxGeometry(0.012, 0.05, 0.004), M.yuzKoyu, 0.07, 0.42, -0.165);
      ek(govde, new T.BoxGeometry(0.03, 0.01, 0.004), M.yuzKoyu, 0.09, 0.425, -0.165).rotation.z = 0.7;
    }
    if (t.ceket) {   // takım: yaka ve kravat
      [-1, 1].forEach(function (y) { var yk = ek(govde, new T.BoxGeometry(0.07, 0.24, 0.012), M.yaka, y * 0.075, 0.42, -0.142); yk.rotation.z = y * -0.35; });
      ek(govde, new T.BoxGeometry(0.11, 0.2, 0.008), M.gomlek, 0, 0.44, -0.138);
      var kr = ek(govde, new T.BoxGeometry(0.04, 0.16, 0.01), M.kravat, 0, 0.42, -0.145); void kr;
    }
    if (t.mont) { ek(govde, new T.BoxGeometry(0.012, 0.42, 0.006), M.fermuar, 0.0, 0.34, -0.14); [-1, 1].forEach(function (y) { ek(govde, new T.BoxGeometry(0.14, 0.06, 0.29), M.yaka, y * 0.15, 0.55, 0); }); }
    if (t.hirka) [-1, 1].forEach(function (y) { ek(govde, new T.BoxGeometry(0.05, 0.42, 0.012), M.yaka, y * 0.06, 0.34, -0.142); });
    // boyun ve kafa
    ek(govde, new T.CylinderGeometry(0.075, 0.085, 0.1, 14), M.ten, 0, 0.6, 0);
    var bas = new T.Group(); bas.position.set(0, BAS_Y - 0.66, 0); bas.scale.setScalar(BAS_OLCEK); govde.add(bas);
    var kafa = ek(bas, new T.SphereGeometry(BAS_R, 30, 22), M.ten, 0, 0, 0); kafa.scale.set(1, 0.96, 0.95);
    return { govde: govde, bas: bas };
  }

  // ---------- Kıyafet aksesuarları (maskottaki eşyaların tam vücuda uyarlanmış hali) ----------
  function aksesuarlar(bas, govde, M, aks, hareketli) {
    function grup(ad, eb) { var g = new T.Group(); g.visible = false; eb.add(g); aks[ad] = g; return g; }
    var ty = BAS_R * 0.92;                         // kafa tepesi (kafa grubunda)
    var beyaz = mat(0xf6f4ee, 0.5), altin = M.altin;
    var sap = grup('sapka', bas); ek(sap, new T.CylinderGeometry(0.26, 0.28, 0.2, 24), beyaz, 0, ty + 0.06, 0); ek(sap, new T.CylinderGeometry(0.29, 0.29, 0.05, 24), beyaz, 0, ty - 0.02, 0);
    var tac = grup('tac', bas);
    ek(tac, new T.CylinderGeometry(0.22, 0.2, 0.1, 24, 1, true), altin, 0, ty + 0.02, 0).material.side = T.DoubleSide;
    for (var i = 0; i < 7; i++) { var a = i / 7 * Math.PI * 2; ek(tac, new T.ConeGeometry(0.045, 0.13, 8), altin, Math.cos(a) * 0.2, ty + 0.12, Math.sin(a) * 0.2); ek(tac, new T.SphereGeometry(0.022, 8, 6), mat(i % 2 ? 0xe6395a : 0x2f9bff, 0.2), Math.cos(a) * 0.215, ty + 0.03, Math.sin(a) * 0.215); }
    var kas = grup('kasket', bas), kirmizi = mat(0xd23a32, 0.6);
    var kub = ek(kas, new T.SphereGeometry(0.285, 22, 12, 0, Math.PI * 2, 0, Math.PI / 2), kirmizi, 0, ty - 0.08, 0); kub.scale.y = 0.8;
    ek(kas, new T.BoxGeometry(0.26, 0.025, 0.2), kirmizi, 0, ty - 0.07, 0.3);
    var goz = grup('gozluk', bas), cam = mat(0x2f86d8, 0.08, 0.55);
    [-1, 1].forEach(function (y) { var c = ek(goz, new T.SphereGeometry(0.062, 14, 10), cam, y * 0.09, 0.015, -0.25); c.scale.set(1.15, 0.8, 0.3); });
    ek(goz, new T.BoxGeometry(0.42, 0.014, 0.014), altin, 0, 0.04, -0.245);
    var biy = grup('biyik', bas);
    [-1, 1].forEach(function (y) { var b = ek(biy, new T.CapsuleGeometry(0.022, 0.08, 4, 8), M.yuzKoyu, y * 0.055, -0.065, -0.262); b.rotation.z = y * 1.2; });
    var pap = grup('papyon', govde), kumas = mat(0xb3122e, 0.5);
    [-1, 1].forEach(function (y) { var k = ek(pap, new T.ConeGeometry(0.06, 0.12, 12), kumas, y * 0.06, 0.55, -0.15); k.rotation.z = y * Math.PI / 2; });
    ek(pap, new T.SphereGeometry(0.03, 10, 8), kumas, 0, 0.55, -0.16);
    var noel = mat(0xd6202c, 0.6), tuy = mat(0xffffff, 0.85);
    var yb = grup('yilbasi', bas);
    ek(yb, new T.TorusGeometry(0.27, 0.05, 10, 26), tuy, 0, ty - 0.04, 0).rotation.x = Math.PI / 2;
    ek(yb, new T.CylinderGeometry(0.16, 0.27, 0.22, 22), noel, 0, ty + 0.07, 0);
    var u = ek(yb, new T.ConeGeometry(0.16, 0.3, 22), noel, 0.09, ty + 0.28, 0.02); u.rotation.z = -0.62;
    ek(yb, new T.SphereGeometry(0.07, 14, 10), tuy, 0.21, ty + 0.4, 0.02);
    var parti = grup('parti', bas), rk = [0xff3b8d, 0x2fb6ff, 0xffd23f, 0x7b5cff, 0x35d07f];
    for (var pk = 0; pk < 5; pk++) ek(parti, new T.CylinderGeometry(0.17 - (pk + 1) * 0.032, 0.17 - pk * 0.032, 0.085, 20), mat(rk[pk], 0.45), 0, ty + 0.04 + pk * 0.083, 0);
    ek(parti, new T.SphereGeometry(0.05, 12, 10), tuy, 0, ty + 0.47, 0);
    var kul = grup('kulaklik', bas), plastik = mat(0x22242b, 0.35, 0.4), halka = mat(0x2fb6ff, 0.3);
    ek(kul, new T.TorusGeometry(0.3, 0.025, 10, 36, Math.PI), plastik, 0, 0.0, 0);
    [-1, 1].forEach(function (y) { ek(kul, new T.CylinderGeometry(0.1, 0.1, 0.07, 22), plastik, y * 0.29, 0, 0).rotation.z = Math.PI / 2; ek(kul, new T.TorusGeometry(0.055, 0.014, 8, 20), halka, y * 0.33, 0, 0).rotation.y = Math.PI / 2; });
    var kov = grup('kovboy', bas), deri = mat(0x8a5427, 0.7);
    var kn = ek(kov, new T.CylinderGeometry(0.45, 0.45, 0.032, 30), deri, 0, ty - 0.02, 0); kn.scale.z = 0.85;
    ek(kov, new T.CylinderGeometry(0.19, 0.25, 0.22, 22), deri, 0, ty + 0.1, 0);
    ek(kov, new T.CylinderGeometry(0.24, 0.252, 0.05, 22), mat(0x2a180c, 0.6), 0, ty + 0.03, 0);
    var sil = grup('silindir', bas), kadife = mat(0x15131c, 0.4, 0.15);
    ek(sil, new T.CylinderGeometry(0.36, 0.36, 0.035, 28), kadife, 0, ty - 0.02, 0);
    ek(sil, new T.CylinderGeometry(0.22, 0.21, 0.38, 26), kadife, 0, ty + 0.18, 0);
    ek(sil, new T.CylinderGeometry(0.215, 0.212, 0.065, 26), mat(0x7b35c9, 0.4, 0.2), 0, ty + 0.03, 0);
    var yele = grup('yele', bas), yt = [mat(0xc9781f, 0.9), mat(0x8a4a14, 0.9), mat(0xe29a35, 0.9)];
    for (var y2 = 0; y2 < 18; y2++) { var a2 = y2 / 18 * Math.PI * 2; ek(yele, new T.SphereGeometry(0.1, 10, 8), yt[y2 % 3], Math.cos(a2) * 0.3, Math.sin(a2) * 0.3 + 0.02, 0.06); }
    var fy = grup('fiyonk', bas), pembe = mat(0xff3d8b, 0.4);
    [-1, 1].forEach(function (y) { var k = ek(fy, new T.ConeGeometry(0.09, 0.18, 14), pembe, 0.1 + y * 0.1, ty + 0.02, 0.02); k.rotation.z = y * Math.PI / 2; });
    ek(fy, new T.SphereGeometry(0.05, 12, 10), mat(0xd81b60, 0.4), 0.1, ty + 0.02, 0.02);
    var ct = grup('cicektac', bas);
    ek(ct, new T.TorusGeometry(0.26, 0.016, 8, 30), mat(0x4f9a3a, 0.7), 0, ty - 0.03, 0).rotation.x = Math.PI / 2;
    [0xff6fa5, 0xffffff, 0xffd23f, 0xb784ff, 0xff8a65, 0xffffff, 0xff6fa5, 0xffd23f].forEach(function (r2, j) { var a3 = j / 8 * Math.PI * 2; ek(ct, new T.SphereGeometry(0.04, 8, 6), mat(r2, 0.6), Math.cos(a3) * 0.26, ty - 0.02, Math.sin(a3) * 0.26); });
    var kg = grup('kedigoz', bas);
    [-1, 1].forEach(function (y) { var c = ek(kg, new T.SphereGeometry(0.066, 14, 10), mat(0x2a0b1c, 0.1, 0.4), y * 0.09, 0.015, -0.25); c.scale.set(1.25, 0.75, 0.3); var uc = ek(kg, new T.ConeGeometry(0.025, 0.07, 8), pembe, y * 0.165, 0.06, -0.24); uc.rotation.z = -y * 0.9; });
    var inci = grup('inci', govde);
    for (var ic2 = 0; ic2 < 15; ic2++) { var ia = ic2 / 14 * Math.PI; ek(inci, new T.SphereGeometry(0.02, 10, 8), mat(0xfaf6f0, 0.2, 0.15), Math.cos(ia) * 0.13, 0.56 - Math.sin(ia) * 0.06, -0.1 - Math.sin(ia) * 0.05); }
    var ns = grup('nsakal', bas);
    [[0, -0.15, 0.09], [-0.08, -0.12, 0.07], [0.08, -0.12, 0.07], [-0.04, -0.21, 0.07], [0.04, -0.21, 0.07], [0, -0.26, 0.06], [-0.13, -0.05, 0.05], [0.13, -0.05, 0.05]].forEach(function (q) { ek(ns, new T.SphereGeometry(q[2], 10, 8), tuy, q[0], q[1], -0.2); });
    function atki(ad, ana, serit) {
      var g = grup(ad, govde);
      ek(g, new T.TorusGeometry(0.13, 0.05, 10, 24), ana, 0, 0.57, 0).rotation.x = Math.PI / 2;
      var ucu = new T.Group(); ucu.position.set(0.1, 0.55, 0.08); g.add(ucu);
      ek(ucu, new T.BoxGeometry(0.1, 0.3, 0.03), ana, 0, -0.15, 0.06); ek(ucu, new T.BoxGeometry(0.1, 0.04, 0.032), serit, 0, -0.22, 0.06);
      hareketli[ad] = ucu;
    }
    atki('atki', mat(0xffc400, 0.7), mat(0x1c2023, 0.7)); atki('ylatki', mat(0xd6202c, 0.7), mat(0xffffff, 0.7));
    var canta = grup('canta', govde);
    ek(canta, T.RoundedBoxGeometry ? new T.RoundedBoxGeometry(0.34, 0.38, 0.16, 3, 0.05) : new T.BoxGeometry(0.34, 0.38, 0.16), mat(0x17181c, 0.6), 0, 0.33, 0.22);
    ek(canta, new T.BoxGeometry(0.34, 0.04, 0.165), mat(0xffc400, 0.5), 0, 0.42, 0.22);
    var pel = grup('pelerin', govde), pk2 = mat(0xc81432, 0.7);
    pk2.side = T.DoubleSide;
    hareketli.pelerin = [0, 1].map(function (i) { var p = new T.Group(); p.position.set(0, 0.55 - i * 0.27, 0.15 + i * 0.03); pel.add(p); ek(p, new T.PlaneGeometry(0.46 + i * 0.08, 0.3), pk2, 0, -0.15, 0); return p; });
    var bal = grup('balon', govde);
    hareketli.balon = [[-0.3, 1.0, 0xff3b5c], [-0.45, 0.8, 0x2fb6ff], [-0.2, 1.2, 0xffd23f]].map(function (b) {
      var g = new T.Group(); bal.add(g);
      ek(g, new T.SphereGeometry(0.13, 16, 12), mat(b[2], 0.3), b[0], b[1], 0.25).scale.y = 1.2;
      ek(g, new T.CylinderGeometry(0.004, 0.004, b[1] - 0.3, 4), beyaz, b[0] * 0.5, (b[1] + 0.3) / 2, 0.22).rotation.z = -b[0] * 0.5;
      return g;
    });
    var kanat = grup('kanat', govde), kb = mat(0xffffff, 0.6);
    hareketli.kanat = [-1, 1].map(function (yon) {
      var g = new T.Group(); g.position.set(yon * 0.1, 0.42, 0.16); kanat.add(g);
      var k = ek(g, new T.SphereGeometry(0.22, 14, 10), kb, yon * 0.2, 0.05, 0.02); k.scale.set(1.2, 0.6, 0.12);
      var k2 = ek(g, new T.SphereGeometry(0.15, 12, 8), kb, yon * 0.3, -0.1, 0.02); k2.scale.set(1.2, 0.5, 0.1);
      return { g: g, yon: yon };
    });
  }

  function olustur(t) {
    t = t || {};
    var M = {
      ten: mat(t.ten || '#f2c19b', 0.65), tenKoyu: mat(new T.Color(t.ten || '#f2c19b').offsetHSL(0, 0, -0.08), 0.65),
      sac: mat(t.sacRenk || '#2a1a10', 0.55), tutam: mat(t.tutamRenk || '#e0115f', 0.5), toka: mat(t.tokaRenk || '#ff3d8b', 0.4),
      ust: mat(t.ust || '#e94e3c', 0.7), alt: mat(t.alt || '#2b3a55', 0.75), etek: mat(t.etekRenk || t.ust || '#e94e3c', 0.7),
      onluk: mat(t.onlukRenk || '#ffffff', 0.7), rozet: mat('#ffbf0a', 0.35, 0.1), yaka: mat(t.yakaRenk || '#1c1f26', 0.6),
      gomlek: mat(t.gomlek || '#ffffff', 0.6), kravat: mat(t.kravat || '#c62828', 0.5), fermuar: mat('#9ea4ab', 0.3, 0.7),
      ayakkabi: mat(t.ayakkabi || '#ffffff', 0.5), taban: mat(t.taban || '#ffbf0a', 0.5), el: mat(t.ten || '#f2c19b', 0.65),
      yuzKoyu: mat('#1a1214', 0.5), kas: mat(t.kasRenk || t.sacRenk || '#2a1a10', 0.6), agiz: mat('#5c1606', 0.8), dil: mat('#ff6a6a', 0.6),
      dis: mat('#ffffff', 0.4), ruj: mat(t.ruj || '#c2185b', 0.45), allik: mat('#ff7aa8', 0.8), gozBeyaz: mat('#ffffff', 0.35),
      iris: mat(t.iris || '#3d7fd6', 0.3), parilti: new T.MeshBasicMaterial({ color: 0xffffff }), gozIsik: mat(t.gozIsik || '#ffd23f', 0.3, 0, t.gozIsik || '#ffb300'),
      biyik: mat(t.biyikRenk || t.sacRenk || '#2a1a10', 0.7), altin: mat('#ffd23f', 0.22, 0.7), cam: new T.MeshStandardMaterial({ color: 0xbfe6ff, transparent: true, opacity: 0.35, roughness: 0.05 }),
      bigudi: mat('#ff8fc0', 0.4), inci: mat('#faf6f0', 0.2, 0.15)
    };
    var kok = new T.Group();
    var takla = new T.Group(); takla.position.y = 0.78; kok.add(takla);
    var ic = new T.Group(); ic.position.y = -0.78; takla.add(ic);
    var gb = govdeYap(ic, t, M), govde = gb.govde, bas = gb.bas;
    var bas_yuz = yuzYap(bas, t, M); void bas_yuz;
    var sac = sacYap(bas, t, M);
    var aks = {}, hareketli = { pelerin: [], balon: [], kanat: [] };
    aksesuarlar(bas, govde, M, aks, hareketli);

    // bacaklar (maskotla aynı ölçüler)
    function ayakkabi(eb) {
      var g = new T.Group(); eb.add(g);
      var u = ek(g, new T.SphereGeometry(0.11, 16, 12), M.ayakkabi, 0, -0.03, -0.045); u.scale.set(0.95, 0.7, 1.5);
      var tb = ek(g, new T.CylinderGeometry(0.112, 0.118, 0.045, 20), M.taban, 0, -0.09, -0.05); tb.scale.set(0.98, 1, 1.55);
      return g;
    }
    var bacakUst = t.etek === 'uzun' ? M.ten : (t.etek ? M.ten : M.alt);
    var bacaklar = [-1, 1].map(function (yon) {
      var kalca = new T.Group(); kalca.position.set(yon * 0.11, 0.72, 0); ic.add(kalca);
      kapsul(kalca, 0.078, 0.25, bacakUst);
      var diz = new T.Group(); diz.position.y = -0.29; kalca.add(diz);
      kapsul(diz, 0.07, 0.24, t.etek ? (t.corap ? mat(t.corap, 0.6) : M.ten) : M.alt);
      var ayak = new T.Group(); ayak.position.y = -0.3; diz.add(ayak);
      ayakkabi(ayak);
      return { yon: yon, kalca: kalca, diz: diz, ayak: ayak };
    });
    var kollar = [-1, 1].map(function (yon) {
      var omuz = new T.Group(); omuz.position.set(yon * (t.gobek ? 0.3 : 0.26), 1.17, 0); ic.add(omuz);
      ek(omuz, new T.SphereGeometry(0.075, 12, 10), M.ust, 0, 0, 0);
      kapsul(omuz, 0.06, 0.2, M.ust);
      var dirsek = new T.Group(); dirsek.position.y = -0.24; omuz.add(dirsek);
      kapsul(dirsek, 0.054, 0.17, t.uzunKol ? M.ust : M.ten);
      var el = new T.Group(); el.position.y = -0.22; dirsek.add(el);
      var avuc = ek(el, new T.SphereGeometry(0.068, 14, 10), M.el, 0, -0.02, 0); avuc.scale.set(0.9, 1.05, 0.9);
      return { yon: yon, omuz: omuz, dirsek: dirsek };
    });

    var durus = t.durus || 'neseli';
    var KOL = { neseli: 1, huysuz: 0.7, kotu: 0.85, zarif: 0.6, guzel: 1 }[durus] || 1;
    var EGIM = { neseli: 0, huysuz: 0.07, kotu: 0.12, zarif: -0.04, guzel: 0 }[durus] || 0;
    var SEK = { neseli: 1, huysuz: 0.7, kotu: 0.8, zarif: 0.6, guzel: 1.35 }[durus] || 1;

    function canlandir(poz, faz, ekv) {
      ekv = ekv || {};
      var s = Math.sin(faz), c = Math.cos(faz);
      var egim = -0.14, yukari = 0, dondur = 0, sek = 0;
      var bA = [[0, 0], [0, 0]], kA = [[0, 0, 0], [0, 0, 0]];
      bacaklar.forEach(function (b, i) {
        var f = faz + (b.yon > 0 ? Math.PI : 0);
        if (poz === 'kos') bA[i] = [Math.sin(f) * 0.95, -Math.max(0, Math.cos(f)) * 1.5 - 0.12];
        else if (poz === 'zipla') bA[i] = b.yon < 0 ? [1.15, -1.8] : [0.35, -1.35];
        else if (poz === 'kay') bA[i] = b.yon < 0 ? [1.55, -0.15] : [1.25, -0.9];
        else if (poz === 'sevinc') bA[i] = [b.yon * 0.06, -0.05];
        else if (poz === 'dusus') bA[i] = [1.35, -1.1];
        else bA[i] = [0, 0];
      });
      kollar.forEach(function (k, i) {
        var f = faz + (k.yon > 0 ? 0 : Math.PI);
        if (poz === 'kos') kA[i] = [Math.sin(f) * 0.9 * KOL, 1.2, 0.18];
        else if (poz === 'zipla') kA[i] = [-0.2, 0.7, 1.75];
        else if (poz === 'kay') kA[i] = [-1.05, 0.35, 0.9];
        else if (poz === 'sevinc') kA[i] = [0, 0.4, 2.35 + Math.sin(faz * 1.7 + i * 2) * 0.28];
        else if (poz === 'dusus') kA[i] = [0.6, 0.9, 0.8];
        else if (durus === 'zarif' && i === 1) kA[i] = [-0.15, 1.15, 0.7];             // el belde
        else if (durus === 'huysuz') kA[i] = [0.3, 1.75, -0.32];                       // kollar önde kavuşturulmuş
        else if (durus === 'kotu') kA[i] = [0.45, 1.55, -0.2 + Math.sin(faz * 1.5 + i * Math.PI) * 0.05];   // ellerini ovuşturur
        else kA[i] = [Math.sin(faz * 0.4) * 0.05, 0.25, 0.12];
      });
      bacaklar.forEach(function (b, i) { b.kalca.rotation.x = bA[i][0]; b.diz.rotation.x = bA[i][1]; b.ayak.rotation.x = poz === 'kos' ? -(bA[i][0] + bA[i][1]) * 0.55 : poz === 'kay' ? -0.2 : -(bA[i][0] + bA[i][1]) * 0.3; });
      kollar.forEach(function (k, i) { k.omuz.rotation.x = kA[i][0]; k.dirsek.rotation.x = kA[i][1]; k.omuz.rotation.z = k.yon * kA[i][2]; });
      if (poz === 'kos') { sek = Math.abs(c) * 0.07 * SEK; govde.rotation.z = s * 0.035; govde.rotation.y = s * 0.07; egim += EGIM; }
      else { govde.rotation.z = 0; govde.rotation.y = 0; }
      if (poz === 'zipla') { egim = -0.08; dondur = ekv.takla || 0; }
      if (poz === 'kay') { egim = 1.08; yukari = -0.46; }
      if (poz === 'dur') { egim = EGIM * 0.4; sek = Math.sin(faz * 0.5) * 0.015 * SEK; }
      if (poz === 'sevinc') { egim = 0; sek = Math.abs(Math.sin(faz * 1.4)) * 0.14 * SEK; }
      if (poz === 'dusus') { egim = 0.5; yukari = -0.38; }
      takla.rotation.x = egim - dondur;
      takla.position.y = 0.78 + sek + yukari;
      bas.rotation.x = poz === 'dur' && durus === 'huysuz' ? 0.12 : poz === 'dur' && durus === 'zarif' ? -0.08 : 0;
      bas.rotation.z = poz === 'dur' && durus === 'guzel' ? Math.sin(faz * 0.6) * 0.08 : 0;
      var an = performance.now() / 1000, kosuyor = poz === 'kos' || poz === 'zipla' || poz === 'kay';
      hareketli.pelerin.forEach(function (h, i) { h.rotation.x = -(kosuyor ? (i ? 0.13 : 0.42) : (i ? 0.02 : 0.09)) - Math.sin(an * (kosuyor ? 13 : 2.5) - i * 0.9) * (kosuyor ? 0.11 : 0.025); });
      ['atki', 'ylatki'].forEach(function (a) { if (hareketli[a]) hareketli[a].rotation.x = -(kosuyor ? 0.75 : 0.08) - Math.sin(an * (kosuyor ? 14 : 2)) * 0.12; });
      hareketli.balon.forEach(function (g, i) { g.position.y = Math.sin(an * 3 + i * 2) * 0.035; });
      hareketli.kanat.forEach(function (k) { k.g.rotation.y = -k.yon * (0.25 + Math.sin(an * (kosuyor ? 11 : 3)) * (kosuyor ? 0.5 : 0.2)); });
      if (sac.userData.kuyruk) { sac.userData.kuyruk.rotation.x = (kosuyor ? 0.55 : 0.08) + Math.sin(an * (kosuyor ? 14 : 2.2)) * (kosuyor ? 0.16 : 0.04); }
      if (sac.userData.perde) { sac.userData.perde.rotation.x = (kosuyor ? 0.32 : 0.02) + Math.sin(an * (kosuyor ? 12 : 2)) * (kosuyor ? 0.06 : 0.015); }
    }

    var YUVA = { sapka: 'bas', tac: 'bas', kasket: 'bas', yilbasi: 'bas', parti: 'bas', kulaklik: 'bas', kovboy: 'bas', silindir: 'bas', yele: 'bas',
      gozluk: 'yuz', biyik: 'yuz', nsakal: 'yuz', papyon: 'boyun', atki: 'boyun', ylatki: 'boyun', canta: 'sirt', pelerin: 'sirt', balon: 'sirt', kanat: 'sirt',
      fiyonk: 'bas', cicektac: 'bas', kedigoz: 'yuz', inci: 'boyun' };
    var BUYUK_SAPKA = { sapka: 1, kasket: 1, yilbasi: 1, parti: 1, kovboy: 1, silindir: 1, tac: 1 };
    var temelAyakkabi = M.ayakkabi.color.getHex(), temelTaban = M.taban.color.getHex();
    function kusan(secim) {
      secim = secim || {};
      Object.keys(aks).forEach(function (a) { aks[a].visible = secim[YUVA[a]] === a; });
      // Büyük şapka takılınca saçın tepe kısmı (perçem, topuz) şapkanın içinde kalır
      sac.userData.tepe.visible = !BUYUK_SAPKA[secim.bas];
      M.taban.color.setHex(secim.ayakkabi === 'kirmizi' ? 0xe0323c : secim.ayakkabi === 'neon' ? 0x39ff88 : secim.ayakkabi === 'pembe' ? 0xff4f9a : temelTaban);
      M.taban.emissive.setHex(secim.ayakkabi === 'neon' ? 0x0c6b32 : 0x000000);
      M.ayakkabi.color.setHex(secim.ayakkabi === 'kirmizi' ? 0xffffff : temelAyakkabi);
      M.el.color.set(secim.eldiven === 'altin' ? 0xffcf3a : (t.ten || '#f2c19b'));
      M.el.metalness = secim.eldiven === 'altin' ? 0.65 : 0;
    }
    kok.traverse(function (m) { if (m.isMesh) m.castShadow = true; });
    return { kok: kok, canlandir: canlandir, kusan: kusan, kadin: function () {}, yuzOn: function () {}, aksesuarlar: Object.keys(aks), insan: true };
  }

  window.TarakInsan3D = { olustur: olustur };
})();
