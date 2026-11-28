/* 3D koşu sahnesi: gökyüzü, ışık ve gölge, dokulu yol, çevre, canlı trafik, aslanlar, engeller, kamera. */
(function () {
  'use strict';
  var T = window.THREE, U = window.TarakUc, MD = window.TarakModel;
  var GORUS = 150;

  var TEMA = {
    sehir:  { gok: ['#2f8fe8', '#8fcaf6', '#e9f2f6'], sis: 0xa6d2f0, yol: '#4a5066', serit: '#ffffff', kenar: 0xd9cbb2, isik: 0xfff0d2, yer: 0xb5a58a, doga: false, gunes: [40, 155], pus: 2, mavi: 1.7, bulut: 0.4 },
    otoyol: { gok: ['#3c3f88', '#d9718c', '#ffc673'], sis: 0xe9b08f, yol: '#393a43', serit: '#ffd23f', kenar: 0x8f8a99, isik: 0xffcf9e, yer: 0x6e7340, doga: false, gunes: [9, -62], pus: 7, mavi: 2.4, bulut: 0.35 },
    orman:  { gok: ['#2f8fe8', '#9fd6ee', '#eef6d8'], sis: 0xbfe0d0, yol: '#8a5f38', serit: '#b88a58', kenar: 0x62a834, isik: 0xfff0cc, yer: 0x5aa83a, doga: true, gunes: [46, 150], pus: 2, mavi: 1.5, bulut: 0.45 },
    in:     { gok: ['#3a2a5a', '#c2614f', '#ffb15a'], sis: 0xe2a070, yol: '#a8743d', serit: '#d9a45a', kenar: 0x9a6a33, isik: 0xffc08a, yer: 0xa58040, doga: true, gunes: [7, 58], pus: 9, mavi: 3, bulut: 0.3 }
  };

  var tuvalDoku = MD.tuvalDoku, ekle = MD.ekle;
  var KADIN = false;   // kadın kuaför modu: tabelalar ve dükkânlar değişir
  var ROTA = null, YER = window.TarakYerler;   // oynanan ilçenin özellikleri (iller.js)
  // Bölgeye göre bina dokuları
  var STILLER = {
    tarihi: { cephe: ['#ef8a6a', '#4fb3c4', '#f6c75a', '#d9604a', '#8cc79a', '#a98bdb'], tente: [0xe23d3d, 0x2f7fe0, 0x23a35a, 0xff8a1f, 0x8d45d6, 0x14a3a3], korniz: [0xfff4e2, 0xfff4e2, 0x7a3b2a, 0xfff4e2, 0x2f5d50, 0xfff4e2], kat: 0 },
    modern: { cephe: ['#8fa7bf', '#c3ccd6', '#5f7a96', '#dfe4e9', '#7f93a8', '#a9b8c6'], tente: [0x2b2e35, 0x1f6fd6, 0x23a35a, 0x2b2e35, 0xd9534f, 0x14a3a3], korniz: [0x2b2e35, 0xe8ebee, 0x2b2e35, 0x4a5563, 0xe8ebee, 0x2b2e35], kat: 2, cerceve: '#2b2e35' },
    tas: { cephe: ['#e8cfa2', '#dcbf8c', '#f0dcb4', '#d6b27a', '#e4c898', '#caa56d'], tente: [0x9a5a2a, 0x2f7f6f, 0xb23a2a, 0x6a4a2a, 0x2f5d9a, 0x8a3a5a], korniz: [0xc9a66b, 0xd9bb84, 0xb8945a, 0xc9a66b, 0xd9bb84, 0xb8945a], kat: -1, cerceve: '#f4e6c8' },
    beyaz: { cephe: ['#ffffff', '#f7f7f2', '#ffffff', '#f2f6f8', '#ffffff', '#fbfbf6'], tente: [0x1f6fd6, 0x1f6fd6, 0x2fa3d6, 0x1f6fd6, 0x2fa3d6, 0x1f6fd6], korniz: [0xffffff, 0xffffff, 0xffffff, 0xffffff, 0xffffff, 0xffffff], kat: -1, cerceve: '#2f6fd6', begonvil: true },
    cumbali: { cephe: ['#e85d75', '#3fb6a8', '#f2b134', '#5c8de8', '#9b6bd6', '#ef8a4c'], tente: [0x7a3b2a, 0x7a3b2a, 0x5a3b24, 0x7a3b2a, 0x5a3b24, 0x7a3b2a], korniz: [0x5a3b24, 0x5a3b24, 0x5a3b24, 0x5a3b24, 0x5a3b24, 0x5a3b24], kat: 0, cumba: true, cerceve: '#fff6e6' }
  };
  var mCache = {};
  function mat(renk, ek) {
    var k = renk + (ek ? JSON.stringify(ek) : '');
    if (!mCache[k]) { var o = { color: renk, roughness: 0.8, metalness: 0 }; for (var a in ek) o[a] = ek[a]; mCache[k] = new T.MeshStandardMaterial(o); }
    return mCache[k];
  }
  var gCache = {};
  function kutuG(w, h, d) { var k = 'k' + w + '_' + h + '_' + d; return gCache[k] || (gCache[k] = new T.BoxGeometry(w, h, d)); }
  function silG(r1, r2, h, n) { var k = 's' + r1 + '_' + r2 + '_' + h + '_' + n; return gCache[k] || (gCache[k] = new T.CylinderGeometry(r1, r2, h, n || 12)); }
  function kureG(r, n) { var k = 'u' + r + '_' + n; return gCache[k] || (gCache[k] = new T.SphereGeometry(r, n || 10, Math.max(6, (n || 10) - 3))); }
  function koniG(r, h, n) { var k = 'c' + r + '_' + h + '_' + n; return gCache[k] || (gCache[k] = new T.ConeGeometry(r, h, n || 10)); }
  function yer(o, x, y, z) { o.position.set(x, y, z); return o; }
  function yaziPlakasi(w, h, metin, zemin, renk, punto, genislikPx) {
    var d = tuvalDoku(genislikPx || 256, Math.round((genislikPx || 256) * h / w), function (g, cw, ch) {
      g.fillStyle = zemin; g.fillRect(0, 0, cw, ch);
      g.fillStyle = renk; g.textAlign = 'center'; g.textBaseline = 'middle';
      var satir = metin.split('\n'), boy = punto || ch * 0.55 / satir.length;
      satir.forEach(function (s, i) { g.font = '900 ' + boy + 'px system-ui, sans-serif'; g.fillText(s, cw / 2, ch * (i + 0.5) / satir.length, cw * 0.92); });
    });
    return new T.Mesh(new T.PlaneGeometry(w, h), new T.MeshBasicMaterial({ map: d, toneMapped: false }));
  }

  // Düz renkli Lambert parçaları köşe rengiyle tek geometride birleştirir (çevre için).
  var duzM = null;
  function birlestir(grup) {
    if (!duzM) duzM = new T.MeshStandardMaterial({ vertexColors: true, roughness: 0.85, metalness: 0 });
    grup.updateMatrixWorld(true);
    var parcalar = [], kalan = [];
    grup.traverse(function (m) {
      if (!m.isMesh) return;
      var x = m.material;
      var duz = (x.isMeshLambertMaterial || x.isMeshStandardMaterial) && !x.userData.foto && !x.map && !x.transparent && !x.flatShading && x.emissive.getHex() === 0 && !x.vertexColors && (!x.metalness);
      if (!duz) { kalan.push(m); return; }
      var g = m.geometry.index ? m.geometry.toNonIndexed() : m.geometry.clone();
      g.applyMatrix4(m.matrixWorld);
      Object.keys(g.attributes).forEach(function (a) { if (a !== 'position' && a !== 'normal' && a !== 'uv') g.deleteAttribute(a); });
      if (!g.attributes.uv) g.setAttribute('uv', new T.BufferAttribute(new Float32Array(g.attributes.position.count * 2), 2));
      var n = g.attributes.position.count, renkler = new Float32Array(n * 3);
      for (var i = 0; i < n; i++) { renkler[i * 3] = x.color.r; renkler[i * 3 + 1] = x.color.g; renkler[i * 3 + 2] = x.color.b; }
      g.setAttribute('color', new T.BufferAttribute(renkler, 3));
      g.clearGroups();
      parcalar.push(g);
    });
    var yeni = new T.Group();
    if (parcalar.length) { var me = new T.Mesh(T.mergeGeometries(parcalar, false), duzM); me.receiveShadow = true; yeni.add(me); }
    kalan.forEach(function (m) {
      var k = new T.Mesh(m.geometry, m.material);
      m.matrixWorld.decompose(k.position, k.quaternion, k.scale);
      yeni.add(k);
    });
    return yeni;
  }

  // ---------- Fotoğraf dokuları (Poly Haven, CC0) ----------
  // Fotoğraflar yüklenene kadar çizilmiş dokular görünür; yüklenince aynı tuvaller fotoğrafla yeniden çizilir.
  var FOTO = {}, fotoBekleyen = [], cepheNormalleri = [];
  function canliDoku(w, h, ciz) {
    var c = document.createElement('canvas'); c.width = w; c.height = h;
    var d = new T.CanvasTexture(c); d.colorSpace = T.SRGBColorSpace; d.anisotropy = 4;
    function yap() { ciz(c.getContext('2d'), w, h); d.needsUpdate = true; }
    yap(); fotoBekleyen.push(yap);
    return d;
  }
  function fotoTex(im, rx, ry, renkli) {
    var t = new T.Texture(im); t.wrapS = t.wrapT = T.RepeatWrapping; t.repeat.set(rx, ry); t.anisotropy = 4;
    if (renkli) t.colorSpace = T.SRGBColorSpace;
    t.needsUpdate = true;
    return t;
  }
  function fotoYukle(bitti) {
    var adlar = ['asfalt', 'cim', 'kabuk', 'camur', 'duvar'], kalan = adlar.length * 2;
    adlar.forEach(function (ad) {
      ['', '-n'].forEach(function (ek) {
        var im = new Image();
        im.onload = function () { FOTO[ad + (ek ? 'N' : '')] = im; if (--kalan === 0) bitti(); };
        im.onerror = function () { if (--kalan === 0) bitti(); };
        im.src = 'assets/tex/' + ad + ek + '.jpg';
      });
    });
  }
  function fotoDose(g, im, w, h, boyut) {
    for (var y = 0; y < h; y += boyut) for (var x = 0; x < w; x += boyut) g.drawImage(im, x, y, boyut, boyut);
  }

  // ---------- Dokular ----------
  function tekrar(d, x, y) { d.wrapS = d.wrapT = T.RepeatWrapping; d.repeat.set(x, y); return d; }
  function cimDoku() {
    return tekrar(canliDoku(256, 256, function (g) {
      if (FOTO.cim) { g.drawImage(FOTO.cim, 0, 0, 256, 256); return; }
      g.fillStyle = '#d4d4d4'; g.fillRect(0, 0, 256, 256);
      for (var i = 0; i < 60; i++) { g.fillStyle = 'rgba(' + (i % 2 ? '255,255,255' : '0,0,0') + ',.06)'; g.beginPath(); g.arc(Math.random() * 256, Math.random() * 256, 8 + Math.random() * 26, 0, 6.28); g.fill(); }
      for (var j = 0; j < 2600; j++) {
        var x = Math.random() * 256, y = Math.random() * 256, l = Math.round(150 + Math.random() * 105);
        g.strokeStyle = 'rgba(' + l + ',' + l + ',' + l + ',.55)'; g.lineWidth = 1;
        g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.random() * 3 - 1.5, y - 3 - Math.random() * 6); g.stroke();
      }
    }), 10, 50);
  }
  function tasDoku() {
    return tekrar(tuvalDoku(256, 256, function (g) {
      g.fillStyle = '#d8d6d0'; g.fillRect(0, 0, 256, 256);
      for (var y = 0; y < 8; y++) for (var x = 0; x < 8; x++) {
        var l = 200 + Math.round(Math.random() * 40);
        g.fillStyle = 'rgb(' + l + ',' + l + ',' + (l - 6) + ')'; g.fillRect(x * 32 + 1, y * 32 + 1, 30, 30);
      }
    }), 10, 50);
  }
  function kaldirimDoku(doga) {
    return tekrar(canliDoku(128, 128, function (g) {
      if (doga && FOTO.cim) { g.drawImage(FOTO.cim, 0, 0, 128, 128); return; }
      if (doga) {
        g.fillStyle = '#cfcfcf'; g.fillRect(0, 0, 128, 128);
        for (var i = 0; i < 900; i++) { var l = 140 + Math.round(Math.random() * 115); g.fillStyle = 'rgb(' + l + ',' + l + ',' + l + ')'; g.fillRect(Math.random() * 128, Math.random() * 128, 1.5, 4); }
        return;
      }
      g.fillStyle = '#f3dfc2'; g.fillRect(0, 0, 128, 128);
      g.fillStyle = '#ead1ad'; g.fillRect(0, 0, 64, 64); g.fillRect(64, 64, 64, 64);
      g.strokeStyle = '#cfae84'; g.lineWidth = 2;
      for (var k = 0; k <= 128; k += 32) { g.beginPath(); g.moveTo(0, k); g.lineTo(128, k); g.stroke(); g.beginPath(); g.moveTo(k, 0); g.lineTo(k, 128); g.stroke(); }
      g.fillStyle = '#8f96a8'; g.fillRect(0, 0, 10, 128);
    }), 1, 60);
  }
  function yolDoku(ad) {
    var t = TEMA[ad];
    return tekrar(canliDoku(512, 512, function (g) {
      g.fillStyle = t.yol; g.fillRect(0, 0, 512, 512);
      var foto = t.doga ? FOTO.camur : FOTO.asfalt;
      if (foto) {
        g.drawImage(foto, 0, 0, 512, 512);
        g.globalAlpha = t.doga ? 0.35 : 0.5; g.fillStyle = t.yol; g.fillRect(0, 0, 512, 512); g.globalAlpha = 1;
      } else for (var i = 0; i < 9000; i++) { var a = Math.random(); g.fillStyle = 'rgba(' + (a > 0.5 ? '255,255,255' : '0,0,0') + ',' + (0.03 + Math.random() * 0.09) + ')'; g.fillRect(Math.random() * 512, Math.random() * 512, 1 + Math.random() * 2, 1 + Math.random() * 2); }
      for (var p = 0; p < 4; p++) { g.fillStyle = 'rgba(0,0,0,.07)'; g.fillRect(Math.random() * 400, Math.random() * 440, 60 + Math.random() * 80, 40 + Math.random() * 60); }
      g.strokeStyle = 'rgba(0,0,0,.28)'; g.lineWidth = 1.2;
      for (var c = 0; c < 10; c++) { var x = Math.random() * 512, y = Math.random() * 512; g.beginPath(); g.moveTo(x, y); for (var k = 0; k < 6; k++) { x += Math.random() * 30 - 15; y += Math.random() * 26 - 4; g.lineTo(x, y); } g.stroke(); }
      [0.19, 0.5, 0.81].forEach(function (u) { [-26, 26].forEach(function (d) { var gr = g.createLinearGradient(u * 512 + d - 14, 0, u * 512 + d + 14, 0); gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(0.5, 'rgba(0,0,0,.13)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(u * 512 + d - 14, 0, 28, 512); }); });
      g.fillStyle = t.serit;
      if (t.doga) {
        for (var k2 = 0; k2 < 260; k2++) { var l = 120 + Math.round(Math.random() * 100); g.fillStyle = 'rgba(' + l + ',' + Math.round(l * 0.85) + ',' + Math.round(l * 0.65) + ',.8)'; g.beginPath(); g.arc(Math.random() * 512, Math.random() * 512, 1 + Math.random() * 3.5, 0, 6.28); g.fill(); }
        g.fillStyle = 'rgba(60,90,30,.35)'; for (var o = 0; o < 40; o++) g.fillRect(Math.random() < 0.5 ? Math.random() * 30 : 482 + Math.random() * 30, Math.random() * 512, 3, 7);
      } else {
        g.globalAlpha = 0.92;
        g.fillRect(8, 0, 11, 512); g.fillRect(493, 0, 11, 512);
        g.fillRect(172, 48, 9, 240); g.fillRect(331, 48, 9, 240);
        g.globalAlpha = 1;
        g.fillStyle = 'rgba(0,0,0,.25)'; for (var w = 0; w < 300; w++) g.fillRect(8 + Math.random() * 496, Math.random() * 512, 1, 1);
        g.strokeStyle = 'rgba(30,30,32,.9)'; g.lineWidth = 3; g.beginPath(); g.arc(256, 420, 22, 0, 6.28); g.stroke();
        g.fillStyle = 'rgba(40,40,44,.8)'; g.beginPath(); g.arc(256, 420, 19, 0, 6.28); g.fill();
      }
    }), 1, 40);
  }
  function gokDoku(ad) {
    var t = TEMA[ad], sis = '#' + new T.Color(t.sis).getHexString();
    return tuvalDoku(4, 256, function (g) {
      var gr = g.createLinearGradient(0, 0, 0, 256);
      gr.addColorStop(0, t.gok[0]); gr.addColorStop(0.3, t.gok[1]); gr.addColorStop(0.47, t.gok[2]); gr.addColorStop(0.5, sis); gr.addColorStop(1, sis);
      g.fillStyle = gr; g.fillRect(0, 0, 4, 256);
    });
  }
  function cepheDoku(zemin, tohum, cerceve) {
    cerceve = cerceve || '#fbf6ec';
    return canliDoku(512, 232, function (g) {
      g.fillStyle = zemin; g.fillRect(0, 0, 512, 232);
      if (FOTO.duvar) {
        g.globalCompositeOperation = 'multiply'; g.globalAlpha = 0.42; fotoDose(g, FOTO.duvar, 512, 232, 256);
        g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
      } else for (var i = 0; i < 2500; i++) { g.fillStyle = 'rgba(' + (i % 2 ? '255,255,255' : '0,0,0') + ',.05)'; g.fillRect(Math.random() * 512, Math.random() * 232, 2, 2); }
      var lekeGr = g.createLinearGradient(0, 0, 0, 232); lekeGr.addColorStop(0, 'rgba(0,0,0,0)'); lekeGr.addColorStop(1, 'rgba(0,0,0,.12)'); g.fillStyle = lekeGr; g.fillRect(0, 0, 512, 232);
      g.fillStyle = 'rgba(255,255,255,.55)'; g.fillRect(0, 214, 512, 10);
      g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(0, 224, 512, 4);
      for (var w = 0; w < 3; w++) {
        var x = 46 + w * 160, y = 42, ww = 100, hh = 140;
        g.fillStyle = 'rgba(0,0,0,.28)'; g.fillRect(x - 9, y - 9, ww + 18, hh + 18);
        g.fillStyle = cerceve; g.fillRect(x - 7, y - 7, ww + 14, hh + 14);
        var cam = g.createLinearGradient(x, y, x + ww * 0.4, y + hh);
        var yanik = (tohum * 7 + w * 3) % 9 === 0;
        cam.addColorStop(0, yanik ? '#ffe9a8' : '#c9ecff'); cam.addColorStop(0.5, yanik ? '#ffc35c' : '#5cb0ec'); cam.addColorStop(1, yanik ? '#e08a2e' : '#2366a8');
        g.fillStyle = cam; g.fillRect(x, y, ww, hh);
        if ((tohum + w) % 3 === 1) { g.fillStyle = 'rgba(240,235,225,.85)'; g.fillRect(x, y, ww * 0.35, hh); g.fillRect(x + ww * 0.65, y, ww * 0.35, hh); }
        g.fillStyle = cerceve; g.fillRect(x + ww / 2 - 3, y, 6, hh); g.fillRect(x, y + hh * 0.38, ww, 5);
        g.fillStyle = 'rgba(255,255,255,.35)'; g.beginPath(); g.moveTo(x + 8, y + hh); g.lineTo(x + 30, y); g.lineTo(x + 44, y); g.lineTo(x + 22, y + hh); g.fill();
        g.fillStyle = '#fffaf0'; g.fillRect(x - 12, y + hh + 7, ww + 24, 9);
        g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(x - 12, y + hh + 16, ww + 24, 4);
        if ((tohum * 3 + w) % 4 === 0) { g.fillStyle = '#d9d9d6'; g.fillRect(x + ww + 14, y + hh - 50, 30, 36); g.fillStyle = '#8f9196'; for (var z = 0; z < 5; z++) g.fillRect(x + ww + 17, y + hh - 46 + z * 7, 24, 2); }
      }
    });
  }
  function pencereDoku(zemin, cam) {
    return tuvalDoku(128, 256, function (g) {
      g.fillStyle = zemin; g.fillRect(0, 0, 128, 256);
      for (var y = 14; y < 250; y += 30) for (var x = 12; x < 118; x += 28) {
        g.fillStyle = (x * 7 + y * 3) % 11 < 3 ? '#ffe8a3' : cam; g.fillRect(x, y, 17, 20);
        g.fillStyle = 'rgba(255,255,255,.35)'; g.fillRect(x, y, 17, 4);
        g.fillStyle = 'rgba(0,0,0,.18)'; g.fillRect(x - 2, y + 20, 21, 3);
      }
    });
  }
  function tahtaMat() {
    return mCache.tahta || (mCache.tahta = new T.MeshLambertMaterial({ map: tuvalDoku(128, 128, function (g) {
      for (var i = 0; i < 6; i++) { var l = 150 + (i % 2) * 22; g.fillStyle = 'rgb(' + l + ',' + Math.round(l * 0.72) + ',' + Math.round(l * 0.45) + ')'; g.fillRect(0, i * 22, 128, 21); }
      g.strokeStyle = 'rgba(60,35,15,.5)'; g.lineWidth = 2; for (var j = 0; j < 30; j++) { var y = Math.random() * 128; g.beginPath(); g.moveTo(0, y); g.bezierCurveTo(40, y + 4, 80, y - 4, 128, y); g.stroke(); }
    }) }));
  }
  function kayaMat() {
    return mCache.kaya || (mCache.kaya = new T.MeshLambertMaterial({ map: tuvalDoku(128, 128, function (g) {
      g.fillStyle = '#857a6c'; g.fillRect(0, 0, 128, 128);
      for (var i = 0; i < 260; i++) { var l = 90 + Math.round(Math.random() * 90); g.fillStyle = 'rgb(' + l + ',' + Math.round(l * 0.93) + ',' + Math.round(l * 0.82) + ')'; g.beginPath(); g.arc(Math.random() * 128, Math.random() * 128, 2 + Math.random() * 7, 0, 6.28); g.fill(); }
    }) }));
  }

  // ---------- Çevre prototipleri ----------
  function prototipler() {
    var P = { sehir: [], otoyol: { sol: [], sag: [] }, orman: [], in: [] };
    var dukkan = [['BERBER', 0xe8845c, '#1c2023', '#ffffff'], ['FIRIN', 0x5aa7b8, '#1c2023', '#ffffff'], ['tarak.app', 0x3a3e47, '#1c2023', '#d9a45b'], ['ÇAY EVİ', 0xd9a441, '#7a2d1e', '#ffffff'], ['MANAV', 0x7fae62, '#1c2023', '#ffffff'], ['KIRTASİYE', 0xb77fb0, '#1c2023', '#ffffff']];
    var dukkanK = [['KUAFÖR', 0xe8845c, '#1c2023', '#ffffff'], ['GÜZELLİK', 0x5aa7b8, '#1c2023', '#ffffff'], ['tarak.app', 0x3a3e47, '#1c2023', '#d9a45b'], ['MANİKÜR', 0xd9a441, '#7a2d1e', '#ffffff'], ['ÇİÇEKÇİ', 0x7fae62, '#1c2023', '#ffffff'], ['BUTİK', 0xb77fb0, '#1c2023', '#ffffff']];
    var camlar = ['#9fd3ee', '#8fc3e8', '#b5dcf0'];
    function binaYap(d, i, stilAd, sade) {
      var st = STILLER[stilAd] || STILLER.tarihi;
      var g = new T.Group(), katSayisi = Math.max(1, 2 + (i % 3) + st.kat), h = katSayisi * 3;
      var cepheRenk = st.cephe[i], tente = st.tente[i], korniz = st.korniz[i];
      var dk = cepheDoku(cepheRenk, i + 1, st.cerceve); dk.wrapS = dk.wrapT = T.RepeatWrapping; dk.repeat.set(1, katSayisi);
      var duvar = new T.MeshStandardMaterial({ map: dk, roughness: 0.92, metalness: 0 });
      cepheNormalleri.push({ m: duvar, kat: katSayisi });
      void camlar;
      ekle(g, kutuG(4, h, 6.6), duvar, 2.2, h / 2 + 2.4, 0);
      ekle(g, kutuG(4.3, 0.35, 6.9), mat(korniz), 2.15, h + 2.55, 0);
      ekle(g, kutuG(0.25, 0.6, 6.9), mat(korniz), 0.15, h + 2.95, 0);
      ekle(g, kutuG(0.18, h, 0.3), mat(korniz), 0.12, h / 2 + 2.4, -3.2); ekle(g, kutuG(0.18, h, 0.3), mat(korniz), 0.12, h / 2 + 2.4, 3.2);
      if (i % 2 === 0) { ekle(g, silG(0.5, 0.5, 1.1, 14), mat(0xd9dce1, { metalness: 0.6, roughness: 0.4 }), 3, h + 3.3, -1.8); ekle(g, silG(0.02, 0.02, 1.8, 4), mat(0x555555), 3.4, h + 3.6, 2); }
      for (var kat = 1; kat < katSayisi; kat++) {
        if ((i + kat) % 2) continue;
        var by = 2.4 + kat * 3;
        ekle(g, kutuG(0.75, 0.12, 2.0), mat(0xe2ddd3), -0.2, by, 0);
        ekle(g, kutuG(0.04, 0.85, 2.0), new T.MeshStandardMaterial({ color: 0x9fb8c8, transparent: true, opacity: 0.45, roughness: 0.1, metalness: 0.3 }), -0.56, by + 0.48, 0);
        ekle(g, kutuG(0.06, 0.06, 2.0), mat(0x3a3c40, { metalness: 0.7, roughness: 0.35 }), -0.56, by + 0.92, 0);
      }
      ekle(g, kutuG(4, 2.4, 6.6), mat(d[1]), 2.2, 1.2, 0);
      ekle(g, kutuG(4.2, 0.25, 6.8), mat(0x6d6a66), 2.2, h + 2.5, 0);
      if (st.cumba) for (var cb = 1; cb < katSayisi; cb++) {   // Osmanlı cumbası: üst katlarda yola taşan çıkma
        ekle(g, kutuG(0.9, 2.5, 3.6), mat(new T.Color(cepheRenk).offsetHSL(0, 0, 0.06).getHex()), -0.25, 2.4 + cb * 3 + 1.25, 0);
        ekle(g, kutuG(0.06, 1.2, 3.0), mat(0xcfeefa, { emissive: 0x223844 }), -0.71, 2.4 + cb * 3 + 1.35, 0);
        ekle(g, kutuG(1.0, 0.14, 3.8), mat(0x5a3b24), -0.25, 2.4 + cb * 3, 0);
        for (var kr = -1; kr <= 1; kr += 2) { var kz = ekle(g, kutuG(0.08, 0.9, 0.08), mat(0x5a3b24), -0.5, 2.4 + cb * 3 - 0.3, kr * 1.5); kz.rotation.z = 0.6; }
      }
      if (st.begonvil) [-2.2, 1.4].forEach(function (z) { for (var bv = 0; bv < 6; bv++) ekle(g, kureG(0.32, 8), mat(bv % 2 ? 0xe0408f : 0xff5fae), -0.05, 2.9 + (bv % 3) * 0.55, z + (bv % 2) * 0.5); });
      var tab = i === 2 ? new T.Mesh(new T.PlaneGeometry(4.6, 0.8), MD.logoMat('#1c2023', 4.6, 0.8)) : yaziPlakasi(4.6, 0.8, d[0], d[2], d[3]);
      tab.position.set(0.12, 2.55, 0); tab.rotation.y = -Math.PI / 2; g.add(tab);
      ekle(g, kutuG(0.12, 0.9, 4.8), mat(0x22252b), 0.16, 2.55, 0);
      ekle(g, kutuG(0.08, 1.6, 2.6), mat(0xcfeefa, { emissive: 0x223844 }), 0.19, 1.05, -1.2);
      ekle(g, kutuG(0.08, 1.9, 1.1), mat(0x5a3b2e), 0.19, 0.95, 1.7);
      for (var s = 0; s < 10; s++) { var t = ekle(g, kutuG(0.95, 0.08, 0.62), mat(s % 2 ? 0xffffff : tente), -0.25, 1.98, -2.8 + s * 0.62); t.rotation.z = 0.32; }
      for (var s2 = 0; s2 < 10; s2++) ekle(g, kutuG(0.06, 0.22, 0.6), mat(s2 % 2 ? 0xffffff : tente), -0.7, 1.74, -2.8 + s2 * 0.62);
      // Sokak eşyası (saksı, lamba, ağaç, berber direği). Gerçek caddede (sade) konmaz: oradakiler OSM'den gelir
      if (!sade) {
      ekle(g, kutuG(0.42, 0.36, 1.7), mat(0x7a4a32), -0.2, 0.3, -1.2);
      [0xff4f7a, 0xffd23f, 0xff7a3d, 0xffffff, 0xd94fff].forEach(function (rk, f) { ekle(g, kureG(0.17, 8), mat(rk), -0.2 + (f % 2) * 0.08 - 0.04, 0.55, -1.85 + f * 0.33); });
      ekle(g, kutuG(0.3, 0.14, 1.6), mat(0x3f9a3c), -0.2, 0.5, -1.2);
      if (i % 2 === 0) { // sokak lambası
        ekle(g, silG(0.06, 0.08, 4.6, 8), mat(0x2f3238), -1.25, 2.3, -3);
        ekle(g, kutuG(0.9, 0.06, 0.06), mat(0x2f3238), -1.65, 4.55, -3);
        ekle(g, kutuG(0.36, 0.1, 0.22), mat(0xfff3c4, { emissive: 0x7a6a30 }), -2.05, 4.48, -3);
      } else { // ağaç
        var ag = MD.agacYaprakli(0.72, [0x3f7d34, 0x4b8c3f, 0x356b32]); ag.position.set(-1.05, 0.12, 2.4); g.add(ag);
        ekle(g, kutuG(0.9, 0.06, 0.9), mat(0x6b5a44), -1.05, 0.14, 2.4);
      }
      if (i === 0 || i === 2) {
        var direk = new T.MeshLambertMaterial({ map: tuvalDoku(32, 128, function (c) { c.fillStyle = '#fff'; c.fillRect(0, 0, 32, 128); for (var y = -32; y < 160; y += 32) { c.fillStyle = '#e03b3b'; c.beginPath(); c.moveTo(0, y); c.lineTo(32, y - 16); c.lineTo(32, y - 6); c.lineTo(0, y + 10); c.fill(); c.fillStyle = '#2f6fd6'; c.beginPath(); c.moveTo(0, y + 16); c.lineTo(32, y); c.lineTo(32, y + 10); c.lineTo(0, y + 26); c.fill(); } }) });
        ekle(g, silG(0.13, 0.13, 1.1, 14), direk, -0.05, 1.25, 0.65);
        ekle(g, kureG(0.16, 10), mat(0xc9ccd4), -0.05, 1.86, 0.65);
      }
      }
      return birlestir(g);
    }
    P.sehir = dukkan.map(function (d, i) { return binaYap(d, i, 'tarihi'); });
    P.sehirK = dukkanK.map(function (d, i) { return binaYap(d, i, 'tarihi'); });
    // Diğer bina stilleri ve özel yuvalar ihtiyaç olunca bir kez üretilir
    P.stil = function (stilAd, kadin, sade) {
      var k = 'sehir|' + stilAd + '|' + (kadin ? 'k' : 'e') + (sade ? '|s' : '');
      if (stilAd === 'tarihi' && !sade) return kadin ? P.sehirK : P.sehir;
      return P[k] || (P[k] = (kadin ? dukkanK : dukkan).map(function (d, i) { return binaYap(d, i, stilAd, sade); }));
    };
    P.ozel = function (ad) {
      if (P['o|' + ad]) return P['o|' + ad];
      var l = ad === 'sahil' ? [YER.sahil(false), YER.sahil(false)] : ad === 'gol' ? [YER.sahil(true)] : ad === 'kopru' ? [YER.kopruYuvasi()] : [1, 2, 3, 4].map(function (t) { return YER.periYuvasi(t); });
      return (P['o|' + ad] = l.map(birlestir));
    };

    // Otoyol: solda karşı yön şeritleri, sağda tepeler ve reklam panosu
    function bariyer(g) {
      for (var b = -3; b <= 3; b += 2) ekle(g, kutuG(0.12, 0.8, 0.12), mat(0x8f8da3), 0.35, 0.4, b);
      ekle(g, kutuG(0.1, 0.28, 7.8), mat(0xd6d4e4), 0.28, 0.72, 0);
    }
    function karsiYol(g) {
      var a = ekle(g, new T.PlaneGeometry(6.4, 7.7), mat(0x3d3e46), 4.4, 0.012, 0); a.rotation.x = -Math.PI / 2;
      ekle(g, kutuG(0.12, 0.01, 3.2), mat(0xf4f1e6), 4.4, 0.02, -1.6);
      ekle(g, kutuG(0.1, 0.01, 7.7), mat(0xffd23f), 1.35, 0.02, 0);
      ekle(g, kutuG(0.1, 0.01, 7.7), mat(0xf4f1e6), 7.45, 0.02, 0);
      for (var b = -3; b <= 3; b += 2) ekle(g, kutuG(0.12, 0.75, 0.12), mat(0x8f8da3), 7.9, 0.37, b);
      ekle(g, kutuG(0.1, 0.25, 7.8), mat(0xd6d4e4), 7.85, 0.66, 0);
    }
    function lamba(g, x) {
      ekle(g, silG(0.08, 0.11, 5.4, 8), mat(0x3a3d45), x, 2.7, 0);
      ekle(g, kutuG(1.6, 0.1, 0.14), mat(0x3a3d45), x - 0.75, 5.35, 0);
      ekle(g, kutuG(0.45, 0.1, 0.24), mat(0xffeaa0, { emissive: 0x8a7a40 }), x - 1.5, 5.28, 0);
    }
    for (var o = 0; o < 3; o++) {
      var sl = new T.Group(); bariyer(sl); karsiYol(sl); if (o === 0) lamba(sl, 0.6);
      var tp = new T.Group(); tp.add(yer(MD.kaya(0.6, 0x6f7a46), 9 + o * 2, 0, -1.5));
      P.otoyol.sol.push(birlestir(sl));
      var sg = new T.Group(); bariyer(sg);
      if (o === 0) lamba(sg, 0.6);
      if (o === 1) { var tepe = ekle(sg, kureG(5, 14), mat(0x6b7340), 9, -0.8, 0); tepe.scale.set(1, 0.7, 1.2); sg.add(yer(MD.agacYaprakli(1.1, [0x56743a, 0x627f40]), 6, 0, 2.5)); }
      if (o === 2) {
        ekle(sg, silG(0.1, 0.1, 3.4, 8), mat(0x3b3d45), 1.6, 1.7, 0); ekle(sg, silG(0.1, 0.1, 3.4, 8), mat(0x3b3d45), 4.6, 1.7, 0.4);
        var yz = new T.Mesh(new T.PlaneGeometry(3.8, 1.8), MD.logoMat('#1c2023', 3.8, 1.8, 'Berber Kuaför Çağır · Ücretsiz')); yz.position.set(3.1, 4.2, 0.2); yz.rotation.y = -0.4; sg.add(yz);
      }
      sg.add(yer(MD.cali(1, 0x5d7a3a), 3.2, 0, -2.5));
      P.otoyol.sag.push(birlestir(sg));
    }

    // Orman: ağaçlar, çalılar, kayalar, devrilmiş kütükler
    var yesil = [[0x2f6b34, 0x3c7b3a, 0x275a2e], [0x4b8c3f, 0x3f7d34, 0x5a9a48], [0x356b32, 0x2c5c2b, 0x447f3a]];
    for (var v = 0; v < 5; v++) {
      var g = new T.Group();
      g.add(yer(v % 2 ? MD.agacCam(1.1, yesil[v % 3]) : MD.agacYaprakli(1.15, yesil[v % 3]), 1.9, 0, -1.5));
      g.add(yer(v < 2 ? MD.agacYaprakli(0.95, yesil[(v + 1) % 3]) : MD.agacCam(1.4, yesil[(v + 2) % 3]), 4.6, 0, 2.0));
      g.add(yer(MD.agacCam(1.7, yesil[2]), 8, 0, -0.5));
      g.add(yer(MD.agacYaprakli(1.5, yesil[0]), 11.5, 0, 2.5));
      g.add(yer(MD.cali(0.8 + v * 0.1, 0x3f7a34), 0.9, 0, 2.6));
      g.add(yer(MD.kaya(0.5 + v * 0.12, 0x868a8e), 0.8, 0, -3));
      g.add(yer(MD.cimTutam(0x5a9a48, 1.2), 0.4, 0, 0.6));
      g.add(yer(MD.cimTutam(0x4b8c3f, 1), 0.6, 0, -1.6));
      if (v === 3) { var kt = ekle(g, silG(0.3, 0.34, 3.2, 10), mat(0x5d4128), 3.2, 0.32, 0); kt.rotation.set(0, 0.5, Math.PI / 2); }
      P.orman.push(birlestir(g));
    }
    // Aslanın İni: akasyalar, kaya tepeleri, kuru otlar, termit tepeleri
    for (var w = 0; w < 5; w++) {
      var a = new T.Group();
      if (w % 2 === 0) a.add(yer(MD.akasya(1 + w * 0.1), 2.6, 0, -1));
      a.add(yer(MD.kaya(1 + w * 0.4, 0x8a5a45), 2.2 + w * 0.7, 0, 2));
      a.add(yer(MD.kaya(2.6, 0x6d3f33), 9, 0, -2));
      a.add(yer(MD.cimTutam(0xc9a24a, 1.4), 0.5, 0, 0.5));
      a.add(yer(MD.cimTutam(0xb08a3a, 1.2), 0.9, 0, -2.2));
      a.add(yer(MD.cimTutam(0xd2ad55, 1.3), 1.4, 0, 2.8));
      if (w === 1 || w === 4) { var tt = ekle(a, MD.puruzlu(new T.ConeGeometry(0.7, 2.2, 9, 3), 0.2), mat(0x9a6a3a), 3.8, 1.1, 1); tt.scale.set(1, 1, 0.9); }
      if (w === 3) a.add(yer(MD.akasya(1.4), 6, 0, 1));
      P.in.push(birlestir(a));
    }
    return P;
  }

  // ---------- Engeller ----------
  // Tıknaz, yuvarlak köşeli parçalar ve şeritli boyalar (çizgi film görünümü)
  function yuvG(w, h, d, r) { var k = 'r' + w + '_' + h + '_' + d + '_' + r; return gCache[k] || (gCache[k] = new T.RoundedBoxGeometry(w, h, d, 3, r)); }
  // yon: 0 dikey çubuk, 1 eğik, 2 yatay bant
  function seritMat(a, b, n, yon) {
    var k = 'st|' + a + b + n + yon;
    if (!mCache[k]) mCache[k] = new T.MeshStandardMaterial({ roughness: 0.62, metalness: 0, map: tuvalDoku(128, 128, function (g) {
      g.fillStyle = a; g.fillRect(0, 0, 128, 128); g.fillStyle = b;
      var w = 128 / n;
      for (var i = -2; i <= n + 1; i++) {
        g.beginPath();
        if (yon === 1) { g.moveTo(i * w, 128); g.lineTo(i * w + w / 2, 128); g.lineTo(i * w + w / 2 + 64, 0); g.lineTo(i * w + 64, 0); }
        else if (yon === 2) g.rect(0, i * w, 128, w / 2);
        else g.rect(i * w, 0, w / 2, 128);
        g.fill();
      }
    }) });
    return mCache[k];
  }
  function lambaM(renk) { return mat(renk, { emissive: renk, emissiveIntensity: 2.6, roughness: 0.3 }); }
  function parlakM(renk) { return mat(renk, { roughness: 0.35 }); }
  function ampuller(g, w, h, x0, y0, z) { // tabela çevresinde sıra ampuller
    var m = lambaM(0xfff1b0), ad = Math.max(4, Math.round(w / 0.2));
    for (var i = 0; i <= ad; i++) { var x = x0 - w / 2 + i * w / ad; ekle(g, kureG(0.045, 6), m, x, y0 + h / 2, z); ekle(g, kureG(0.045, 6), m, x, y0 - h / 2, z); }
  }

  function kentEngel(tur, boy, cesit) {
    var g = new T.Group();
    var turuncu = parlakM(0xff7a1a), koyu = parlakM(0x2b2e35), beyaz = parlakM(0xffffff);
    if (tur === 'bariyer') {
      if (cesit === 0) { // klasik yol bariyeri: eğik şeritli kalın pano, ayaklar, yanıp sönen lambalar
        ekle(g, yuvG(1.64, 0.34, 0.18, 0.07), seritMat('#ffffff', '#e8322c', 4, 1), 0, 0.66, -0.2);
        ekle(g, yuvG(1.4, 0.16, 0.14, 0.05), seritMat('#ffffff', '#e8322c', 4, 1), 0, 0.34, -0.2);
        [-0.62, 0.62].forEach(function (x) {
          ekle(g, yuvG(0.14, 0.8, 0.14, 0.05), turuncu, x, 0.42, -0.2);
          ekle(g, yuvG(0.26, 0.09, 0.5, 0.04), koyu, x, 0.045, -0.2);
          ekle(g, silG(0.05, 0.06, 0.06, 10), koyu, x, 0.85, -0.2);
          ekle(g, kureG(0.1, 10), lambaM(0xffa31a), x, 0.93, -0.2);
        });
      } else if (cesit === 1) { // üç tombul koni ve üstünde şeritli çubuk
        [-0.58, 0, 0.58].forEach(function (x) {
          ekle(g, yuvG(0.5, 0.07, 0.5, 0.03), parlakM(0xd9480f), x, 0.035, -0.25);
          ekle(g, silG(0.05, 0.27, 0.68, 18), turuncu, x, 0.41, -0.25);
          ekle(g, silG(0.155, 0.2, 0.13, 18), beyaz, x, 0.42, -0.25);
          ekle(g, kureG(0.065, 8), turuncu, x, 0.75, -0.25);
        });
        ekle(g, yuvG(1.66, 0.13, 0.12, 0.05), seritMat('#ffc400', '#1c2023', 6, 1), 0, 0.68, -0.25);
      } else { // kırmızı-beyaz beton blok
        ekle(g, yuvG(1.64, 0.32, 0.52, 0.09), seritMat('#ffffff', '#e8322c', 3, 0), 0, 0.16, -0.25);
        ekle(g, yuvG(1.5, 0.44, 0.3, 0.09), seritMat('#ffffff', '#e8322c', 3, 0), 0, 0.53, -0.25);
        [-0.55, 0.55].forEach(function (x) { ekle(g, yuvG(0.16, 0.08, 0.04, 0.02), lambaM(0xffa31a), x, 0.58, -0.09); });
      }
    } else if (tur === 'koli') { // tombul karton koli: bant, logo etiketi
      ekle(g, yuvG(1.28, 0.92, 0.8, 0.08), parlakM(0xd99a5b), 0, 0.47, -0.4);
      ekle(g, yuvG(0.28, 0.94, 0.82, 0.05), parlakM(0xf6e0b0), 0, 0.47, -0.4);
      ekle(g, yuvG(1.3, 0.1, 0.82, 0.04), parlakM(0xc4834a), 0, 0.9, -0.4);
      var et = new T.Mesh(new T.PlaneGeometry(0.74, 0.3), MD.logoMat('#1c2023', 0.74, 0.3)); et.position.set(0, 0.64, 0.012); g.add(et);
      var y = yaziPlakasi(0.7, 0.2, '⚠ KIRILIR', '#f6e0b0', '#c0392b'); y.position.set(0, 0.3, 0.012); g.add(y);
    } else if (tur === 'cukur') { // yol çalışması çukuru: kalın şeritli kenarlar, koniler, lambalar
      var ac = ekle(g, new T.PlaneGeometry(1.7, boy), new T.MeshBasicMaterial({ color: 0x1a0f0a }), 0, 0.012, -boy / 2); ac.rotation.x = -Math.PI / 2;
      var ic = ekle(g, new T.PlaneGeometry(1.3, boy - 0.5), new T.MeshBasicMaterial({ color: 0x080404 }), 0, 0.014, -boy / 2); ic.rotation.x = -Math.PI / 2;
      [0.12, -boy - 0.12].forEach(function (z) { ekle(g, yuvG(1.8, 0.12, 0.22, 0.05), seritMat('#ffc400', '#1c2023', 6, 1), 0, 0.06, z); });
      [-0.88, 0.88].forEach(function (x) { ekle(g, yuvG(0.12, 0.1, boy + 0.2, 0.04), seritMat('#ffc400', '#1c2023', 6, 2), x, 0.05, -boy / 2); });
      [-0.78, 0.78].forEach(function (x) {
        ekle(g, silG(0.04, 0.17, 0.52, 14), turuncu, x, 0.38, 0.22);
        ekle(g, silG(0.1, 0.13, 0.09, 14), beyaz, x, 0.4, 0.22);
        ekle(g, kureG(0.07, 8), lambaM(0xffa31a), x, 0.68, 0.22);
      });
    } else if (tur === 'kapi') { // ampullü dev tabela altından kayılır
      [-0.86, 0.86].forEach(function (x) {
        ekle(g, yuvG(0.17, 2.9, 0.17, 0.06), seritMat('#ffffff', '#e8322c', 4, 2), x, 1.45, -0.3);
        ekle(g, yuvG(0.32, 0.1, 0.32, 0.04), koyu, x, 0.05, -0.3);
      });
      ekle(g, yuvG(1.9, 1.22, 0.24, 0.1), koyu, 0, 1.7, -0.3);
      var p = yaziPlakasi(1.66, 1.0, (KADIN ? 'KUAFÖR' : 'BERBER') + '\n▼ KAY ▼', KADIN ? '#ff7eb3' : '#ffc400', '#1c2023'); p.position.set(0, 1.7, -0.175); g.add(p);
      ampuller(g, 1.7, 1.12, 0, 1.7, -0.17);
    } else if (tur === 'tunel') { // renkli iskele tüneli
      var aralik = Math.max(2.5, (boy - 0.4) / Math.ceil(boy / 4));
      [-0.9, 0.9].forEach(function (x) { for (var z = 0.2; z <= boy; z += aralik) ekle(g, yuvG(0.16, 2.5, 0.16, 0.05), seritMat('#ffffff', '#e8322c', 4, 2), x, 1.25, -z); });
      ekle(g, yuvG(1.96, 1.36, boy, 0.16), parlakM(0x1fa3a3), 0, 1.78, -boy / 2);
      ekle(g, yuvG(2.0, 0.22, boy - 0.2, 0.08), parlakM(0xffc400), 0, 2.4, -boy / 2);
      ekle(g, yuvG(2.0, 0.2, 0.2, 0.06), seritMat('#ffc400', '#1c2023', 7, 1), 0, 1.2, 0.02);
      var s = yaziPlakasi(1.78, 0.78, '⏩ TURBO ×2\nİKİ KEZ KAY', '#1c2023', '#ffc400'); s.position.set(0, 1.84, 0.02); g.add(s);
      ampuller(g, 1.8, 0.86, 0, 1.84, 0.03);
    } else if (tur === 'kule') { // üst üste renkli kasalar: çift zıpla
      [0xe8413c, 0x2f7fe0, 0xffc400].forEach(function (rk, k) {
        var y = 0.32 + k * 0.64;
        ekle(g, yuvG(1.36 - k * 0.04, 0.6, 0.76, 0.08), parlakM(rk), 0, y, -0.4);
        ekle(g, yuvG(1.38 - k * 0.04, 0.09, 0.78, 0.03), parlakM(new T.Color(rk).multiplyScalar(0.62).getHex()), 0, y, -0.4);
      });
      var ok = yaziPlakasi(0.8, 0.34, '▲▲', '#1c2023', '#ffffff', 0, 128); ok.position.set(0, 1.62, 0.0); g.add(ok);
    }
    return g;
  }

  function dogaEngel(tur, boy, cesit) {
    var g = new T.Group(), kabuk = MD.kabukMat(), ic = mat(0xc9a16b);
    if (tur === 'bariyer') {
      if (cesit === 0) { // yolda yatan aslan
        var a = MD.aslan(false); a.guncelle('yat', 1);
        a.kok.rotation.y = Math.PI / 2 + 0.25; a.kok.scale.setScalar(0.82); a.kok.position.z = -0.3; g.add(a.kok);
      } else if (cesit === 1) {
        var kt = ekle(g, silG(0.36, 0.38, 1.7, 14), kabuk, 0, 0.37, -0.3); kt.rotation.z = Math.PI / 2;
        [-1, 1].forEach(function (y) { var u = ekle(g, new T.CircleGeometry(0.34, 14), ic, y * 0.86, 0.37, -0.3); u.rotation.y = y * Math.PI / 2; });
        g.add(yer(MD.cali(0.35, 0x4f7a2c), 0.4, 0.45, -0.3));
        var dal = ekle(g, silG(0.04, 0.06, 0.6, 6), kabuk, -0.3, 0.75, -0.3); dal.rotation.z = 0.6;
      } else {
        g.add(yer(MD.kaya(0.85, 0x8b8680), -0.4, 0, -0.3));
        g.add(yer(MD.kaya(0.7, 0x77736d), 0.45, 0, -0.2));
        g.add(yer(MD.kaya(0.45, 0x9a958e), 0.05, 0.25, -0.45));
      }
    } else if (tur === 'koli') {
      ekle(g, yuvG(1.25, 0.9, 0.8, 0.07), tahtaMat(), 0, 0.46, -0.4);
      [-0.6, 0.6].forEach(function (x) { ekle(g, yuvG(0.12, 0.94, 0.84, 0.04), parlakM(0x7a4e26), x, 0.46, -0.4); });
      ekle(g, yuvG(1.3, 0.1, 0.84, 0.04), parlakM(0x7a4e26), 0, 0.88, -0.4);
      ekle(g, yuvG(1.3, 0.1, 0.84, 0.04), parlakM(0x7a4e26), 0, 0.05, -0.4);
      var cz = ekle(g, yuvG(1.4, 0.1, 0.04, 0.03), parlakM(0x7a4e26), 0, 0.46, 0.01); cz.rotation.z = 0.55;
      var y = yaziPlakasi(0.8, 0.24, 'KIRILIR', '#d9b27a', '#4a2c12'); y.position.set(0, 0.5, 0.012); g.add(y);
    } else if (tur === 'cukur') {
      var ca = ekle(g, new T.PlaneGeometry(1.75, boy), MD.std(0x3a2714, 0.12, 0), 0, 0.012, -boy / 2); ca.rotation.x = -Math.PI / 2;
      for (var i = 0; i < 6; i++) g.add(yer(MD.kaya(0.22, 0x7d7468), (i % 2 ? 1 : -1) * 0.9, 0, -i * boy / 5));
      var tabela = yaziPlakasi(0.6, 0.3, 'ÇAMUR!', '#d9b27a', '#4a2c12'); tabela.position.set(-0.75, 0.55, 0.3); g.add(tabela);
      ekle(g, silG(0.03, 0.03, 0.5, 6), kabuk, -0.75, 0.25, 0.28);
    } else if (tur === 'kapi') { // devrilmiş ağacın altından kayılır
      [-0.88, 0.88].forEach(function (x) { var d = ekle(g, silG(0.15, 0.2, 1.9, 8), kabuk, x, 0.95, -0.3); d.rotation.z = x > 0 ? -0.08 : 0.08; });
      var lg = ekle(g, silG(0.27, 0.3, 2.2, 12), kabuk, 0, 1.47, -0.3); lg.rotation.z = Math.PI / 2;
      g.add(yer(MD.cali(0.55, 0x3f7a34), -0.4, 1.55, -0.3)); g.add(yer(MD.cali(0.45, 0x4b8c3f), 0.55, 1.6, -0.25));
      [-0.5, 0.1, 0.6].forEach(function (x) { ekle(g, silG(0.015, 0.015, 0.3, 4), mat(0x3d6b2a), x, 1.08 + 0.15, -0.2); });
      var t = yaziPlakasi(0.9, 0.28, '▼ KAY ▼', '#ffc400', '#3b2a14'); t.position.set(0, 1.2, -0.02); g.add(t);
    } else if (tur === 'tunel') {
      ekle(g, yuvG(1.95, 1.3, boy, 0.18), kayaMat(), 0, 1.75, -boy / 2);
      ekle(g, yuvG(2.05, 0.28, boy - 0.3, 0.12), parlakM(0x4fa83a), 0, 2.42, -boy / 2);
      for (var cc = 0; cc < boy; cc += 2.2) g.add(yer(MD.cali(0.4 + (cc % 3) * 0.1, 0x3f9a34), (cc % 4 < 2 ? -0.6 : 0.65), 2.5, -cc - 0.8));
      [-0.99, 0.99].forEach(function (x) { ekle(g, yuvG(0.24, 1.12, boy, 0.08), kayaMat(), x, 0.56, -boy / 2); });
      for (var k = 0; k < 5; k++) ekle(g, silG(0.02, 0.02, 0.3, 4), mat(0x5d4128), -0.6 + k * 0.3, 1.12 + 0.12, -0.1 - k * 0.7);
      var s2 = yaziPlakasi(1.6, 0.6, '⏩ TURBO ×2\nİKİ KEZ KAY', '#3b2a14', '#ffc400'); s2.position.set(0, 1.85, 0.012); g.add(s2);
    } else if (tur === 'kule') {
      for (var kat = 0; kat < 3; kat++) for (var n = 0; n < 2; n++) {
        var kk = ekle(g, silG(0.3, 0.3, 1.4, 12), kabuk, (n - 0.5) * 0.02, 0.32 + kat * 0.62, -0.25 - n * 0.6); kk.rotation.z = Math.PI / 2;
        [-1, 1].forEach(function (yy) { var u2 = ekle(g, new T.CircleGeometry(0.28, 12), ic, yy * 0.71, 0.32 + kat * 0.62, -0.25 - n * 0.6); u2.rotation.y = yy * Math.PI / 2; });
      }
      var ok2 = yaziPlakasi(0.7, 0.3, '▲▲', '#3b2a14', '#ffc400', 0, 128); ok2.position.set(0, 1.0, 0.07); g.add(ok2);
    }
    return g;
  }

  // Otobüs tavanına çıkan rampa (kameraya bakan uç yerde, ileri uç 2.4 m)
  function rampaYap(boy, doga) {
    var g = new T.Group(), H = 2.4, L = boy, aci = Math.atan2(H, L), uz = Math.hypot(H, L);
    var tahta = ekle(g, yuvG(1.7, 0.14, uz, 0.04), doga ? tahtaMat() : seritMat('#ffc400', '#1c2023', 5, 1), 0, H / 2 - 0.07, -L / 2);
    tahta.rotation.x = aci;
    var yan = new T.Shape(); yan.moveTo(0, 0); yan.lineTo(L, 0); yan.lineTo(L, H - 0.1); yan.lineTo(0, 0);
    var yg = new T.ExtrudeGeometry(yan, { depth: 0.08, bevelEnabled: false }); yg.rotateY(Math.PI / 2);
    [-0.86, 0.78].forEach(function (x) { ekle(g, yg, doga ? parlakM(0x6b4a2b) : parlakM(0x8f96a8), x, 0, 0); });
    if (!doga) [-0.62, 0.62].forEach(function (x) { ekle(g, kureG(0.07, 8), lambaM(0xffa31a), x, 0.12, 0.05); });
    else for (var i = 0; i < 3; i++) { var k = ekle(g, silG(0.12, 0.12, 1.8, 8), MD.kabukMat(), 0, 0.3 + i * 0.7, -1.2 - i * 1.6); k.rotation.z = Math.PI / 2; }
    return g;
  }
  // Park etmiş otobüs: tavanı tam 2.4 m ve düz (üstünde koşulur)
  function otobusYap(boy, cesit, doga) {
    var g = new T.Group(), W = 1.9, H = 2.4, alt = 0.34;
    var renk = (doga ? [0xc8b07a, 0x7aa04a, 0xd98a3a] : [0xffc400, 0x2f8fff, 0xe8413c])[cesit % 3];
    var boya = parlakM(renk), koyu = parlakM(0x1c2023), cam = mat(0x16324a, { roughness: 0.15, metalness: 0.3 });
    ekle(g, yuvG(W, H - alt, boy, 0.2), boya, 0, alt + (H - alt) / 2, -boy / 2);
    ekle(g, yuvG(W - 0.3, 0.05, boy - 0.5, 0.02), parlakM(0xf2f2ee), 0, H - 0.01, -boy / 2);
    [-1, 1].forEach(function (y) {
      var x = y * (W / 2 + 0.006);
      ekle(g, kutuG(0.02, 0.72, boy - 1.6), cam, x, 1.72, -boy / 2 - 0.2);
      for (var p = 0; p < Math.floor((boy - 1.6) / 1.5); p++) ekle(g, kutuG(0.03, 0.74, 0.12), boya, x, 1.72, -1.2 - p * 1.5);
      var lp = new T.Mesh(new T.PlaneGeometry(Math.min(boy * 0.55, 5.5), 0.62), MD.logoMat('#1c2023', Math.min(boy * 0.55, 5.5), 0.62, 'Berber Kuaför Çağır'));
      lp.position.set(x + y * 0.004, 0.98, -boy / 2 - 0.3); lp.rotation.y = y * Math.PI / 2; g.add(lp);
      [-1.7, -(boy - 2.1)].forEach(function (z) { var t = ekle(g, silG(0.46, 0.46, 0.3, 18), koyu, y * (W / 2 - 0.1), 0.46, z); t.rotation.z = Math.PI / 2; ekle(g, silG(0.24, 0.24, 0.32, 14), parlakM(0xd7dbe3), y * (W / 2 - 0.1), 0.46, z).rotation.z = Math.PI / 2; });
    });
    ekle(g, kutuG(W - 0.42, 0.72, 0.02), cam, 0, 1.75, 0.008);
    var arka = new T.Mesh(new T.PlaneGeometry(1.45, 0.6), MD.logoMat('#1c2023', 1.45, 0.6));
    arka.position.set(0, 0.98, 0.014); g.add(arka);
    [-0.74, 0.74].forEach(function (x) { ekle(g, yuvG(0.22, 0.14, 0.05, 0.03), lambaM(0xff2a2a), x, 0.62, 0.01); });
    ekle(g, yuvG(W + 0.04, 0.2, 0.18, 0.06), koyu, 0, alt + 0.04, -0.02);
    return g;
  }

  function engelYap(tur, boy, cesit, doga) {
    if (tur === 'rampa') return MD.birlestirMat(rampaYap(boy, doga));
    if (tur === 'otobus') return MD.birlestirMat(otobusYap(boy, cesit, doga)); return MD.birlestirMat(doga ? dogaEngel(tur, boy, cesit) : kentEngel(tur, boy, cesit)); }

  var KENT_TIP = ['sedan', 'hatch', 'suv', 'taksi', 'sedan', 'minibus', 'hatch', 'suv'];
  var SAFARI = [0xc8b07a, 0xe9e6dc, 0x56703f, 0x9a7a4a];
  function aracTanim(e, doga) {
    if (e.boy > 8) return { tip: 'kamyon', renk: 0, durum: 'park' };
    if (ROTA && ROTA.tramvay && !doga && !e.ileri && !e.hareket) return { tip: 'tramvay', renk: ROTA.nostaljik ? 1 : 0, durum: 'park' };
    var durum = e.hareket ? 'gelen' : e.ileri ? 'ileri' : 'fren';
    if (doga) return { tip: 'cip', renk: SAFARI[e.id % SAFARI.length], durum: durum };
    var tip = KENT_TIP[e.id % KENT_TIP.length];
    var renk = tip === 'taksi' ? 0xf2c200 : tip === 'minibus' ? 0xf4f4f2 : MD.BOYALAR[(e.id * 7) % MD.BOYALAR.length];
    return { tip: tip, renk: renk, durum: durum };
  }
  function aracYap(tn, boy) {
    if (tn.tip === 'tramvay') { var tr = YER.tramvay(boy, !tn.renk); tr.userData.tekerler = []; tr.userData.r = 0.32; return tr; }
    var g = new T.Group(), a = tn.tip === 'kamyon' ? MD.kamyon(boy) : MD.araba(tn.tip, tn.renk, tn.durum);
    if (tn.durum === 'gelen') a.rotation.y = Math.PI;
    a.position.z = -boy / 2; g.add(a);
    g.userData.tekerler = a.userData.tekerler; g.userData.r = a.userData.r;
    return g;
  }

  // ---------- Toplanabilirler ----------
  function tarakGeo() {
    var s = new T.Shape();
    s.moveTo(-0.3, 0.17); s.quadraticCurveTo(-0.3, 0.21, -0.25, 0.21); s.lineTo(0.25, 0.21); s.quadraticCurveTo(0.3, 0.21, 0.3, 0.17); s.lineTo(0.3, 0.04);
    for (var i = 0; i < 6; i++) { var x = 0.3 - i * 0.108; s.lineTo(x, -0.2); s.lineTo(x - 0.055, -0.2); if (i < 5) { s.lineTo(x - 0.055, 0.04); s.lineTo(x - 0.108, 0.04); } }
    s.lineTo(-0.3, -0.2); s.lineTo(-0.3, 0.17);
    var g = new T.ExtrudeGeometry(s, { depth: 0.06, bevelEnabled: true, bevelThickness: 0.015, bevelSize: 0.012, bevelSegments: 1 });
    g.translate(0, 0, -0.03);
    return g;
  }
  var SIMGE = { parca: ['🎟️', '#ff3d8b'], miknatis: ['🧲', '#2f6fd6'], kalkan: ['🛡️', '#21a6c9'], ikikat: ['2×', '#8d45d6'], jet: ['🚀', '#ff7a1a'], kalp: ['❤️', '#ffffff'], sandik: ['🎁', '#ffc400'] };
  var guclerM = {};
  function gucYap(tur) {
    var s = SIMGE[tur];
    if (!guclerM[tur]) guclerM[tur] = new T.MeshBasicMaterial({ transparent: true, toneMapped: false, map: tuvalDoku(128, 128, function (g) {
      g.beginPath(); g.arc(64, 64, 60, 0, 6.2832); g.fillStyle = 'rgba(255,255,255,.55)'; g.fill();
      g.beginPath(); g.arc(64, 64, 48, 0, 6.2832); g.fillStyle = s[1]; g.fill();
      g.fillStyle = '#fff'; g.font = '900 ' + (tur === 'ikikat' ? 52 : 58) + 'px system-ui'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(s[0], 64, 69);
    }) });
    return new T.Mesh(gCache.guc || (gCache.guc = new T.PlaneGeometry(0.85, 0.85)), guclerM[tur]);
  }

  function durakYap(ad, doga, son) {
    var g = new T.Group(), direk = doga ? mat(0x6b4a2b) : mat(0x1c2023);
    if (son) {   // rota sonu: damalı bitiş kapısı
      [-3.05, 3.05].forEach(function (x) { ekle(g, silG(0.16, 0.19, 5.2, 12), direk, x, 2.6, 0); ekle(g, kureG(0.3, 12), mat(0xffc400, { emissive: 0xffc400, emissiveIntensity: 2 }), x, 5.35, 0); });
      var bp = yaziPlakasi(6.1, 1.4, '🏁 ROTA SONU\n' + ad + ' seni bekliyor!', '#1c2023', '#ffc400', 0, 512); bp.position.set(0, 4.4, 0.06); g.add(bp);
      ekle(g, kutuG(6.25, 1.52, 0.1), direk, 0, 4.4, 0);
      for (var bi = 0; bi < 14; bi++) for (var bj = 0; bj < 3; bj++) { var bk = ekle(g, new T.PlaneGeometry(0.44, 0.44), mat((bi + bj) % 2 ? 0x1c2023 : 0xffffff), -2.86 + bi * 0.44, 0.02, bj * 0.44); bk.rotation.x = -Math.PI / 2; }
      return MD.birlestirMat(g);
    }
    [-3.05, 3.05].forEach(function (x) { ekle(g, silG(0.14, 0.17, 4.6, 12), direk, x, 2.3, 0); ekle(g, kureG(0.28, 12), mat(0xffc400, { emissive: 0x4a3300 }), x, 4.75, 0); });
    var p = yaziPlakasi(6.1, 1.25, '📍 ' + ad + '\nRandevuya yetiştin!', doga ? '#e0b56e' : '#ffc400', '#1c2023', 0, 512); p.position.set(0, 3.95, 0.06); g.add(p);
    ekle(g, kutuG(6.25, 1.38, 0.1), direk, 0, 3.95, 0);
    for (var i = 0; i < 12; i++) for (var j = 0; j < 2; j++) { var kare = ekle(g, new T.PlaneGeometry(0.45, 0.45), mat((i + j) % 2 ? 0x1c2023 : 0xffffff), -2.48 + i * 0.45, 0.02, j * 0.45); kare.rotation.x = -Math.PI / 2; }
    return MD.birlestirMat(g);
  }

  // ---------- Gerçek cadde kıvrımı ----------
  // Bütün malzemelerin köşe gölgelendiricisine yanal bükülme eklenir: oyuncunun önündeki d metredeki nokta,
  // gerçek caddenin o noktadaki sapması kadar yana kayar (her 6.25 m'de bir değer, 32 değer = 200 m).
  // Örnekler arası Catmull-Rom (Hermite) ile yumuşak: kırık çizgi kare kare titreme yapmaz.
  // Fizik düz kalır; yalnız görüntü gerçek caddenin şeklini alır.
  var BUKUM = { value: new Float32Array(32) };
  (function () {
    if (!T || !T.ShaderChunk || T.ShaderChunk.common.indexOf('tkBuk') >= 0) return;
    var buk = function (v) {
      return '{ float tkD = max(-' + v + '.z / 6.25, 0.0); int tkI = min(int(tkD), 30); float tkF = tkD - float(tkI); ' +
        'float tkA = tkBuk[max(tkI - 1, 0)], tkB0 = tkBuk[tkI], tkB1 = tkBuk[tkI + 1], tkC = tkBuk[min(tkI + 2, 31)]; float tkF2 = tkF * tkF; ' +
        v + '.x += 0.5 * (2.0 * tkB0 + (tkB1 - tkA) * tkF + (2.0 * tkA - 5.0 * tkB0 + 4.0 * tkB1 - tkC) * tkF2 + (3.0 * tkB0 - tkA - 3.0 * tkB1 + tkC) * tkF2 * tkF); }';
    };
    T.ShaderChunk.common = 'uniform float tkBuk[32];\n' + T.ShaderChunk.common;
    T.ShaderChunk.project_vertex = T.ShaderChunk.project_vertex.replace('mvPosition = modelViewMatrix * mvPosition;',
      'vec4 tkW = modelMatrix * mvPosition;\n' + buk('tkW') + '\nmvPosition = viewMatrix * tkW;');
    T.ShaderChunk.worldpos_vertex = T.ShaderChunk.worldpos_vertex.replace('worldPosition = modelMatrix * worldPosition;',
      'worldPosition = modelMatrix * worldPosition;\n\t' + buk('worldPosition'));
    T.Material.prototype.onBeforeCompile = function (sh) { sh.uniforms.tkBuk = BUKUM; };
  })();

  // ---------- Sahne ----------
  function olustur(tuval, kap, ayar) {
    ayar = ayar || {};
    var ses = ayar.ses || function () {};
    var cizici = new T.WebGLRenderer({ canvas: tuval, antialias: true, alpha: false, powerPreference: 'high-performance' });
    // Nötr ton eşleme renkleri soldurmaz; üstüne çıkış geçişinde renk derecelendirme yapılır
    cizici.toneMapping = T.NeutralToneMapping; cizici.toneMappingExposure = 1.0;
    cizici.shadowMap.enabled = true; cizici.shadowMap.type = T.PCFShadowMap;
    var sahne = new T.Scene();
    sahne.environmentIntensity = 0.7;
    sahne.fog = new T.Fog(TEMA.sehir.sis, 40, GORUS - 10);
    var kamera = new T.PerspectiveCamera(70, 0.5, 0.2, GORUS + 40);

    var yariKure = new T.HemisphereLight(0xa8d8ff, 0xc9a27a, 1.0); sahne.add(yariKure);
    var gunes = new T.DirectionalLight(0xfff0d2, 2.6);
    gunes.castShadow = true;
    gunes.shadow.mapSize.set(2048, 2048); gunes.shadow.radius = 3;
    var sc = gunes.shadow.camera; sc.left = -12; sc.right = 12; sc.top = 28; sc.bottom = -28; sc.near = 1; sc.far = 70;
    gunes.shadow.bias = -0.0006; gunes.shadow.normalBias = 0.03;
    sahne.add(gunes); sahne.add(gunes.target);

    // Atmosferli gökyüzü kamerayı izler; aynı gökyüzünden yansıma ve ortam ışığı üretilir
    // Gökyüzü gölgelendiricisi fiziksel (çok parlak) değer üretir; ekranda ve yansımada ayrı ayrı ölçeklenir.
    function olcekliGok(olcek) {
      var k = new T.Sky(), m = k.material;
      m.uniforms.gokOlcek = { value: olcek };
      m.fragmentShader = m.fragmentShader.replace('void main() {', 'uniform float gokOlcek;\nvoid main() {').replace('gl_FragColor = vec4( texColor, 1.0 );', 'gl_FragColor = vec4( texColor * gokOlcek, 1.0 );');
      return k;
    }
    var gok = olcekliGok(0.32); gok.scale.setScalar(150);
    gok.material.depthTest = false; gok.renderOrder = -10; gok.frustumCulled = false;
    sahne.add(gok);
    var gokU = gok.material.uniforms;
    var pmrem = null, envSahne = null, envGok = null, envRT = null;
    try { pmrem = new T.PMREMGenerator(cizici); envSahne = new T.Sahne(); envGok = olcekliGok(0.16); envGok.scale.setScalar(10); envSahne.add(envGok); } catch (e) { pmrem = null; }
    var gunesYon = new T.Vector3();

    // Yol, kaldırım, zemin
    var yolDokulari = {};
    Object.keys(TEMA).forEach(function (ad) { yolDokulari[ad] = yolDoku(ad); });
    var cim = cimDoku(), tas = tasDoku(), kaldirim = kaldirimDoku(false), verge = kaldirimDoku(true);
    // Yaya caddesi (OSM highway=pedestrian / parke yüzey): şeritsiz parke taşı
    yolDokulari.parke = tekrar(tuvalDoku(256, 256, function (c) {
      c.fillStyle = '#8e8a84'; c.fillRect(0, 0, 256, 256);
      for (var y = 0; y < 16; y++) for (var x = 0; x < 8; x++) {
        var ox = (y % 2) * 16, v = 150 + ((x * 37 + y * 53) % 40);
        c.fillStyle = 'rgb(' + v + ',' + (v - 6) + ',' + (v - 14) + ')'; c.fillRect(x * 32 + ox + 1, y * 16 + 1, 30, 14);
      }
    }), 3, 40);
    yolDokulari.parke.anisotropy = 16;   // uzakta parke deseni titremesin
    var yolM = new T.MeshStandardMaterial({ map: yolDokulari.sehir, roughness: 0.88, metalness: 0 });
    var yol = new T.Mesh(new T.PlaneGeometry(5.8, 200, 1, 80), yolM); yol.rotation.x = -Math.PI / 2; yol.position.z = -85; yol.receiveShadow = true; sahne.add(yol);
    // Gerçek caddede tramvay hattı varsa (OSM railway=tram) orta şeritte raylar
    var raylar = new T.Group(); raylar.visible = false; sahne.add(raylar);
    [-0.72, 0.72].forEach(function (x) { var ry = new T.Mesh(new T.BoxGeometry(0.09, 0.04, 200, 1, 1, 80), new T.MeshStandardMaterial({ color: 0x9aa0a8, metalness: 0.8, roughness: 0.35 })); ry.position.set(x, 0.02, -85); raylar.add(ry); });
    var kenarM = new T.MeshStandardMaterial({ color: TEMA.sehir.kenar, roughness: 0.9 }), kenarUstM = new T.MeshStandardMaterial({ map: kaldirim, roughness: 0.9 });
    var yerM = new T.MeshStandardMaterial({ color: TEMA.sehir.yer, map: tas, roughness: 0.95 });
    [-1, 1].forEach(function (y) {
      var k = new T.Mesh(new T.BoxGeometry(1.7, 0.18, 200, 1, 1, 80), kenarM); k.position.set(y * 3.75, 0.03, -85); sahne.add(k);
      var ku = new T.Mesh(new T.PlaneGeometry(1.7, 200, 1, 80), kenarUstM); ku.rotation.x = -Math.PI / 2; ku.position.set(y * 3.75, 0.122, -85); ku.receiveShadow = true; sahne.add(ku);
      var z = new T.Mesh(new T.PlaneGeometry(40, 200, 1, 80), yerM); z.rotation.x = -Math.PI / 2; z.position.set(y * 24.5, -0.02, -85); z.receiveShadow = true; sahne.add(z);
    });

    var bordurDoku = tekrar(tuvalDoku(16, 64, function (g) { g.fillStyle = '#ffffff'; g.fillRect(0, 0, 16, 64); g.fillStyle = '#e8413c'; g.fillRect(0, 0, 16, 32); g.fillStyle = 'rgba(0,0,0,.12)'; g.fillRect(0, 30, 16, 2); g.fillRect(0, 62, 16, 2); }), 1, 100);
    var bordurM = new T.MeshStandardMaterial({ map: bordurDoku, roughness: 0.7 });
    var bordurlar = [-1, 1].map(function (y) {
      var b = new T.Mesh(new T.PlaneGeometry(0.32, 200, 1, 80), bordurM); b.rotation.x = -Math.PI / 2; b.position.set(y * 3.06, 0.126, -85); b.receiveShadow = true; sahne.add(b);
      return b;
    });
    var proto = prototipler();
    // Gece parlayan lambalar ve vitrinler (prototiplerle aynı malzeme örnekleri)
    var lambaMatlar = [mat(0xfff3c4, { emissive: 0x7a6a30 }), mat(0xffeaa0, { emissive: 0x8a7a40 }), mat(0xcfeefa, { emissive: 0x223844 })];

    // Yağmur çizgileri ve kar taneleri kamerayı çevreler
    function yagisNoktalari(n, cizgi) {
      var p = new Float32Array(n * (cizgi ? 6 : 3));
      for (var i = 0; i < n; i++) {
        var x = (Math.random() - 0.5) * 24, y = Math.random() * 15, z = 6 - Math.random() * 42;
        if (cizgi) p.set([x, y, z, x + 0.02, y - 0.6, z + 0.12], i * 6); else p.set([x, y, z], i * 3);
      }
      var g = new T.BufferGeometry(); g.setAttribute('position', new T.BufferAttribute(p, 3));
      return g;
    }
    var yagmur = new T.LineSegments(yagisNoktalari(1300, true), new T.LineBasicMaterial({ color: 0xc4d0dc, transparent: true, opacity: 0.5 }));
    var karDoku = tuvalDoku(32, 32, function (g) { var gr = g.createRadialGradient(16, 16, 0, 16, 16, 16); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.fillRect(0, 0, 32, 32); });
    var kar = new T.Points(yagisNoktalari(1600, false), new T.PointsMaterial({ color: 0xffffff, size: 0.22, map: karDoku, transparent: true, depthWrite: false }));
    [yagmur, kar].forEach(function (m) { m.frustumCulled = false; m.visible = false; sahne.add(m); });
    function yagisGuncelle(dt, hiz) {
      [yagmur, kar].forEach(function (m) {
        if (!m.visible) return;
        var p = m.geometry.attributes.position, a = p.array, adimN = m === yagmur ? 6 : 3;
        var dy = (m === yagmur ? 24 : 1.5) * dt, dz = hiz * dt * 0.55;
        for (var i = 0; i < a.length; i += adimN) {
          var y = a[i + 1] - dy, z = a[i + 2] + dz, x = a[i];
          if (m === kar) x += Math.sin((y + i) * 0.7) * dt * 0.6;
          if (y < 0 || z > 8) { y += y < 0 ? 15 : 0; if (z > 8) z -= 42; }
          a[i] = x; a[i + 1] = y; a[i + 2] = z;
          if (adimN === 6) { a[i + 3] = x + 0.02; a[i + 4] = y - 0.6; a[i + 5] = z + 0.12; }
        }
        p.needsUpdate = true;
      });
    }
    // Hız çizgileri: hız arttıkça ve turbo/jet sırasında görünür olur
    var RUZ = 70, rp = new Float32Array(RUZ * 6), ruzgarVeri = [];
    for (var ri = 0; ri < RUZ; ri++) {
      var ra = Math.random() * Math.PI * 2, rr = 2.2 + Math.random() * 3.2;
      ruzgarVeri.push({ x: Math.cos(ra) * rr * 1.25, y: 2.2 + Math.sin(ra) * rr * 0.75, z: -Math.random() * 30, l: 1.2 + Math.random() * 2.2 });
    }
    var rg = new T.BufferGeometry(); rg.setAttribute('position', new T.BufferAttribute(rp, 3));
    var ruzgar = new T.LineSegments(rg, new T.LineBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0, depthWrite: false, fog: false, toneMapped: false }));
    ruzgar.frustumCulled = false; sahne.add(ruzgar);
    function ruzgarGuncelle(dt, hiz, guc, kx) {
      ruzgar.visible = guc > 0.02;
      ruzgar.material.opacity = Math.min(0.55, guc * 0.6);
      if (!ruzgar.visible) return;
      var a = rg.attributes.position.array;
      for (var i = 0; i < RUZ; i++) {
        var w = ruzgarVeri[i];
        w.z += hiz * dt * 1.6;
        if (w.z > 7) { w.z = -24 - Math.random() * 8; }
        var l = w.l * (0.6 + guc);
        a[i * 6] = kx + w.x; a[i * 6 + 1] = w.y; a[i * 6 + 2] = w.z;
        a[i * 6 + 3] = kx + w.x; a[i * 6 + 4] = w.y; a[i * 6 + 5] = w.z + l;
      }
      rg.attributes.position.needsUpdate = true;
    }

    // Gece yıldızları
    var yp = new Float32Array(700 * 3);
    for (var yi = 0; yi < 700; yi++) {
      var ya = Math.random() * Math.PI * 2, ye = 0.08 + Math.random() * 1.3;
      yp.set([Math.cos(ya) * Math.cos(ye) * 140, Math.sin(ye) * 140, Math.sin(ya) * Math.cos(ye) * 140], yi * 3);
    }
    var yg2 = new T.BufferGeometry(); yg2.setAttribute('position', new T.BufferAttribute(yp, 3));
    var yildizlar = new T.Points(yg2, new T.PointsMaterial({ color: 0xffffff, size: 1.7, sizeAttenuation: false, fog: false, transparent: true, opacity: 0.85, depthWrite: false, toneMapped: false }));
    yildizlar.visible = false; yildizlar.frustumCulled = false; sahne.add(yildizlar);
    var normaller = {};
    fotoYukle(function () {
      fotoBekleyen.forEach(function (f) { f(); });
      if (FOTO.asfaltN) normaller.kent = fotoTex(FOTO.asfaltN, 1, 40);
      if (FOTO.camurN) normaller.doga = fotoTex(FOTO.camurN, 1, 40);
      if (FOTO.cimN) { normaller.cim = fotoTex(FOTO.cimN, 10, 50); normaller.verge = fotoTex(FOTO.cimN, 1, 60); }
      if (FOTO.duvarN) cepheNormalleri.forEach(function (c) { c.m.normalMap = fotoTex(FOTO.duvarN, 2, c.kat * 0.9); c.m.normalScale.set(0.7, 0.7); c.m.needsUpdate = true; });
      var km = MD.kabukMat();
      if (FOTO.kabuk) { km.map = fotoTex(FOTO.kabuk, 2, 3, true); km.color.set(0xd9c9b8); }
      if (FOTO.kabukN) km.normalMap = fotoTex(FOTO.kabukN, 2, 3);
      km.needsUpdate = true;
      atmKey = ''; if (tema) temaUygula(tema, atmSaat, atmHava);
    });
    var YUVA = 22, ARALIK = 7.6, yuvalar = [];
    for (var i = 0; i < YUVA * 2; i++) {
      var yg = new T.Group(); yg.userData = { yan: i < YUVA ? -1 : 1, sira: i % YUVA, no: null };
      yg.position.x = yg.userData.yan * 4.5; if (yg.userData.yan < 0) yg.rotation.y = Math.PI;
      sahne.add(yg); yuvalar.push(yg);
    }

    // ---------- Sponsor reklamları ----------
    var SPONSOR = [], gosterilen = {}, reklamC = {}, oyunda = false;
    function reklamMat(sp, pano) {
      var k = (sp ? sp.id : 0) + '|' + (pano ? 'p' : 't');
      if (reklamC[k]) return reklamC[k];
      var w = 512, h = pano ? 256 : 90, logo = null;
      function ciz(c) {
        c.fillStyle = sp ? sp.renk || '#1c2023' : '#1c2023'; c.fillRect(0, 0, w, h);
        c.fillStyle = '#ffc400'; c.fillRect(0, h - (pano ? 10 : 6), w, pano ? 10 : 6);
        c.textBaseline = 'middle'; c.fillStyle = '#ffffff';
        if (!sp) {
          c.textAlign = 'center';
          c.font = '900 ' + (pano ? 38 : 30) + 'px system-ui, sans-serif'; c.fillText(pano ? 'BERBERLER, KUAFÖRLER' : 'OYUNA SPONSOR OL', w / 2, pano ? 70 : h / 2 - 4, w - 30);
          if (pano) { c.font = '800 34px system-ui, sans-serif'; c.fillStyle = '#ffc400'; c.fillText('Oyuna sponsor ol ✂️', w / 2, 130, w - 30); c.font = '700 26px system-ui, sans-serif'; c.fillStyle = '#ffffff'; c.fillText('tarak.app › İşletme Paneli', w / 2, 190, w - 30); }
          return;
        }
        var lx = 10;
        if (logo && logo.width) { var lh = h - (pano ? 40 : 16), lw = Math.min(pano ? 200 : 150, logo.width * lh / logo.height); c.fillStyle = '#ffffff'; c.fillRect(8, (h - lh) / 2 - 4, lw + 8, lh + 8); c.drawImage(logo, 12, (h - lh) / 2, lw, lh); lx = lw + 30; }
        c.textAlign = 'left'; c.fillStyle = '#ffffff';
        c.font = '900 ' + (pano ? 40 : 32) + 'px system-ui, sans-serif'; c.fillText(sp.ad.toLocaleUpperCase('tr-TR'), lx, pano ? 62 : h / 2 - (sp.hizmet ? 13 : 0), w - lx - 12);
        if (sp.hizmet) { c.font = '700 ' + (pano ? 30 : 22) + 'px system-ui, sans-serif'; c.fillStyle = '#ffc400'; c.fillText(sp.hizmet, lx, pano ? 116 : h / 2 + 22, w - lx - 12); }
        if (pano) { c.font = '700 24px system-ui, sans-serif'; c.fillStyle = '#ffffff'; c.fillText('📍 ' + (sp.ilce || sp.il) + ' · tarak.app’te randevu al', lx, 176, w - lx - 12); }
      }
      var d = tuvalDoku(w, h, ciz);
      if (sp && sp.logo) { logo = new Image(); logo.onload = function () { var cv = d.image; ciz(cv.getContext('2d')); d.needsUpdate = true; }; logo.src = sp.logo; }
      return (reklamC[k] = new T.MeshBasicMaterial({ map: d, toneMapped: false, side: T.DoubleSide }));
    }
    function reklamYap(dw, no, yan) {
      var sp = SPONSOR.length ? SPONSOR[Math.abs(no) % SPONSOR.length] : null;
      if (!sp && ((no % 10) + 10) % 10 !== 2) return null;   // sponsor yoksa seyrek "sponsor ol" reklamı
      var g = new T.Group();
      if (dw === 'sehir') {   // dükkân tabelasının önüne sponsorun tabelası
        var t = new T.Mesh(gC2('t', 4.6, 0.8), reklamMat(sp, false)); t.position.set(0.06, 2.55, 0); t.rotation.y = -Math.PI / 2; g.add(t);
      } else {   // yol kenarı panosu
        [-1.5, 1.5].forEach(function (z) { var di = new T.Mesh(silG(0.08, 0.1, 4.2, 8), mat(0x3a3d45)); di.position.set(2.1, 2.1, z); g.add(di); });
        var p = new T.Mesh(gC2('p', 3.8, 1.9), reklamMat(sp, true)); p.position.set(2.0, 3.7, 0); p.rotation.y = -Math.PI / 2; g.add(p);
        var ar = new T.Mesh(kutuG(0.08, 2.0, 3.9), mat(0x2b2e35)); ar.position.set(2.06, 3.7, 0); g.add(ar);
      }
      if (sp && oyunda) gosterilen[sp.id] = 1;
      return g;
    }
    var gC2c = {};
    function gC2(k, w, h) { return gC2c[k] || (gC2c[k] = new T.PlaneGeometry(w, h)); }

    // Ufuktaki simge ve sıcak hava balonları (ilçeye göre)
    var simgeGrup = new T.Group(); sahne.add(simgeGrup);
    var balonGrup = YER.balonlar(); balonGrup.visible = false; balonGrup.traverse(function (o) { o.frustumCulled = false; }); sahne.add(balonGrup);
    var tabelaC = {}, rotaAnahtari = '';
    function rotaUygula(rt) {
      var k = rt ? rt.il + '/' + rt.ilce : '';
      if (k === rotaAnahtari) return;
      rotaAnahtari = k; ROTA = rt;
      yuvalar.forEach(function (y) { y.userData.no = null; });
      canli.forEach(function (c) { birak(c.m); }); canli.clear();
      simgeGrup.clear();
      var sg = rt && rt.simge ? YER.simge(rt.simge) : null;
      if (sg) simgeGrup.add(sg);
      simgeGrup.userData.x = sg ? sg.userData.x : 0;
      if (sg && rt.deniz === 'sol' && simgeGrup.userData.x > 10) simgeGrup.userData.x = -simgeGrup.userData.x;   // denizdeki simge deniz tarafında
      balonGrup.visible = !!(rt && rt.balon);
      VERI = null; veriDizin = null;
      if (rt && CD) CD.yukle(rt.plaka, function (v) {
        if (ROTA !== rt || !v || !v[rt.sira]) return;
        veriKur(v[rt.sira]);
        yuvalar.forEach(function (y) { y.userData.no = null; });
        atmKey = '';   // yol yüzeyi (parke) yeniden seçilsin
      });
    }
    // Gerçek cadde (OpenStreetMap): oyundaki metre = caddedeki metre; cadde biterse baştan tekrar eder.
    // Her yuva (7.6 m) caddenin o aralığındaki gerçek sokağı, yapıyı ya da dükkânı gösterir.
    var CD = window.TarakCadde, VERI = null, veriDizin = null;
    function veriKur(v) {
      VERI = v; veriDizin = { n: Math.max(4, Math.round(Math.max(v.uzunluk, 120) / ARALIK)), y: {}, e: {} };
      // Sokak eşyası: yuva no + yan -> [yuva içindeki metre, tür, caddeye uzaklık]
      (v.esya || []).forEach(function (o) {
        var mt = o[0] * veriDizin.n * ARALIK, no = Math.round(mt / ARALIK) % veriDizin.n;
        var k = no + '|' + o[1]; (veriDizin.e[k] = veriDizin.e[k] || []).push([mt - Math.round(mt / ARALIK) * ARALIK, o[2], o[3]]);
      });
      function koy(liste, tur) {
        (liste || []).forEach(function (o) {
          var no = Math.round(o[0] * veriDizin.n) % veriDizin.n;
          (o[1] === 0 ? [-1, 1] : [o[1]]).forEach(function (yan) {
            var k = no + '|' + yan;
            if (!veriDizin.y[k] || veriDizin.y[k].tur === 'dukkan' && tur !== 'dukkan') veriDizin.y[k] = { tur: tur, o: o };
          });
        });
      }
      koy(v.sokak, 'sokak'); koy(v.simge, 'simge'); koy(v.dukkan, 'dukkan');
    }
    function veriYuvasi(no, yan) {
      if (!veriDizin) return null;
      var n = veriDizin.n;
      return veriDizin.y[(((no % n) + n) % n) + '|' + yan] || { tur: 'bos' };
    }
    function yayaCaddesi() { return !!(VERI && VERI.yol && (VERI.yol.tur === 'pedestrian' || /paving|sett|cobble/.test(VERI.yol.yuzey || ''))); }
    function caddeAdi() { return VERI ? VERI.cadde : ROTA && ROTA.cadde; }
    // Caddenin s metresindeki yanal sapması (m). Cadde bitince baştan tekrar eder (profil iki uçta 0'dır)
    // Catmull-Rom: 10 m'lik noktalar arasında eğim de sürekli (kırık çizgide eğim her 10 m'de sıçrıyor, yol titriyordu)
    function sapma(m) {
      var sk = VERI.sekil, n = sk.length, uz = (n - 1) * 10;
      m = ((m % uz) + uz) % uz;
      var i = Math.min(n - 2, Math.floor(m / 10)), f = m / 10 - i;
      var a = sk[Math.max(0, i - 1)], b = sk[i], c = sk[i + 1], d = sk[Math.min(n - 1, i + 2)];
      return 0.05 * (2 * b + (c - a) * f + (2 * a - 5 * b + 4 * c - d) * f * f + (3 * b - a - 3 * c + d) * f * f * f);
    }
    function bukumGuncelle(s) {
      var b = BUKUM.value;
      if (!VERI || !VERI.sekil || VERI.sekil.length < 3) { if (b[31] || b[16]) b.fill(0); return; }
      var y0 = sapma(s), egim = (sapma(s + 1) - sapma(s - 1)) / 2;
      for (var k = 0; k < 32; k++) { var d = k * 6.25; b[k] = -(sapma(s + d) - y0 - egim * d); }
    }

    var maskot = window.TarakMaskot3D.olustur(); sahne.add(maskot.kok);
    maskot.kok.traverse(function (m) { if (m.isMesh) m.castShadow = true; });
    var golge = new T.Mesh(new T.CircleGeometry(0.55, 24), new T.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.18, depthWrite: false }));
    golge.rotation.x = -Math.PI / 2; golge.position.y = 0.03; sahne.add(golge);
    var kalkanKure = new T.Mesh(new T.SphereGeometry(1.15, 22, 16), new T.MeshBasicMaterial({ color: 0x7fd8ff, transparent: true, opacity: 0.22, depthWrite: false }));
    sahne.add(kalkanKure);
    var jetGrup = new T.Group();
    ekle(jetGrup, silG(0.13, 0.17, 0.55, 14), MD.std(0x7fd8ff, 0.3, 0.4), 0, 0, 0); ekle(jetGrup, silG(0.1, 0.1, 0.12, 12), MD.std(0xd7dbe3, 0.2, 1), 0, -0.32, 0);
    var alev = ekle(jetGrup, koniG(0.12, 0.6, 12), new T.MeshBasicMaterial({ color: 0xffa31a, toneMapped: false }), 0, -0.66, 0); alev.rotation.x = Math.PI;
    jetGrup.position.set(0, 1.0, 0.36); maskot.kok.add(jetGrup);

    var TARAK_UST = 260;
    var taraklar = new T.InstancedMesh(tarakGeo(), new T.MeshStandardMaterial({ color: 0xffc21a, roughness: 0.18, metalness: 0.75, emissive: 0xb86e00, emissiveIntensity: 0.9 }), TARAK_UST);
    taraklar.instanceMatrix.setUsage(T.DynamicDrawUsage); taraklar.frustumCulled = false; sahne.add(taraklar);
    var isiltiDoku = tuvalDoku(64, 64, function (g) { var gr = g.createRadialGradient(32, 32, 0, 32, 32, 32); gr.addColorStop(0, 'rgba(255,236,150,.95)'); gr.addColorStop(0.35, 'rgba(255,190,40,.45)'); gr.addColorStop(1, 'rgba(255,170,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, 64, 64); });
    var isiltilar = new T.InstancedMesh(new T.PlaneGeometry(1.25, 1.25), new T.MeshBasicMaterial({ map: isiltiDoku, transparent: true, depthWrite: false, blending: T.AdditiveBlending, toneMapped: false, fog: false }), TARAK_UST);
    isiltilar.instanceMatrix.setUsage(T.DynamicDrawUsage); isiltilar.frustumCulled = false; isiltilar.renderOrder = 2; sahne.add(isiltilar);
    var yardimci = new T.Object3D();

    var parcalar = [];
    for (var pp = 0; pp < 80; pp++) { var q = new T.Mesh(kutuG(0.11, 0.11, 0.11), new T.MeshBasicMaterial({ color: 0xffffff })); q.visible = false; q.userData.t = 0; sahne.add(q); parcalar.push(q); }
    var parcaSira = 0;
    function sac(x, y, z, renk, adet, guc) {
      for (var i = 0; i < adet; i++) {
        var q = parcalar[parcaSira++ % parcalar.length];
        q.position.set(x, y, z); q.material.color.set(renk); q.visible = true;
        q.userData = { t: 0.45 + Math.random() * 0.3, vx: (Math.random() - 0.5) * guc, vy: Math.random() * guc, vz: (Math.random() - 0.5) * guc };
      }
    }

    var havuz = {}, canli = new Map(), sonKukreme = -9;
    function al(anahtar, yap) {
      var l = havuz[anahtar] || (havuz[anahtar] = []);
      var m = l.pop() || yap();
      m.userData.anahtar = anahtar; m.visible = true; sahne.add(m);
      return m;
    }
    function birak(m) { sahne.remove(m); havuz[m.userData.anahtar].push(m); }
    function kukret(zaman) { if (zaman - sonKukreme > 3.2) { sonKukreme = zaman; ses('kukreme'); } }

    // ---------- Canlı çevre: aslanlar, karşı şerit trafiği, kuşlar ----------
    var aslanHavuz = [], aslanlar = [], aslanSira = 0;
    function aslanGuncelle(s, dt, zaman, dunyaAt, oyunVar) {
      if (aslanSira < s + 40) aslanSira = s + 60;
      while (aslanSira < s + 115) {
        var dw = dunyaAt(aslanSira);
        if (TEMA[dw].doga && (!oyunVar || (ROTA && ROTA.aslan))) {
          var a = aslanHavuz.pop() || MD.aslan(Math.random() < 0.3), yan = Math.random() < 0.5 ? -1 : 1, z = Math.random();
          var poz = z < 0.4 ? 'yuru' : z < 0.62 ? 'yat' : z < 0.82 ? 'otur' : 'kukre', yon = Math.random() < 0.5 ? 1 : -1;
          a.kok.rotation.y = poz === 'yuru' ? (yon > 0 ? 0 : Math.PI) : (yan > 0 ? Math.PI / 2 : -Math.PI / 2) + (Math.random() - 0.3) * 0.8 * yan;
          sahne.add(a.kok);
          aslanlar.push({ a: a, s: aslanSira, x: yan * (3.35 + Math.random() * 1.3), poz: poz, yon: yon, faz: Math.random() * 6, kukredi: false, kukreZaman: 0 });
          aslanSira += 18 + Math.random() * 18;
        } else aslanSira += 12;
      }
      for (var i = aslanlar.length - 1; i >= 0; i--) {
        var k = aslanlar[i];
        if (k.poz === 'yuru') k.s += (k.yon > 0 ? 1.3 : -1.3) * dt;
        var ds = k.s - s;
        if (ds < -12 || ds > 175) { sahne.remove(k.a.kok); aslanHavuz.push(k.a); aslanlar.splice(i, 1); continue; }
        if (oyunVar && !k.kukredi && ds < 16 && ds > 3 && (k.poz === 'kukre' || Math.random() < 0.006)) { k.kukredi = true; k.kukreZaman = 1.8; kukret(zaman); }
        var poz2 = k.kukreZaman > 0 ? 'kukre' : (k.poz === 'kukre' ? 'otur' : k.poz);
        if (k.kukreZaman > 0) k.kukreZaman -= dt;
        k.faz += dt * (poz2 === 'yuru' ? 5 : 2.2);
        k.a.guncelle(poz2, k.faz);
        k.a.kok.position.set(k.x, 0, -ds);
      }
    }

    var trafik = [], trafikZaman = 0, trafikHavuz = {};
    var TRAFIK_TIP = ['sedan', 'suv', 'hatch', 'minibus', 'sedan', 'taksi', 'suv'];
    function trafikGuncelle(s, dt, dunyaAt) {
      trafikZaman -= dt;
      if (trafikZaman <= 0) {
        trafikZaman = 0.8 + Math.random() * 1.6;
        if (dunyaAt(s + 150) === 'otoyol') {
          var tip = TRAFIK_TIP[Math.floor(Math.random() * TRAFIK_TIP.length)];
          var renk = tip === 'taksi' ? 0xf2c200 : MD.BOYALAR[Math.floor(Math.random() * MD.BOYALAR.length)];
          var anahtar = tip + '|' + renk, l = trafikHavuz[anahtar] || (trafikHavuz[anahtar] = []);
          var m = l.pop() || MD.araba(tip, renk, 'gelen');
          m.userData.anahtar = anahtar; m.rotation.y = Math.PI; sahne.add(m);
          trafik.push({ m: m, s: s + 155, x: Math.random() < 0.5 ? -7.45 : -10.35, hiz: 19 + Math.random() * 9 });
        }
      }
      for (var i = trafik.length - 1; i >= 0; i--) {
        var t = trafik[i];
        t.s -= t.hiz * dt;
        var ds = t.s - s;
        if (ds < -14) { sahne.remove(t.m); trafikHavuz[t.m.userData.anahtar].push(t.m); trafik.splice(i, 1); continue; }
        t.m.position.set(t.x, 0, -ds);
        var d = t.hiz * dt / t.m.userData.r;
        t.m.userData.tekerler.forEach(function (w) { w.rotation.x -= d; });
      }
    }

    var kuslar = new T.Group(), kusAktif = false, kusX = 0;
    kuslar.visible = false; sahne.add(kuslar);
    var kanatlar = [];
    for (var kb = 0; kb < 7; kb++) {
      var kus = new T.Group(); kus.position.set((kb % 3) * 1.6 - kb * 0.9, (kb % 2) * 0.8, -kb * 0.8);
      [-1, 1].forEach(function (yon) { var k = new T.Mesh(kutuG(0.7, 0.03, 0.22), mat(0x1c1c22)); k.position.x = yon * 0.35; var piv = new T.Group(); piv.add(k); kus.add(piv); kanatlar.push({ p: piv, yon: yon, f: kb }); });
      kuslar.add(kus);
    }
    function kusGuncelle(dt, zaman) {
      if (!kusAktif && TEMA[tema].doga && Math.random() < dt * 0.12) { kusAktif = true; kusX = -55; kuslar.position.set(kusX, 17 + Math.random() * 6, -45 - Math.random() * 25); kuslar.visible = true; }
      if (!kusAktif) return;
      kusX += 9 * dt; kuslar.position.x = kusX;
      kanatlar.forEach(function (k) { k.p.rotation.z = k.yon * Math.sin(zaman * 11 + k.f) * 0.6; });
      if (kusX > 60) { kusAktif = false; kuslar.visible = false; }
    }

    function temizle() {
      canli.forEach(function (k) { birak(k.m); }); canli.clear();
      yuvalar.forEach(function (y) { y.userData.no = null; });
      parcalar.forEach(function (q) { q.visible = false; q.userData.t = 0; });
      aslanlar.forEach(function (k) { sahne.remove(k.a.kok); aslanHavuz.push(k.a); }); aslanlar = []; aslanSira = 0;
      trafik.forEach(function (t) { sahne.remove(t.m); trafikHavuz[t.m.userData.anahtar].push(t.m); }); trafik = [];
      sarsinti = 0; takla = 0; donus = 0; oncekiZip = 0;
      gosterilen = {}; yuvalar.forEach(function (y) { y.userData.no = null; });
    }

    var ROTA_VITRIN = null;
    var tema = '', sarsinti = 0, takla = 0, oncekiZip = 0, donus = 0, kamX = 0, yatma = 0, kamY = 4.7, vitrinKaydir = false;
    var atmKey = '', atmSaat = 'oglen', atmHava = 'acik', bloomPass = null;
    var SAAT = {
      sabah: { gunes: [14, 40], pus: 4, mavi: 1.5, isik: 0xffe0bc, guc: 2.5, yari: 0.75, env: 0.7, sis: 0xe9dcc8, lamba: 0.6 },
      aksam: { gunes: [6, -58], pus: 8, mavi: 2.6, isik: 0xffb37a, guc: 2.1, yari: 0.6, env: 0.55, sis: 0xe6a27a, lamba: 1.6 },
      gece:  { gunes: [-9, 20], pus: 2, mavi: 0.6, isik: 0xa9bcff, guc: 1.15, yari: 0.55, env: 0.3, sis: 0x223060, lamba: 7 }
    };
    function temaUygula(ad, saat, hava) {
      saat = saat || 'oglen'; hava = hava || 'acik';
      var anahtar = ad + '|' + saat + '|' + hava;
      if (anahtar === atmKey) return;
      atmKey = anahtar; tema = ad; atmSaat = saat; atmHava = hava;
      var t = TEMA[ad], z = SAAT[saat], beyaz = new T.Color(0xffffff);
      var gp = z ? z.gunes : t.gunes, pus = z ? z.pus : t.pus, mavi = z ? z.mavi : t.mavi;
      var kapali = hava === 'bulutlu' || hava === 'yagmur' || hava === 'kar';
      var bulut = kapali ? 0.88 : hava === 'sis' ? 0.6 : t.bulut;
      if (hava === 'yagmur' || hava === 'kar') pus = Math.max(pus, 9);
      var sis = new T.Color(z ? z.sis : t.sis), gece = saat === 'gece';
      if (hava === 'sis') sis.lerp(new T.Color(gece ? 0x2a3242 : 0xd5d8da), 0.7);
      if (hava === 'yagmur') sis.lerp(new T.Color(gece ? 0x1a2030 : 0x98a1aa), 0.6);
      if (hava === 'kar') sis.lerp(new T.Color(gece ? 0x2a3348 : 0xe9eef3), 0.6);
      sahne.fog.color.copy(sis);
      sahne.fog.near = hava === 'sis' ? 6 : (hava === 'yagmur' || hava === 'kar') ? 18 : 40;
      sahne.fog.far = hava === 'sis' ? 62 : (hava === 'yagmur' || hava === 'kar') ? 100 : GORUS - 10;
      var el = gp[0] * Math.PI / 180, az = gp[1] * Math.PI / 180;
      gunesYon.set(Math.sin(az) * Math.cos(el), Math.sin(el), -Math.cos(az) * Math.cos(el));
      [gokU, envGok && envGok.material.uniforms].forEach(function (u) {
        if (!u) return;
        u.turbidity.value = pus; u.rayleigh.value = mavi; u.mieCoefficient.value = 0.005; u.mieDirectionalG.value = 0.82;
        u.sunPosition.value.copy(gunesYon);
        if (u.cloudCoverage) u.cloudCoverage.value = bulut;
      });
      if (pmrem) { if (envRT) envRT.dispose(); envRT = pmrem.fromScene(envSahne, 0); sahne.environment = envRT.texture; }
      sahne.environmentIntensity = (z ? z.env : 0.55) * (hava === 'acik' ? 1 : 0.75);
      yolM.map = ad === 'sehir' && yayaCaddesi() ? yolDokulari.parke : yolDokulari[ad];
      yolM.normalMap = normaller[t.doga ? 'doga' : 'kent'] || null;
      yolM.roughness = hava === 'yagmur' ? 0.3 : 0.88; yolM.metalness = hava === 'yagmur' ? 0.15 : 0;
      kenarUstM.map = t.doga ? verge : kaldirim;
      kenarUstM.color.set(t.doga ? (FOTO.cim ? new T.Color(t.kenar).lerp(beyaz, 0.45) : t.kenar) : 0xffffff);
      kenarUstM.normalMap = t.doga ? (normaller.verge || null) : null;
      yerM.normalMap = ad === 'sehir' ? null : (normaller.cim || null);
      kenarM.color.set(t.kenar);
      bordurlar.forEach(function (b) { b.visible = !t.doga; });
      yerM.map = ad === 'sehir' ? tas : cim;
      yerM.color.set(t.yer); if (FOTO.cim && ad !== 'sehir') yerM.color.lerp(beyaz, 0.5);
      yolM.emissive.set(hava === 'kar' ? 0x2a2e33 : 0x000000);
      if (hava === 'kar') { yerM.color.lerp(beyaz, 0.8); kenarUstM.color.lerp(beyaz, 0.7); kenarM.color.lerp(beyaz, 0.6); }
      yolM.needsUpdate = kenarUstM.needsUpdate = yerM.needsUpdate = true;
      gunes.color.set(z ? z.isik : t.isik);
      gunes.intensity = (z ? z.guc : 2.6) * (hava === 'acik' ? 1 : hava === 'bulutlu' ? 0.7 : 0.55);
      yariKure.intensity = z ? z.yari * 1.3 : 1.0;
      yariKure.color.set(gece ? 0x5a6cb0 : t.gok[1]); yariKure.groundColor.set(gece ? 0x2a2440 : t.yer);
      lambaMatlar.forEach(function (m) { m.emissiveIntensity = z ? z.lamba : 0.4; });
      if (bloomPass) { bloomPass.threshold = gece ? 0.8 : 1.45; bloomPass.strength = gece ? 0.6 : 0.35; }
      if (derece) { derece.doygunluk.value = gece ? 1.12 : kapali || hava === 'sis' ? 1.18 : 1.3; derece.sicak.value = gece ? -0.01 : 0.03; }
      yagmur.visible = hava === 'yagmur'; kar.visible = hava === 'kar';
      yildizlar.visible = gece && (hava === 'acik' || hava === 'bulutlu');
      kap.style.background = '#' + sis.getHexString();
    }

    // Çıkış geçişi: doygunluk, kontrast ve hafif kenar kararması (canlı, "çizgi film" görünümü)
    var derece = null;
    function renkGecisi() {
      var c = new T.OutputPass(), u = c.uniforms;
      u.doygunluk = { value: 1.3 }; u.kontrast = { value: 1.08 }; u.vinyet = { value: 0.28 }; u.sicak = { value: 0.03 };
      var fs = c.material.fragmentShader;
      fs = fs.replace('void main() {', 'uniform float doygunluk, kontrast, vinyet, sicak;\nvoid main() {');
      fs = fs.replace('#ifdef SRGB_TRANSFER', 'float lumi = dot(gl_FragColor.rgb, vec3(0.2126, 0.7152, 0.0722));\n\tgl_FragColor.rgb = max(mix(vec3(lumi), gl_FragColor.rgb, doygunluk), 0.0);\n\t#ifdef SRGB_TRANSFER');
      var son = fs.lastIndexOf('}');
      fs = fs.slice(0, son) + '\tgl_FragColor.rgb = clamp((gl_FragColor.rgb - 0.5) * kontrast + 0.5 + vec3(sicak, sicak * 0.4, -sicak), 0.0, 1.0);\n\tvec2 vv = vUv - 0.5; gl_FragColor.rgb *= 1.0 - vinyet * dot(vv, vv) * 1.6;\n' + fs.slice(son);
      c.material.fragmentShader = fs;
      derece = u;
      return c;
    }
    var composer = null;
    try {
      var hedefRT = new T.WebGLRenderTarget(4, 4, { type: T.HalfFloatType, samples: 4 });
      composer = new T.EffectComposer(cizici, hedefRT);
      composer.addPass(new T.RenderPass(sahne, kamera));
      bloomPass = new T.UnrealBloomPass(new T.Vector2(256, 256), 0.28, 0.4, 1.7);
      composer.addPass(bloomPass);
      composer.addPass(renkGecisi());
    } catch (e) { composer = null; }
    var W = 0, H = 0, oranSiniri = 2;
    function boyutla() {
      // Sahne gizliyken (kart resmi çekilirken) tuval yine telefon oranında boyutlanır
      var w = tuval.clientWidth || (W ? 0 : 420), h = tuval.clientHeight || (H ? 0 : 820);
      if (!w || !h || (w === W && h === H)) return;
      W = w; H = h;
      var pr = Math.min(window.devicePixelRatio || 1, oranSiniri);
      cizici.setPixelRatio(pr);
      cizici.setSize(w, h, false);
      if (composer) { composer.setPixelRatio(pr); composer.setSize(w, h); }
      kamera.aspect = w / h;
      kamera.fov = kamera.aspect < 0.62 ? 74 : kamera.aspect < 1 ? 64 : 55;
      kamera.updateProjectionMatrix();
    }

    // Telefon yavaşsa kademeli olarak: parlama kapanır, çözünürlük düşer, gölge yumuşaklığı azalır, gölge kapanır
    var kalite = { toplam: 0, sayi: 0, seviye: 0 };
    function kaliteOlc(dt) {
      if (kalite.seviye >= 4 || !dt) return;
      kalite.toplam += dt; kalite.sayi++;
      if (kalite.sayi < 150) return;
      if (kalite.toplam / kalite.sayi > 0.036) {
        kalite.seviye++;
        if (kalite.seviye === 1 && bloomPass) bloomPass.enabled = false;
        if (kalite.seviye === 2) { oranSiniri = 1.25; W = 0; }
        if (kalite.seviye === 3) { cizici.shadowMap.type = T.PCFShadowMap; gunes.shadow.mapSize.set(1024, 1024); if (gunes.shadow.map) { gunes.shadow.map.dispose(); gunes.shadow.map = null; } }
        if (kalite.seviye === 4) { gunes.castShadow = false; oranSiniri = 1; W = 0; }
      }
      kalite.toplam = 0; kalite.sayi = 0;
    }

    function ciz(o, dt, zaman, ek) {
      ek = ek || {};
      boyutla();
      var s = o ? o.p.s : ek.onizleme ? 40 : zaman * 6;
      oyunda = !!o && !ek.onizleme;
      rotaUygula(o && o.rotaT ? o.rotaT : ek.onizleme ? (ek.rotaT || null) : ROTA_VITRIN);
      var atm = o && o.rotaT ? o.rotaT : ek.onizleme ? ek : null;
      temaUygula(o ? U.dunya(o, s + 30) : ek.onizleme ? ek.tema : ['sehir', 'orman', 'otoyol', 'in'][Math.floor(zaman / 10) % 4], atm ? atm.saat : 'oglen', atm ? atm.hava : 'acik');
      var dunyaAt = o ? function (x) { return U.dunya(o, x); } : function () { return tema; };
      bukumGuncelle(s);
      raylar.visible = !!(VERI && VERI.yol && VERI.yol.tramvay) && dunyaAt(s + 20) === 'sehir';
      var adim = o ? dt : 1 / 60;
      if (o) kaliteOlc(dt);

      yolDokulari[tema].offset.y = (s / 5) % 1; yolDokulari.parke.offset.y = (s / (200 / 40)) % 1;
      cim.offset.y = tas.offset.y = (s / 4) % 1;
      kaldirim.offset.y = verge.offset.y = (s / (200 / 60)) % 1;
      bordurDoku.offset.y = (s / 2) % 1;
      if (normaller.kent) normaller.kent.offset.y = yolDokulari[tema].offset.y;
      if (normaller.doga) normaller.doga.offset.y = yolDokulari[tema].offset.y;
      if (normaller.cim) { normaller.cim.offset.y = cim.offset.y; normaller.verge.offset.y = verge.offset.y; }

      var ilk = Math.floor(s / ARALIK) - 2;
      yuvalar.forEach(function (y) {
        var d = y.userData;
        var no = ilk + (((d.sira - ilk) % YUVA) + YUVA) % YUVA;
        if (d.no !== no) {
          d.no = no;
          var dw = dunyaAt(no * ARALIK), liste = proto[dw];
          // Gerçek cadde verisi varsa şehir kesiminde iki yan da gerçek caddedir (deniz yalnız yol/sahil kesiminde)
          var denizTaraf = ROTA && ROTA.deniz && dw !== 'in' && !(veriDizin && dw === 'sehir') && (ROTA.deniz === 'iki' || (ROTA.deniz === 'sol' && d.yan < 0) || (ROTA.deniz === 'sag' && d.yan > 0));
          if (ROTA && ROTA.simge === 'kopru' && dw === 'otoyol') liste = proto.ozel('kopru');
          else if (denizTaraf) liste = proto.ozel(ROTA.gol || TEMA[dw].doga ? 'gol' : 'sahil');
          else if (dw === 'sehir') liste = proto.stil(ROTA ? ROTA.stil : 'tarihi', KADIN, !!veriDizin);
          else if (dw === 'in' && ROTA && ROTA.peri) liste = proto.ozel('peri');
          if (liste.sol) liste = d.yan < 0 ? liste.sol : liste.sag;
          y.clear();
          var gv = dw === 'sehir' && !denizTaraf ? veriYuvasi(no, d.yan) : null;
          if (gv && gv.tur === 'sokak') y.add(CD.sokakAgzi(gv.o[2], gv.o[3], d.yan));
          else if (gv && gv.tur === 'simge') y.add(CD.yapiYuvasi(gv.o[2], gv.o[3]));
          else {
            y.add(liste[Math.abs(no * 7 + (d.yan > 0 ? 3 : 0)) % liste.length].clone());
            if (gv && gv.tur === 'dukkan') y.add(CD.dukkanTabelasi(gv.o[2], gv.o[3]));
          }
          // Sponsor işletmenin reklamı: şehirde dükkân tabelası, yolda pano (oyuncunun bölgesindeki sponsorlar).
          // Gerçek caddede yalnız gerçek dükkânı olmayan binalara konur.
          if (!denizTaraf && ((no % 5) + 5) % 5 === 2 && (!gv || gv.tur === 'bos')) { var rk = reklamYap(dw, no, d.yan); if (rk) y.add(rk); }
          else if (gv && gv.tur === 'bos') y.add(CD.dukkanTabelasi(null));
          // Gerçek sokak eşyası (çöp kutusu, bayrak, bank, lamba, ağaç, durak…) OSM'deki yerinde
          if (gv) {
            var nn = veriDizin.n, ek2 = veriDizin.e[(((no % nn) + nn) % nn) + '|' + d.yan] || [];
            var yarim = (VERI.yol && VERI.yol.genislik ? VERI.yol.genislik : 8) / 2;
            ek2.forEach(function (e) {
              if (e[1] === 'gecit') {   // yaya geçidi: caddenin karşısına zebra
                var zb = CD.esyaYap('zebra'); if (zb) { zb.position.set(0, 0, d.yan > 0 ? -e[0] : e[0]); y.add(zb); } return;
              }
              var es = CD.esyaYap(e[1]); if (!es) return;
              es.position.set(-1.45 + Math.max(0, Math.min(1, (e[2] - yarim) / 12)) * 1.25, 0.12, d.yan > 0 ? -e[0] : e[0]);
              y.add(es);
            });
          }
          // Lacivert cadde tabelası (gerçek caddede gerçek adı)
          var ca = caddeAdi();
          if (ca && dw === 'sehir' && !denizTaraf && d.yan > 0 && ((no % 4) + 4) % 4 === 0 && (!gv || gv.tur !== 'sokak')) {
            var tb = tabelaC[ca] || (tabelaC[ca] = YER.tabela(ca.toLocaleUpperCase('tr-TR')));
            var tk = tb.clone(); tk.position.set(-1.55, 0.12, 3.3); y.add(tk);
          }
        }
        y.position.z = -(no * ARALIK - s);
      });

      var gorulen = new Set(), nTarak = 0;
      if (o) {
        o.engeller.forEach(function (e) {
          if (e.kirildi || e.s - s > GORUS || e.s + e.boy - s < -7) return;
          var k = canli.get(e.id);
          if (!k) {
            var doga = !!TEMA[U.dunya(o, e.s)].doga, anahtar, yap;
            if (e.tur === 'arac') {
              var tn = aracTanim(e, doga);
              anahtar = 'arac|' + tn.tip + '|' + tn.renk + '|' + tn.durum + '|' + e.boy;
              yap = function () { return aracYap(tn, e.boy); };
            } else if (e.tur === 'aracUstu') {
              var ur = doga ? SAFARI[e.id % SAFARI.length] : MD.BOYALAR[(e.id * 5) % MD.BOYALAR.length];
              anahtar = 'ustu|' + ur + '|' + doga;
              yap = function () { var ug = new T.Group(), a = MD.araba(doga ? 'cip' : 'hatch', ur, 'park'); a.scale.setScalar(0.72); a.position.z = -1.5; ug.add(a); return ug; };
            } else {
              var cesitG = (doga && e.tur === 'bariyer' && e.cesit === 0 && !(ROTA && ROTA.aslan)) ? 1 : e.cesit;
              anahtar = e.tur + '|' + e.boy + '|' + cesitG + '|' + doga + (KADIN && e.tur === 'kapi' ? '|k' : '');
              yap = function () { return engelYap(e.tur, e.boy, cesitG, doga); };
            }
            k = { m: al(anahtar, yap), aslan: doga && e.tur === 'bariyer' && e.cesit === 0 && !!(ROTA && ROTA.aslan) };
            canli.set(e.id, k);
          }
          var z = -(e.s - s);
          k.m.position.set(e.serit * U.S.serit, e.taban || 0, z);
          var hz = e.ileri || (e.tetik ? e.hareket : 0);
          if (hz && k.m.userData.tekerler && dt) { var d = hz * dt / k.m.userData.r; k.m.userData.tekerler.forEach(function (w) { w.rotation.x -= d; }); }
          if (e.ileri && dt && Math.random() < dt * 6) sac(e.serit * U.S.serit - 0.55, 0.3, z + 0.1, 0x9a9a9a, 1, 0.5);
          if (k.aslan && !e.kukre && e.s - s < 8) { e.kukre = true; kukret(zaman); }
          gorulen.add(e.id);
        });
        o.nesneler.forEach(function (n) {
          var ds = n.s - s;
          if (n.alindi || ds > 95 || ds < -4) return;
          if (n.tur === 'tarak') {
            if (nTarak >= TARAK_UST) return;
            yardimci.position.set(n.x, n.y + 0.08, -ds); yardimci.rotation.set(0, zaman * 3.4 + n.s * 0.25, 0.25); yardimci.scale.setScalar(1.45); yardimci.updateMatrix();
            taraklar.setMatrixAt(nTarak, yardimci.matrix);
            yardimci.rotation.set(-0.35, 0, 0); yardimci.scale.setScalar((0.85 + Math.sin(zaman * 5 + n.s) * 0.1) * Math.min(1, Math.max(0, (ds - 1) / 6))); yardimci.position.z -= 0.08; yardimci.updateMatrix();
            isiltilar.setMatrixAt(nTarak++, yardimci.matrix);
            return;
          }
          var k = canli.get(n.id);
          if (!k) { k = { m: al('guc|' + n.tur, function () { return gucYap(n.tur); }) }; canli.set(n.id, k); }
          k.m.position.set(n.x, n.y + Math.sin(zaman * 4 + n.s) * 0.1, -ds);
          k.m.scale.setScalar((n.tur === 'parca' ? 1.35 : 1) * (1 + Math.sin(zaman * 6 + n.s) * 0.07));
          gorulen.add(n.id);
        });
        o.duraklar.forEach(function (d) {
          var ds = d.s - s, id = 'durak' + d.no;
          if (ds > GORUS || ds < -8) return;
          var k = canli.get(id);
          if (!k) { var doga = !!TEMA[U.dunya(o, d.s)].doga; k = { m: al('durak|' + d.ad + '|' + doga + '|' + !!d.son, function () { return durakYap(d.ad, doga, d.son); }) }; canli.set(id, k); }
          k.m.position.set(0, 0, -ds);
          gorulen.add(id);
        });
      }
      canli.forEach(function (k, id) { if (!gorulen.has(id)) { birak(k.m); canli.delete(id); } });
      taraklar.count = isiltilar.count = nTarak; taraklar.instanceMatrix.needsUpdate = isiltilar.instanceMatrix.needsUpdate = true;
      yardimci.scale.setScalar(1);

      aslanGuncelle(s, adim, zaman, dunyaAt, !!o);
      trafikGuncelle(s, adim, dunyaAt);
      kusGuncelle(adim, zaman);

      var px = 0, py = 0;
      jetGrup.visible = false; kalkanKure.visible = false;
      if (o) {
        var P = o.p; px = P.x; py = P.y;
        var poz = 'kos';
        if (P.kayis > 0 && P.yerde) poz = 'kay'; else if (!P.yerde) poz = 'zipla';
        if (o.jet > 0) { poz = 'kay'; jetGrup.visible = true; alev.scale.y = 0.75 + Math.random() * 0.5; }
        if (o.bitti) poz = o.kazandi ? 'sevinc' : 'dusus';
        if (P.zipSayisi === 2 && oncekiZip === 1 && o.jet <= 0) takla = 0.46;
        oncekiZip = P.zipSayisi;
        var aci = 0;
        if (takla > 0) { takla -= dt; if (!P.yerde) aci = (1 - Math.max(0, takla) / 0.46) * Math.PI * 2; }
        donus += ((o.bitti ? Math.PI : 0) - donus) * Math.min(1, dt * 5);
        maskot.yuzOn(donus > Math.PI / 2);
        maskot.kok.position.set(px, py, 0);
        maskot.kok.rotation.set(0, donus, (P.serit * U.S.serit - px) * -0.11);
        maskot.canlandir(poz, s * 2.25, { takla: aci });
        maskot.kok.visible = !(P.dokunulmaz > 0 && !o.bitti && Math.floor(zaman * 12) % 2 === 0);
        kalkanKure.visible = !!o.kalkan; kalkanKure.position.set(px, py + 0.95, 0);
        if (poz === 'kay' && P.yerde && Math.random() < (P.turbo ? 0.9 : 0.35)) sac(px, 0.15, 0.5, P.turbo ? 0xffc400 : 0xd9d0bd, 1, 2.2);
        golge.position.set(px, 0.035, 0); golge.scale.setScalar(Math.max(0.4, 1 - py * 0.22)); golge.visible = true;
        kamX += (px * 0.62 - kamX) * Math.min(1, dt * 12);
        var turbo = (P.turbo && P.kayis > 0) || o.jet > 0;
        var vNow = U.hiz(o), hizOran = Math.max(0, Math.min(1, (vNow - 11) / 14));
        var hedefFov = (W / H < 0.62 ? 72 : W / H < 1 ? 62 : 53) + hizOran * 7 + (turbo ? 9 : 0);
        if (Math.abs(kamera.fov - hedefFov) > 0.1) { kamera.fov += (hedefFov - kamera.fov) * Math.min(1, dt * 6); kamera.updateProjectionMatrix(); }
        // Tavana çıkınca kamera yumuşakça yükselir; koşarken hafif sallanır
        kamY += (4.7 + py * 0.4 - kamY) * Math.min(1, dt * (P.yerde ? 8 : 5));
        var salla = P.yerde && !o.bitti ? Math.sin(s * 1.12) * 0.035 : 0;
        kamera.position.set(kamX, kamY + salla, 6.3 - hizOran * 0.5);
        kamera.lookAt(kamX * 0.8, 0.7 + py * 0.3, -6.5);
        yatma *= Math.max(0, 1 - dt * 6);
        kamera.rotateZ(yatma * 0.045 + (P.serit * U.S.serit - px) * -0.012);
        ruzgarGuncelle(dt, vNow, 0.1 + hizOran * 0.75 + (turbo ? 0.7 : 0), kamX);
      } else if (ek.onizleme) {
        ruzgar.visible = false;
        // Rota kartı: oyuncu gözünden, yolun ilerisine bakış
        maskot.yuzOn(false); maskot.kok.visible = true;
        maskot.kok.position.set(0, 0, 0); maskot.kok.rotation.set(0, 0, 0);
        maskot.canlandir('kos', 1.3, {});
        golge.position.set(0, 0.035, 0); golge.scale.setScalar(1); golge.visible = true;
        kamX = 0;
        kamera.position.set(0.5, 4.2, 6.6);
        kamera.lookAt(0, 0.9, -14);
      } else if (ek.alan && H) {
        // Vitrin: maskot verilen ekran bandına (px) sığacak uzaklıkta ve o banda kaydırılmış görünür
        ruzgar.visible = false;
        maskot.yuzOn(true); maskot.kok.visible = true;
        maskot.kok.position.set(0, 0, 0); maskot.kok.rotation.set(0, Math.PI + Math.sin(zaman * 0.5) * 0.35, 0);
        maskot.canlandir(ek.sevinc ? 'sevinc' : 'dur', zaman * 4, {});
        golge.position.set(0, 0.035, 0); golge.scale.setScalar(1); golge.visible = true;
        kamX = 0;
        var bh = Math.max(70, ek.alan.alt - ek.alan.ust), bc = (ek.alan.ust + ek.alan.alt) / 2, tf = Math.tan(kamera.fov * Math.PI / 360);
        var uz = Math.max(3.2, Math.min(18, (2.35 * H / (0.92 * bh)) / (2 * tf)));
        kamera.position.set(0, 1.08, uz); kamera.lookAt(0, 1.08, 0);
        kamera.setViewOffset(W, H, 0, H / 2 - bc, W, H);
        vitrinKaydir = true;
      } else {
        ruzgar.visible = false;
        maskot.yuzOn(true); maskot.kok.visible = true;
        maskot.kok.position.set(0, 0, 0); maskot.kok.rotation.set(0, Math.PI + Math.sin(zaman * 0.5) * 0.35, 0);
        maskot.canlandir(ek.sevinc ? 'sevinc' : 'dur', zaman * 4, {});
        golge.position.set(0, 0.035, 0); golge.scale.setScalar(1); golge.visible = true;
        kamX = 0;
        kamera.position.set(0, 1.75, ek.uzaklik || 4.6);
        kamera.lookAt(0, ek.bak === undefined ? 1.05 : ek.bak, 0);
      }
      if (vitrinKaydir && !(ek.alan && !o && !ek.onizleme)) { kamera.clearViewOffset(); vitrinKaydir = false; }
      if (sarsinti > 0) { sarsinti -= dt; kamera.position.x += (Math.random() - 0.5) * sarsinti * 0.7; kamera.position.y += (Math.random() - 0.5) * sarsinti * 0.5; }

      // Güneş arkadan aydınlatır; gölge kamerası oyuncunun önünü kapsar
      gunes.target.position.set(kamX, 0, -14);
      gunes.position.set(kamX + 5, 16, -2);
      gok.position.copy(kamera.position);
      // Simge ufukta sabit uzaklıkta; balonlar kameranın çevresinde süzülür
      simgeGrup.position.set(simgeGrup.userData.x + kamX * 0.2, -0.4, kamera.position.z - 134);
      if (balonGrup.visible) {
        balonGrup.position.set(kamX * 0.5, 0, kamera.position.z);
        balonGrup.children.forEach(function (b) { b.position.y = b.userData.y0 + Math.sin(zaman * 0.4 + b.userData.faz) * 1.5; });
      }
      if (gokU.time) gokU.time.value = zaman;
      yildizlar.position.copy(kamera.position);
      yagmur.position.x = kar.position.x = kamX;
      yagisGuncelle(ek.onizleme ? 0 : adim, o ? U.hiz(o) : 6);

      parcalar.forEach(function (q) {
        var d = q.userData;
        if (!q.visible) return;
        d.t -= dt; if (d.t <= 0) { q.visible = false; return; }
        d.vy -= 11 * dt; q.position.x += d.vx * dt; q.position.y += d.vy * dt; q.position.z += (d.vz + (o ? U.hiz(o) * 0.25 : 0)) * dt;
        q.rotation.x += dt * 8; q.scale.setScalar(Math.min(1, d.t * 3));
      });
      if (composer && kalite.seviye < 4) composer.render(); else cizici.render(sahne, kamera);
    }

    // Kart resmi: sahneyi rotanın ilk dünyası, saati ve havasıyla bir kez çizer, ekrandan kopyalar
    function onizleme(rota, w, h) {
      // Yol kenarı parçaları yeni dünyaya göre yeniden seçilsin
      yuvalar.forEach(function (y) { y.userData.no = null; });
      ciz(null, 1 / 60, 3, { onizleme: true, tema: rota.dunyalar[0], saat: rota.saat, hava: rota.hava, rotaT: rota });
      yuvalar.forEach(function (y) { y.userData.no = null; });
      var src = cizici.domElement, sw = src.width, sh = src.height;
      if (!sw || !sh) return null;
      var c = document.createElement('canvas'); c.width = w; c.height = h;
      var oran = w / h, cw = sw, ch = sw / oran;
      if (ch > sh) { ch = sh; cw = sh * oran; }
      var sy = Math.min(sh - ch, sh * 0.16);
      c.getContext('2d').drawImage(src, (sw - cw) / 2, sy, cw, ch, 0, 0, w, h);
      try { return c.toDataURL('image/jpeg', 0.82); } catch (e) { return null; }
    }

    return {
      onizleme: onizleme,
      vitrinRota: function (rt) { ROTA_VITRIN = rt || null; },
      _sahne: function () { return sahne; },
      cadde: function () { return VERI ? { ad: VERI.cadde, uzunluk: VERI.uzunluk, dukkan: VERI.dukkan.length, sokak: VERI.sokak.length, simge: VERI.simge.length } : null; },
      sponsorlar: function (l) { SPONSOR = l || []; reklamC = {}; yuvalar.forEach(function (y) { y.userData.no = null; }); },
      gosterilen: function () { return Object.keys(gosterilen).map(Number); },
      kadin: function (k) {
        KADIN = !!k; maskot.kadin(KADIN);
        canli.forEach(function (c) { birak(c.m); }); canli.clear();
        yuvalar.forEach(function (y) { y.userData.no = null; });
      },
      ciz: ciz, temizle: temizle, sac: sac, maskot: maskot,
      sars: function (m) { sarsinti = Math.max(sarsinti, m); },
      yatir: function (y) { yatma = -y; },
      bilgi: function () { return { cizim: cizici.info.render.calls, ucgen: cizici.info.render.triangles, golge: gunes.castShadow, kalite: kalite.seviye, aslan: aslanlar.length, trafik: trafik.length, aslanlar: aslanlar.map(function (k) { return [Math.round(k.s), k.x.toFixed(1), k.poz]; }) }; }
    };
  }

  window.TarakSahne = { olustur: olustur };
})();
